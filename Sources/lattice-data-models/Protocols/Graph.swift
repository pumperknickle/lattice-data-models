import Foundation
import AwesomeDictionary
import AwesomeTrie
import Bedrock

public protocol Graph: Codable {
    associatedtype SegmentType: Segment
    typealias BlockRepresentationType = SegmentType.BlockRepresentationType
    typealias ChainName = BlockRepresentationType.ChainName
    typealias Digest = SegmentType.Digest
    typealias Number = SegmentType.Number
    typealias SegmentID = SegmentType.SegmentID
    
    // root segments
    var rootSegments: Mapping<SegmentID, SegmentType> { get }
    // root orphans previous block (blocks where we haven't validated the previous block)
    var orphans: Mapping<Digest, SegmentID> { get }
    // parent of segment -> segment, root segments have no parents
    var segmentParents: Mapping<SegmentID, SegmentID> { get }
    // blocks -> segment that block lives in
    var blocks: Mapping<Digest, SegmentID> { get }
    var childChains: Mapping<ChainName, Self> { get }
    // block fingerprint -> block number
    var blockNumbers: Mapping<Digest, Number> { get }
    // if tip is empty, no genesis block exists yet
    var tip: Digest? { get }
    var maxLength: Int? { get }
    
    init(rootSegments: Mapping<SegmentID, SegmentType>, orphans: Mapping<Digest, SegmentID>, segmentParents: Mapping<SegmentID, SegmentID>, blocks: Mapping<Digest, SegmentID>, childChains: Mapping<ChainName, Self>, blockNumbers: Mapping<Digest, Number>, tip: Digest?, maxLength: Int?)
}

public extension Graph {
    func createNew(maxLength: Int?) -> Self {
        return Self(rootSegments: Mapping<SegmentID, SegmentType>(), orphans: Mapping<Digest, SegmentID>(), segmentParents: Mapping<SegmentID, SegmentID>(), blocks: Mapping<Digest, SegmentID>(), childChains: Mapping<ChainName, Self>(), blockNumbers: Mapping<Digest, Number>(), tip: nil, maxLength: maxLength)
    }
    
    func getTipNumber() -> Number? {
        guard let tip = tip else { return nil }
        return blockNumbers[tip]
    }
    
    func changing(rootSegments: Mapping<SegmentID, SegmentType>? = nil, orphans: Mapping<Digest, SegmentID>? = nil, segmentParents: Mapping<SegmentID, SegmentID>? = nil, blocks: Mapping<Digest, SegmentID>? = nil, childChains: Mapping<ChainName, Self>? = nil, blockNumbers: Mapping<Digest, Number>? = nil) -> Self {
        return Self(rootSegments: rootSegments ?? self.rootSegments, orphans: orphans ?? self.orphans, segmentParents: segmentParents ?? self.segmentParents, blocks: blocks ?? self.blocks, childChains: childChains ?? self.childChains, blockNumbers: blockNumbers ?? self.blockNumbers, tip: tip, maxLength: maxLength)
    }
    
    func changing(tip: Digest? = nil) -> Self {
        return Self(rootSegments: rootSegments, orphans: orphans, segmentParents: segmentParents, blocks: blocks, childChains: childChains, blockNumbers: blockNumbers, tip: tip, maxLength: maxLength)
    }
    
    func insert(block: BlockRepresentationType, blockNumber: Number, previousBlockFingerprint: Digest, blockTrie: TrieMapping<ChainName, BlockRepresentationType>, blockNumbers: TrieMapping<ChainName, Number>, previousBlockFingerprints: TrieMapping<ChainName, Digest>) -> Self {
        let newChildChains = childChains.insert(blockTrie: blockTrie, blockNumbers: blockNumbers, previousBlockFingerprints: previousBlockFingerprints)
        return changing(childChains: newChildChains).insert(block: block, blockNumber: blockNumber, previousBlockFingerprint: previousBlockFingerprint)
    }
    
