//
//  An "unchallenged" continuous sequence of validated blocks
//

import Foundation
import AwesomeDictionary
import Bedrock
import AwesomeTrie

public protocol Segment: Codable, Comparable {
    associatedtype BlockRepresentationType: BlockRepresentation
    associatedtype SegmentID: Stringable, Randomizable
    typealias Digest = BlockRepresentationType.Digest
    typealias Number = BlockRepresentationType.Number
    typealias ChainName = BlockRepresentationType.ChainName
    
    var earliestParent: Number? { get }
    // number of max chain's last segment's latest block
    var tipNumber: Number { get }
    // number of last block in this segment
    var latestBlock: Number { get }
    // lower the target, the higher the difficulty
    var latestBlockDifficultyTarget: Digest { get }
    // mapping of block number to block
    var blocks: Mapping<Number, BlockRepresentationType> { get }
    // mapping of child segment id to child segment
    var childSegments: Mapping<SegmentID, Self> { get }
    
    init(tipNumber: Number, earliestParent: Number?, latestBlock: Number, latestBlockDifficultyTarget: Digest, blocks: Mapping<Number, BlockRepresentationType>, childSegments: Mapping<SegmentID, Self>)
}

public extension Segment {
    // comparison of segments for consensus algorithm
    // First: Earliest parent wins
    // Second: Latest Block Number Wins
    // Third: Easiest Difficulty (highest target) Wins
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.earliestParent != nil && rhs.earliestParent == nil { return false }
        if lhs.earliestParent == nil && rhs.earliestParent != nil { return true }
        if lhs.earliestParent != nil && rhs.earliestParent != nil { return lhs.earliestParent! > rhs.earliestParent! }
        if lhs.tipNumber == rhs.tipNumber { return lhs.latestBlockDifficultyTarget < rhs.latestBlockDifficultyTarget }
        return lhs.tipNumber < rhs.tipNumber
    }

    func getLatestBlock() -> BlockRepresentationType {
        return blocks[latestBlock]!
    }
    
    // segments are strictly ordered
    static func == (lhs: Self, rhs: Self) -> Bool {
        return false
    }
    
    func changing(tipNumber: Number? = nil, latestBlock: Number? = nil, latestBlockDifficulty: Digest? = nil, blocks: Mapping<Number, BlockRepresentationType>? = nil, childSegments: Mapping<SegmentID, Self>? = nil) -> Self {
        return Self(tipNumber: tipNumber ?? self.tipNumber, earliestParent: earliestParent, latestBlock: latestBlock ?? self.latestBlock, latestBlockDifficultyTarget: latestBlockDifficulty ?? self.latestBlockDifficultyTarget, blocks: blocks ?? self.blocks, childSegments: childSegments ?? self.childSegments)
    }
    
    func changing(earliestParent: Number?) -> Self {
        return Self(tipNumber: tipNumber, earliestParent: earliestParent, latestBlock: latestBlock, latestBlockDifficultyTarget: latestBlockDifficultyTarget, blocks: blocks, childSegments: childSegments)
    }
    
    func removeParents(blockNumber: Number, parents: Mapping<Digest, Number>) -> Self {
        return parents.elements().reduce(self) { (result, entry) -> Self in
            return result.removeParent(blockNumber: blockNumber, parent: entry.0, blockNumberOfParent: entry.1)
        }
    }
    
    func addParents(blockNumber: Number, parents: Mapping<Digest, Number>) -> Self {
        return parents.elements().reduce(self) { (result, entry) -> Self in
            return result.addParent(blockNumber: blockNumber, parent: entry.0, blockNumberOfParent: entry.1)
        }
    }
    
    func addParent(blockNumber: Number, parent: Digest, blockNumberOfParent: Number) -> Self {
        let newBlock = blocks[blockNumber]!.addParent(hash: parent, parentBlockNumber: blockNumberOfParent)
        let newEarliest = earliestParent != nil ? (blockNumber < earliestParent! ? blockNumber : earliestParent!) : blockNumber
        return changing(blocks: blocks.setting(key: blockNumber, value: newBlock)).changing(earliestParent: newEarliest)
    }
    
    func removeParent(blockNumber: Number, parent: Digest, blockNumberOfParent: Number) -> Self {
        guard let newBlock = blocks[blockNumber]!.removeParent(hash: parent) else { return self }
        let newSegment = changing(blocks: blocks.setting(key: blockNumber, value: newBlock))
        return blockNumberOfParent == earliestParent ? newSegment.updateEarliestParent() : newSegment
    }
    
    // propogate parent cross link confs to child segments
    // apply parent cross link confs to current segment
    // recompute earliest parent
    // if no earliest parent recompute longest chain
    func changeParentConfirmations(currentAdditions: Mapping<Digest, Mapping<Digest, Number>>, currentRemovals: Mapping<Digest, Mapping<Digest, Number>>, additions: Mapping<Digest, Mapping<Digest, Number>>, removals: Mapping<Digest, Mapping<Digest, Number>>, additionsTrie: TrieMapping<SegmentID, [Digest]>, removalsTrie: TrieMapping<SegmentID, [Digest]>, blockNumbers: Mapping<Digest, Number>) -> Self {
        let addedCurrentAdditions = currentAdditions.elements().reduce(self) { (result, entry) -> Self in
            return result.addParents(blockNumber: blockNumbers[entry.0]!, parents: entry.1)
        }
        let removedCurrentRemovals = currentRemovals.elements().reduce(addedCurrentAdditions) { (result, entry) -> Self in
            return result.removeParents(blockNumber: blockNumbers[entry.0]!, parents: entry.1)
        }
        if additionsTrie.isEmpty() && removalsTrie.isEmpty() {
            let updatedEarliest = removedCurrentRemovals.updateEarliestParentNoChildChanges()
            if updatedEarliest.earliestParent == nil && earliestParent != nil {
                return updatedEarliest.updateWithMaxTipNumber()
            }
            return updatedEarliest
        }
        let newChildSegments = childSegments.changeParentConfirmations(additions: additions, removals: removals, additionsTrie: additionsTrie, removalsTrie: removalsTrie, blockNumbers: blockNumbers)
        let updatedChildren = removedCurrentRemovals.changing(childSegments: newChildSegments)
        if currentRemovals.isEmpty() && currentAdditions.isEmpty() && removalsTrie.isEmpty() {
            return updatedChildren.updateEarliestParentOnlyChildChanges()
        }
        let updatedEarliest = updatedChildren.updateEarliestParent()
        if updatedEarliest.earliestParent == nil && earliestParent != nil {
            return updatedEarliest.updateWithMaxTipNumber()
        }
        return updatedEarliest
    }
    
    // if no parents (most common on root graph, tip number is found using max tip number)
    func updateWithMaxTipNumber() -> Self {
        return changing(latestBlock: (childSegments.values().map { $0.tipNumber } + [tipNumber]).max()!)
    }
    
    func updateEarliestParent() -> Self {
        return changing(earliestParent: findEarliestParent())
    }
    
    func findEarliestParent() -> Number? {
        guard let onlyChildChanges = findEarliestParentOnlyChildChanges() else { return findEarliestParentNoChildChanges() }
        guard let noChildChanges = findEarliestParentNoChildChanges() else { return onlyChildChanges }
        return min(onlyChildChanges, noChildChanges)
    }
    
    func updateEarliestParentOnlyChildChanges() -> Self {
        return changing(earliestParent: findEarliestParentOnlyChildChanges())
    }
    
    func findEarliestParentOnlyChildChanges() -> Number? {
        return childSegments.values().filter { $0.earliestParent != nil }.map { $0.earliestParent! }.min()
    }
    
    func updateEarliestParentNoChildChanges() -> Self {
        return changing(earliestParent: findEarliestParentNoChildChanges())
    }
    
    func findEarliestParentNoChildChanges() -> Number? {
        return blocks.elements().filter { $0.1.earliestParent() != nil }.map { $0.1.earliestParent()! }.min()
    }
    
    // chain -> child block fing -> parent block fing -> parent block number
    func allBlocksAndChildConfirmations() -> Mapping<BlockRepresentationType.ChainName, Mapping<Digest, Mapping<Digest, Number>>> {
        return blocks.elements().reduce(Mapping<BlockRepresentationType.ChainName, Mapping<Digest, Mapping<Digest, Number>>>()) { result, entry in
            return entry.1.allBlockInfoAndChildConfirmations().elements().reduce(result) { result1, entry1 in
                let chainName = entry1.0
                let current = result1[chainName] ?? Mapping<Digest, Mapping<Digest, Number>>()
                let valueToSet = entry1.1.reduce(current) { result2, entry2 in
                    let currentVal = result2[entry2.blockHash] ?? Mapping<Digest, Number>()
                    return result2.setting(key: entry2.blockHash, value: currentVal.setting(key: entry.1.blockHash, value: entry.0))
                }
                return result1.setting(key: chainName, value: valueToSet)
            }
        }
    }
    
    func addToStart(block: BlockRepresentationType, blockNumber: Number) -> Self {
        let newEarliestParent = earliestParent == nil ? block.earliestParent() : (block.earliestParent() == nil ? earliestParent : min(block.earliestParent()!, earliestParent!))
        let newBlocks = blocks.setting(key: blockNumber, value: block)
        return changing(earliestParent: newEarliestParent).changing(blocks: newBlocks)
    }
    
    // returns
    // new segment with segment in parameter inserted
    // new segment ids for blocks
    // new segment mapped to segment parent
    func insert(currentSegmentID: SegmentID, path: ArraySlice<SegmentID>, segment: Self, segmentID: SegmentID, segmentStartNumber: Number, previousBlockFingerprint: Digest) -> (Self, Mapping<Digest, SegmentID>, Mapping<SegmentID, SegmentID>) {
        if let firstPath = path.first {
            let childResult = childSegments.insert(firstPath: firstPath, path: path.dropFirst(), segment: segment, segmentID: segmentID, segmentStartNumber: segmentStartNumber, previousBlockFingerprint: previousBlockFingerprint)
            let newChild = childResult.0
            let newChildren = childSegments.setting(key: firstPath, value: childResult.0)
            if newChild > self {
                return (changing(earliestParent: newChild.earliestParent).changing(tipNumber: newChild.tipNumber, latestBlockDifficulty: newChild.latestBlockDifficultyTarget, childSegments: newChildren), childResult.1, childResult.2)
            }
            return (changing(childSegments: newChildren), childResult.1, childResult.2)
        }
        let currentBlockHash = segment.blocks[segmentStartNumber]!.blockHash
        // adding to end of segment
        if getLatestBlock().blockHash == previousBlockFingerprint {
            // adding to end of some chain
            if childSegments.isEmpty() {
                let newSegment = addToEnd(segment: segment)
                let segmentDeltas = segment.blocks.values().map { $0.blockHash }.reduce(Mapping<Digest, SegmentID>()) { result, entry in
                    return result.setting(key: entry, value: currentSegmentID)
                }
                return (newSegment, segmentDeltas, Mapping<SegmentID, SegmentID>())
            }
            // adding a new child to segment
            let newSegment = addAsChild(segment: segment, segmentID: segmentID)
            return (newSegment, Mapping<Digest, SegmentID>().setting(key: currentBlockHash, value: segmentID), Mapping<SegmentID, SegmentID>().setting(key: segmentID, value: currentSegmentID))
        }
        // adding to the middle of segment, must split segment
        let splitBlocks = blocks.elements().reduce((Mapping<Number, BlockRepresentationType>(), Mapping<Number, BlockRepresentationType>())) { result, entry in
            if entry.0 >= segmentStartNumber {
                return (result.0, result.1.setting(key: entry.0, value: entry.1))
            }
            return (result.0.setting(key: entry.0, value: entry.1), result.1)
        }
        let maxChildSegment = childSegments.values().max()!
        let frontSegmentEndNumber = segmentStartNumber.advanced(by: -1)
        let backSegmentEarliestParent = splitBlocks.1.values().filter { $0.earliestParent() != nil }.map { $0.earliestParent()! }.min()
        let keepBackSegmentEarliest = maxChildSegment.earliestParent == earliestParent || earliestParent == backSegmentEarliestParent
        let backSegment = keepBackSegmentEarliest ? changing(blocks: splitBlocks.1) : changing(blocks: splitBlocks.1).changing(earliestParent: backSegmentEarliestParent)
        let newBackSegmentID = SegmentID.random()
        let newChildSegments = Mapping<SegmentID, Self>().setting(key: newBackSegmentID, value: backSegment)
        let frontSegment = changing(latestBlock: frontSegmentEndNumber, blocks: splitBlocks.0, childSegments: newChildSegments)
        let segmentIDChanges = splitBlocks.1.values().reduce(Mapping<Digest, SegmentID>()) { result, entry in
            return result.setting(key: entry.blockHash, value: newBackSegmentID)
        }
        let newSegmentParentChanges = Mapping<SegmentID, SegmentID>().setting(key: segmentID, value: currentSegmentID).setting(key: newBackSegmentID, value: currentSegmentID)
        return (frontSegment.addAsChild(segment: segment, segmentID: segmentID), segmentIDChanges.setting(key: currentBlockHash, value: segmentID), newSegmentParentChanges)
    }
    
    static func createWithSingleBlock(block: BlockRepresentationType, blockNumber: Number) -> Self {
        return Self(tipNumber: blockNumber, earliestParent: block.earliestParent(), latestBlock: blockNumber, latestBlockDifficultyTarget: block.nextDifficulty, blocks: Mapping<Number, BlockRepresentationType>().setting(key: blockNumber, value: block), childSegments: Mapping<SegmentID, Self>())
    }
    
    // segmentID is provided segmentID for segment in parameter
    func addAsChild(segment: Self, segmentID: SegmentID) -> Self {
        let newEarliestParent = earliestParent == nil ? segment.earliestParent : (segment.earliestParent == nil ? earliestParent : min(segment.earliestParent!, earliestParent!))
        let maxChildSegment = childSegments.values().max()!
        let segmentGreaterThanChildren = segment > maxChildSegment
        let newLatestBlockDifficulty = segmentGreaterThanChildren ? segment.latestBlockDifficultyTarget : latestBlockDifficultyTarget
        let newTipNumber = segmentGreaterThanChildren ? segment.tipNumber : tipNumber
        let newChildSegments = childSegments.setting(key: segmentID, value: segment)
        return changing(earliestParent: newEarliestParent).changing(tipNumber: newTipNumber, latestBlockDifficulty: newLatestBlockDifficulty, childSegments: newChildSegments)
    }
    
    func addToEnd(segment: Self) -> Self {
        let newEarliestParent = earliestParent == nil ? segment.earliestParent : (segment.earliestParent == nil ? earliestParent : min(segment.earliestParent!, earliestParent!))
        return Self(tipNumber: segment.tipNumber, earliestParent: newEarliestParent, latestBlock: segment.latestBlock, latestBlockDifficultyTarget: segment.latestBlockDifficultyTarget, blocks: blocks.overwrite(with: segment.blocks), childSegments: segment.childSegments)
    }
    
    func getParentConfirmationsAndTip() -> (Mapping<ChainName, Mapping<Digest, Mapping<Digest, Number>>>, Digest) {
        let childConfs = childSegments.values().max()?.getParentConfirmationsAndTip()
        let newChildConfs = allBlocksAndChildConfirmations().elements().reduce(childConfs?.0 ?? Mapping<ChainName, Mapping<Digest, Mapping<Digest, Number>>>()) { result, entry in
            let chainName = entry.0
            let current = result[chainName] ?? Mapping<Digest, Mapping<Digest, Number>>()
            let valueToSet = entry.1.elements().reduce(current) { result1, entry1 in
                let currentVal = result1[entry1.0] ?? Mapping<Digest, Number>()
                let valSet = entry1.1.elements().reduce(currentVal) { result2, entry2 in
                    return result2.setting(key: entry2.0, value: entry2.1)
                }
                return result1.setting(key: entry1.0, value: valSet)
            }
            return result.setting(key: chainName, value: valueToSet)
        }
        return (newChildConfs, childConfs?.1 ?? getLatestBlock().blockHash)
    }
}

