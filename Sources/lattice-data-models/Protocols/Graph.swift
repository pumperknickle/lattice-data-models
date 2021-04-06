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
    // root orphans previous block
    var orphans: Mapping<SegmentID, Digest> { get }
    // parent of segment -> segment, root segments have no parents
    var segmentParents: Mapping<SegmentID, SegmentID> { get }
    // blocks -> segment that block lives in
    var blocks: Mapping<Digest, SegmentID> { get }
    // child (non validated block on this chain) -> <parent -> blocknumber>
    var orphanParentConfirmations: Mapping<Digest, Mapping<Digest, Number>> { get }
    var childChains: Mapping<ChainName, Self> { get }
    // block fingerprint -> block number
    var blockNumbers: Mapping<Digest, Number> { get }
    var tip: Digest { get }
    
    init(rootSegments: Mapping<SegmentID, SegmentType>, orphans: Mapping<SegmentID, Digest>, segmentParents: Mapping<SegmentID, SegmentID>, blocks: Mapping<Digest, SegmentID>, orphanParentConfirmations: Mapping<Digest, Mapping<Digest, Number>>, childChains: Mapping<ChainName, Self>, blockNumbers: Mapping<Digest, Number>, tip: Digest)
}

public extension Graph {
    func changing(rootSegments: Mapping<SegmentID, SegmentType>? = nil, orphans: Mapping<SegmentID, Digest>? = nil, segmentParents: Mapping<SegmentID, SegmentID>? = nil, blocks: Mapping<Digest, SegmentID>? = nil, orphanParentConfirmations: Mapping<Digest, Mapping<Digest, Number>>? = nil, childChains: Mapping<ChainName, Self>? = nil, blockNumbers: Mapping<Digest, Number>? = nil, tip: Digest? = nil) -> Self {
        return Self(rootSegments: rootSegments ?? self.rootSegments, orphans: orphans ?? self.orphans, segmentParents: segmentParents ?? self.segmentParents, blocks: blocks ?? self.blocks, orphanParentConfirmations: orphanParentConfirmations ?? self.orphanParentConfirmations, childChains: childChains ?? self.childChains, blockNumbers: blockNumbers ?? self.blockNumbers, tip: tip ?? self.tip)
    }
    
    func insert(path: [ChainName], block: BlockRepresentationType, previousBlockFingerprint: Digest) -> Self {
        guard let firstChain = path.first else { return insert(block: block, previousBlockFingerprint: previousBlockFingerprint) }
        guard let childChain = childChains[firstChain] else { return self }
        return changing(childChains: childChains.setting(key: firstChain, value: childChain.insert(path: Array(path.dropFirst()), block: block, previousBlockFingerprint: previousBlockFingerprint)))
    }
    
    func insert(block: BlockRepresentationType, previousBlockFingerprint: Digest) -> Self {
        return self
    }

//    func changeParentConfirmations(additions: Mapping<Digest, Mapping<Digest, Number>>, removals: Mapping<Digest, Mapping<Digest, Number>>) -> Self {
//        let additionsTrie = additions.elements().reduce(TrieMapping<SegmentID, [Digest]>()) { (result, entry) -> TrieMapping<SegmentID, [Digest]> in
//            let route = parentSegments(blockFingerprint: entry.0)
//            if route == [] { return result }
//            return result.setting(keys: route, value: (result[route] ?? []) + [entry.0])
//        }
//        let removalsTrie = removals.elements().reduce(TrieMapping<SegmentID, [Digest]>()) { (result, entry) -> TrieMapping<SegmentID, [Digest]> in
//            let route = parentSegments(blockFingerprint: entry.0)
//            if route == [] { return result }
//            return result.setting(keys: route, value: (result[route] ?? []) + [entry.0])
//        }
//        let blockNumbers = (removals.keys() + additions.keys()).reduce(Mapping<Digest, Number>()) { (result, entry) -> Mapping<Digest, Number> in
//            return result.setting(key: entry, value: self.blockNumbers[entry]!)
//        }
//        let newRootSegments = rootSegments.changeParentConfirmations(additions: additions, removals: removals, additionsTrie: additionsTrie, removalsTrie: removalsTrie, blockNumbers: blockNumbers)
//        
//    }
    
    func chainSegments() -> [SegmentID] {
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
        let chainSegs = chainSegments()
        return blockFingerPrints.filter { self.blocks[$0] != nil }.filter { chainSegs.contains(self.blocks[$0]!) }
    }
    
    func inChain(blockFingerprint: Digest) -> Bool {
        guard let segmentID = blocks[blockFingerprint] else { return false }
        return chainSegments().contains(segmentID)
    }
}