    // remove orphans that have starting block < tipNumber - max length
    // remove beginning blocks
    func trimmingStart() -> Self {
        guard let tipNumber = getTipNumber() else { return self }
        guard let maxLength = maxLength else { return self }
        let chainSegmentSet = Set(chainSegments())
        let orphanValues = orphans.elements().reduce(Mapping<SegmentID, Digest>()) { result, entry in
            return result.setting(key: entry.1, value: entry.0)
        }
        let minStartNumber = tipNumber.advanced(by: -1 * maxLength)
        let newRoots = rootSegments.elements().reduce(Mapping<SegmentID, SegmentType>()) { result, entry in
            if !orphanValues.contains(entry.0) {
                return result.setting(key: entry.0, value: entry.1.trimming(minStartNumber: minStartNumber))
            }
            if entry.1.firstBlockNumber >= minStartNumber {
                return result.setting(key: entry.0, value: entry.1)
            }
        }
        
    }
    
    func clean(segmentID: SegmentID) -> Self {
        guard let parent = segmentParents[segmentID] else { return self }
        let newSegmentParents = segmentParents.deleting(key: segmentID)
        return changing(segmentParents: newSegmentParents).clean(segmentID: parent)
    }
    
    func trimmingStart(segments: ArraySlice<(SegmentID, SegmentType)>, minStartNumber: Number, orphanValues: Mapping<SegmentID, Digest>) -> Self {
        guard let firstSegmentTuple = segments.first else { return self }
        guard let orphanDigest = orphanValues[firstSegmentTuple.0] else {
            let trimTuple = firstSegmentTuple.1.trimming(minStartNumber: minStartNumber, currentSegmentID: firstSegmentTuple.0, removedBlockDigests: TrieBasedSet<Digest>())
            let newRootSegments = rootSegments.deleting(key: firstSegmentTuple.0).setting(key: trimTuple.1, value: trimTuple.0)
            let newBlocks
            return changing(rootSegments:)
        }
        
    }
    
    func insert(block: BlockRepresentationType, blockNumber: Number, previousBlockFingerprint: Digest) -> Self {
        if blocks.contains(block.blockHash) { return self }
        if tip != nil && blockNumbers[tip!]!.advanced(by: -1 * maxLength) > blockNumber { return self }
        let newBlockNumbers = blockNumbers.setting(key: block.blockHash, value: blockNumber)
        if let orphanSegment = orphans[block.blockHash] {
            let newSegment = rootSegments[orphanSegment]!.addToStart(block: block, blockNumber: blockNumber)
            if blockNumbers[previousBlockFingerprint] == nil {
                let newOrphans = orphans.setting(key: previousBlockFingerprint, value: orphanSegment)
                let newRootSegments = rootSegments.setting(key: orphanSegment, value: newSegment)
                let newBlocks = blocks.setting(key: block.blockHash, value: orphanSegment)
                return changing(rootSegments: newRootSegments, orphans: newOrphans, blocks: newBlocks, blockNumbers: newBlockNumbers)
            }
            let newOrphans = orphans.deleting(key: block.blockHash)
            return changing(orphans: newOrphans, blockNumbers: newBlockNumbers).insertSegment(segment: newSegment, segmentID: orphanSegment, previousBlockFingerPrint: previousBlockFingerprint, blockNumber: blockNumber).trimmingStart()
        }
        let newSegment = SegmentType.createWithSingleBlock(block: block, blockNumber: blockNumber)
        let newSegmentID = SegmentID.random()
        if blockNumbers[previousBlockFingerprint] == nil {
            let newRootSegments = rootSegments.setting(key: newSegmentID, value: newSegment)
            let newOrphans = orphans.setting(key: previousBlockFingerprint, value: newSegmentID)
            let newBlocks = blocks.setting(key: block.blockHash, value: newSegmentID)
            return changing(rootSegments: newRootSegments, orphans: newOrphans, blocks: newBlocks, blockNumbers: newBlockNumbers)
        }
        return changing(blockNumbers: newBlockNumbers).insertSegment(segment: newSegment, segmentID: newSegmentID, previousBlockFingerPrint: previousBlockFingerprint, blockNumber: blockNumber).trimmingStart()
    }
    
