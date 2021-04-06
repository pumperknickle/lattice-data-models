//
//  An "unchallenged" continuous sequence of validated blocks
//

import Foundation
import AwesomeDictionary
import Bedrock
import AwesomeTrie

public protocol Segment: Codable {
    associatedtype BlockRepresentationType: BlockRepresentation
    associatedtype SegmentID: Stringable, Randomizable
    typealias Digest = BlockRepresentationType.Digest
    typealias Number = BlockRepresentationType.Number
    
    var id: SegmentID { get }
    var totalParents: Int { get }
    var earliestParent: Number? { get }
    var latestBlock: Number { get }
    var blocks: Mapping<Number, BlockRepresentationType> { get }
    var childSegments: Mapping<SegmentID, Self> { get }
    
    init(id: SegmentID?, totalParents: Int, earliestParent: Number?, latestBlock: Number, blocks: Mapping<Number, BlockRepresentationType>, childSegments: Mapping<SegmentID, Self>)
}

public extension Segment {
    func changing(totalParents: Int? = nil, latestBlock: Number? = nil, blocks: Mapping<Number, BlockRepresentationType>? = nil, childSegments: Mapping<SegmentID, Self>? = nil) -> Self {
        return Self(id: id, totalParents: totalParents ?? self.totalParents, earliestParent: earliestParent, latestBlock: latestBlock ?? self.latestBlock, blocks: blocks ?? self.blocks, childSegments: childSegments ?? self.childSegments)
    }
    
    func changing(earliestParent: Number?) -> Self {
        return Self(id: id, totalParents: totalParents, earliestParent: earliestParent, latestBlock: latestBlock, blocks: blocks, childSegments: childSegments)
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
        return changing(totalParents: totalParents + 1, blocks: blocks.setting(key: blockNumber, value: newBlock)).changing(earliestParent: newEarliest)
    }
    
    func removeParent(blockNumber: Number, parent: Digest, blockNumberOfParent: Number) -> Self {
        guard let newBlock = blocks[blockNumber]!.removeParent(hash: parent) else { return self }
        let newSegment = changing(totalParents: totalParents - 1, blocks: blocks.setting(key: blockNumber, value: newBlock))
        return blockNumberOfParent == earliestParent ? newSegment.updateEarliestParent() : newSegment
    }
    
    func changeParentConfirmations(currentAdditions: Mapping<Digest, Mapping<Digest, Number>>, currentRemovals: Mapping<Digest, Mapping<Digest, Number>>, additions: Mapping<Digest, Mapping<Digest, Number>>, removals: Mapping<Digest, Mapping<Digest, Number>>, additionsTrie: TrieMapping<SegmentID, [Digest]>, removalsTrie: TrieMapping<SegmentID, [Digest]>, blockNumbers: Mapping<Digest, Number>) -> Self {
        let segmentParents = totalParentsForThisSegment()
        let newChildSegments = childSegments.changeParentConfirmations(additions: additions, removals: removals, additionsTrie: additionsTrie, removalsTrie: removalsTrie, blockNumbers: blockNumbers)
        let newTotalParents = newChildSegments.values().map { $0.totalParents }.reduce(0, +) + segmentParents
        let updatedEarliest = earliestParent != nil && childSegments.values().map { $0.earliestParent }.contains(earliestParent) ? updateEarliestParent() : self
        let addedCurrentAdditions = currentAdditions.elements().reduce(updatedEarliest.changing(totalParents: newTotalParents)) { (result, entry) -> Self in
            return result.addParents(blockNumber: blockNumbers[entry.0]!, parents: entry.1)
        }
        return currentRemovals.elements().reduce(addedCurrentAdditions) { (result, entry) -> Self in
            return result.removeParents(blockNumber: blockNumbers[entry.0]!, parents: entry.1)
        }
    }
    
    func updateEarliestParent() -> Self {
        return changing(earliestParent: findEarliestParent())
    }
    
    func findEarliestParent() -> Number? {
        let currentMinOpt = blocks.elements().map { $0.1.parentBlockNumbers.values() }.reduce([], +)
        guard let currentMin = currentMinOpt.min() else { return nil }
        return childSegments.values().map { $0.earliestParent }.reduce(currentMin) { (result, entry) -> Number in
            guard let entry = entry else { return result }
            return min(entry, result)
        }
    }
    
    func totalParentsForThisSegment() -> Int {
        return totalParents - childSegments.values().map { $0.totalParents }.reduce(0, +)
    }
    
    func allBlocksAndChildConfirmations() -> Mapping<BlockRepresentationType.ChainName, [BlockRepresentationType]> {
        return blocks.values().reduce(Mapping<BlockRepresentationType.ChainName, [BlockRepresentationType]>()) { (result, entry) -> Mapping<BlockRepresentationType.ChainName, [BlockRepresentationType]> in
            return result.merge(with: entry.allBlockInfoAndChildConfirmations(), combine: +)
        }
    }
}

public extension Mapping where Value: Segment, Key == Value.SegmentID {
    func changeParentConfirmations(additions: Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>, removals: Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>, additionsTrie: TrieMapping<Value.SegmentID, [Value.Digest]>, removalsTrie: TrieMapping<Value.SegmentID, [Value.Digest]>, blockNumbers: Mapping<Value.Digest, Value.Number>) -> Self {
        return elements().reduce(Mapping<Key, Value>()) { (result, entry) -> Mapping<Key, Value> in
            let additionsForSegment = additionsTrie[[entry.0]] ?? []
            let currentAdditions = additionsForSegment.reduce(Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>()) { (adds, potential) -> Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>> in
                return adds.setting(key: potential, value: adds[potential]!)
            }
            let removalsForSegment = removalsTrie[[entry.0]] ?? []
            let currentRemovals = removalsForSegment.reduce(Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>>()) { (rms, potential) -> Mapping<Value.Digest, Mapping<Value.Digest, Value.Number>> in
                return rms.setting(key: potential, value: rms[potential]!)
            }
            return result.setting(key: entry.0, value: entry.1.changeParentConfirmations(currentAdditions: currentAdditions, currentRemovals: currentRemovals, additions: additions, removals: removals, additionsTrie: additionsTrie.subtree(keys: [entry.0]), removalsTrie: removalsTrie.subtree(keys: [entry.0]), blockNumbers: blockNumbers))
        }
    }
}