public extension Mapping where Value: Segment, Key == Value.SegmentID {
    func computeTip() -> Value.Digest? {
        guard let maxSegment = values().max() else { return nil }
        if maxSegment.childSegments.isEmpty() { return maxSegment.blocks[maxSegment.latestBlock]?.blockHash }
        return maxSegment.childSegments.computeTip()
    }
    
    func insert(firstPath: Key, path: ArraySlice<Key>, segment: Value, segmentID: Key, segmentStartNumber: Value.Number, previousBlockFingerprint: Value.Digest) -> (Value, Mapping<Value.Digest, Key>, Mapping<Key, Key>) {
        return self[firstPath]!.insert(currentSegmentID: firstPath, path: path, segment: segment, segmentID: segmentID, segmentStartNumber: segmentStartNumber, previousBlockFingerprint: previousBlockFingerprint)
    }
    
    func changeParentConfirmations(additions: Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>, removals: Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>, additionsTrie: TrieMapping<Value.SegmentID, [Value.Digest]>, removalsTrie: TrieMapping<Value.SegmentID, [Value.Digest]>, blockNumbers: Mapping<Value.Digest, Value.Number>) -> Self {
        if additionsTrie.isEmpty() && removalsTrie.isEmpty() { return self }
        return elements().reduce(Mapping<Key, Value>()) { (result, entry) -> Mapping<Key, Value> in
            let additionsForSegment = additionsTrie[[entry.0]] ?? []
            let currentAdditions = additionsForSegment.reduce(Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>()) { (adds, potential) -> Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>> in
                return adds.setting(key: potential, value: additions[potential]!)
            }
            let removalsForSegment = removalsTrie[[entry.0]] ?? []
            let currentRemovals = removalsForSegment.reduce(Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>()) { (rms, potential) -> Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>> in
                return rms.setting(key: potential, value: removals[potential]!)
            }
            return result.setting(key: entry.0, value: entry.1.changeParentConfirmations(currentAdditions: currentAdditions, currentRemovals: currentRemovals, additions: additions, removals: removals, additionsTrie: additionsTrie.subtree(keys: [entry.0]), removalsTrie: removalsTrie.subtree(keys: [entry.0]), blockNumbers: blockNumbers))
        }
    }
    