    func insertSegment(segment: SegmentType, segmentID: SegmentID, previousBlockFingerPrint: Digest, blockNumber: Number) -> Self {
        let path = parentSegments(blockFingerprint: previousBlockFingerPrint)
        guard let firstPath = path.first else { return self }
        let newSegmentAndDelta = rootSegments.insert(firstPath: firstPath, path: path.dropFirst(), segment: segment, segmentID: segmentID, previousBlockFingerprint: previousBlockFingerPrint)
        let newBlocks = newSegmentAndDelta.1.elements().reduce(blocks) { result, entry in
            return result.setting(key: entry.0, value: entry.1)
        }
        let newRootSegments = rootSegments.setting(key: segmentID, value: newSegmentAndDelta.0)
        let newSegmentParents = newSegmentAndDelta.2.elements().reduce(segmentParents) { result, entry in
            return result.setting(key: entry.0, value: entry.1)
        }
        let newGraph = changing(rootSegments: newRootSegments, segmentParents: newSegmentParents, blocks: newBlocks)
        if previousBlockFingerPrint == tip {
            let confirmationsAndTip = segment.getParentConfirmationsAndTip()
            let newChildChains = confirmationsAndTip.0.elements().reduce(newGraph.childChains) { result, entry in
                guard let childChain = result[entry.0] else { return result }
                let newChain = childChain.changeParentConfirmations(additions: entry.1)
                return result.setting(key: entry.0, value: newChain)
            }
            return changing(childChains: newChildChains).changing(tip: confirmationsAndTip.1)
        }
        return newGraph.reorganizeWithNewTip()
    }

    // insert new cross linked parent confs with parent chain reorg
    // additions: child block fingerprint -> Mapping (Parent block fingerprint -> parent block number)
    func changeParentConfirmations(additions: Mapping<Digest, Mapping<Digest, Number>> = Mapping<Digest, Mapping<Digest, Number>>(), removals: Mapping<Digest, Mapping<Digest, Number>> = Mapping<Digest, Mapping<Digest, Number>>()) -> Self {
        let additionsTrie = additions.elements().reduce(TrieMapping<SegmentID, [Digest]>()) { (result, entry) -> TrieMapping<SegmentID, [Digest]> in
            let route = parentSegments(blockFingerprint: entry.0)
            if route == [] { return result }
            return result.setting(keys: route, value: (result[route] ?? []) + [entry.0])
        }
        let removalsTrie = removals.elements().reduce(TrieMapping<SegmentID, [Digest]>()) { (result, entry) -> TrieMapping<SegmentID, [Digest]> in
            let route = parentSegments(blockFingerprint: entry.0)
            if route == [] { return result }
            return result.setting(keys: route, value: (result[route] ?? []) + [entry.0])
        }
        let blockNumbers = (removals.keys() + additions.keys()).reduce(Mapping<Digest, Number>()) { (result, entry) -> Mapping<Digest, Number> in
            return result.setting(key: entry, value: self.blockNumbers[entry]!)
        }
        let newRootSegments = rootSegments.changeParentConfirmations(additions: additions, removals: removals, additionsTrie: additionsTrie, removalsTrie: removalsTrie, blockNumbers: blockNumbers)
        return changing(rootSegments: newRootSegments, blocks: blocks, blockNumbers: blockNumbers).reorganizeWithNewTip()
    }
    