    func getAllChildConfirmations(ignore path: ArraySlice<Key>, keep: ArraySlice<Key>) -> Mapping<Value.BlockRepresentationType.ChainName, Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>> {
        guard let firstPath = path.first else { return getAllChildConfirmations(keep: keep) }
        guard let segment = self[firstPath] else { return Mapping<Value.BlockRepresentationType.ChainName, Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>>() }
        return segment.childSegments.getAllChildConfirmations(ignore: path.dropFirst(), keep: keep)
    }
    
    func getAllChildConfirmations(keep: ArraySlice<Key>) -> Mapping<Value.BlockRepresentationType.ChainName, Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>> {
        guard let firstKeep = keep.first else { return Mapping<Value.BlockRepresentationType.ChainName, Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>>() }
        guard let segmentExamined = self[firstKeep] else { return Mapping<Value.BlockRepresentationType.ChainName, Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>>() }
        let rest = segmentExamined.childSegments.getAllChildConfirmations(keep: keep.dropFirst())
        return segmentExamined.allBlocksAndChildConfirmations().elements().reduce(rest) { result, entry in
            let chainName = entry.0
            let current = result[chainName] ?? Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>()
            let valueToSet = entry.1.elements().reduce(current) { result1, entry1 in
                let currentVal = result1[entry1.0] ?? Mapping<Value.Digest, Value.Number>()
                let valSet = entry1.1.elements().reduce(currentVal) { result2, entry2 in
                    return result2.setting(key: entry2.0, value: entry2.1)
                }
                return result1.setting(key: entry1.0, value: valSet)
            }
            return result.setting(key: chainName, value: valueToSet)
        }
    }
}