    // find the new chain tip and recompute child
    func reorganizeWithNewTip() -> Self {
        let rootsWithoutOrphans = orphans.values().reduce(rootSegments) { result, entry in
            return result.deleting(key: entry)
        }
        let newTip = rootsWithoutOrphans.computeTip()
        if newTip == tip { return self }
        let oldSegments = tip == nil ? [] : parentSegments(blockFingerprint: tip!)
        let newSegments = newTip == nil ? [] : parentSegments(blockFingerprint: newTip!)
        let diff = tailDifference(lhs: ArraySlice(oldSegments), rhs: ArraySlice(newSegments))
        let oldPath = oldSegments.dropLast(diff.0.count)
        let newPath = newSegments.dropLast(diff.1.count)
        let removals = rootSegments.getAllChildConfirmations(ignore: ArraySlice(oldPath), keep: ArraySlice(diff.0))
        let additions = rootSegments.getAllChildConfirmations(ignore: ArraySlice(newPath), keep: ArraySlice(diff.1))
        let newChildChains = Set(removals.keys()).union(additions.keys()).reduce(childChains) { result, entry in
            let removalsForChain = removals[entry] ?? Mapping<Digest, Mapping<Digest, Number>>()
            let additionsForChain = additions[entry] ?? Mapping<Digest, Mapping<Digest, Number>>()
            guard let childChain = result[entry] else { return result }
            let newChildChain = childChain.changeParentConfirmations(additions: additionsForChain, removals: removalsForChain)
            return result.setting(key: entry, value: newChildChain)
        }
        return changing(childChains: newChildChains).changing(tip: newTip)
    }
    
    func chainSegments() -> [SegmentID] {
        guard let tip = tip else { return [] }
        guard let tipSegment = blocks[tip] else { return [] }
        return parentSegments(segment: tipSegment)
    }
    
    func parentSegments(blockFingerprint: Digest) -> [SegmentID] {
        guard let parentSegment = blocks[blockFingerprint] else { return [] }
        return parentSegments(segment: parentSegment)
    }
    
    func parentSegments(segment: SegmentID) -> [SegmentID] {
        guard let segmentParent = segmentParents[segment] else { return [segment] }
        return [segment] + parentSegments(segment: segmentParent)
    }
    
    func inChain(blockFingerPrints: [Digest]) -> [Digest] {
        let chainSegs = Set(chainSegments())
        return blockFingerPrints.filter { self.blocks[$0] != nil }.filter { chainSegs.contains(self.blocks[$0]!) }
    }
    
    func inChain(blockFingerprint: Digest) -> Bool {
        guard let segmentID = blocks[blockFingerprint] else { return false }
        return chainSegments().contains(segmentID)
    }
}

func tailDifference<T: Comparable>(lhs: ArraySlice<T>, rhs: ArraySlice<T>) -> ([T], [T]) {
    guard let firstLeft = lhs.first, let firstRight = rhs.first else { return (Array(lhs), Array(rhs)) }
    if firstLeft == firstRight { return tailDifference(lhs: lhs.dropFirst(), rhs: rhs.dropFirst()) }
    return (Array(lhs), Array(rhs))
}

public extension Mapping where Value: Graph, Key == Value.ChainName {
    func insert(blockTrie: TrieMapping<Key, Value.BlockRepresentationType>, blockNumbers: TrieMapping<Key, Value.Number>, previousBlockFingerprints: TrieMapping<Key, Value.Digest>) -> Self {
        return blockTrie.children.keys().reduce(self) { result, entry in
            guard let block = blockTrie[[entry]], let blockNumber = blockNumbers[[entry]], let previousBlockFingerprint = previousBlockFingerprints[[entry]] else { return result }
            guard let childChain = result[entry] else { return result }
            let newChildChain = childChain.insert(block: block, blockNumber: blockNumber, previousBlockFingerprint: previousBlockFingerprint, blockTrie: blockTrie.subtree(keys: [entry]), blockNumbers: blockNumbers.subtree(keys: [entry]), previousBlockFingerprints: previousBlockFingerprints.subtree(keys: [entry]))
            return result.setting(key: entry, value: newChildChain)
        }
    }
}
