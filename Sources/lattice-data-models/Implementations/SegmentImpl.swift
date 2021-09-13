import Foundation
import Bedrock
import AwesomeDictionary

public struct SegmentImpl {
    private let rawEarliestParent: Number?
    private let rawTipNumber: Number
    private let rawLastBlockNumber: Number
    private let rawFirstBlockNumber: Number
    private let rawLatestBlockDifficultyTarget: Digest
    private let rawBlocks: Mapping<Number, BlockRepresentationType>
    private let rawChildSegments: Mapping<SegmentID, Self>
}

extension SegmentImpl: Segment {
    public typealias BlockRepresentationType = BlockRepresentationImpl
    public typealias SegmentID = UInt256
    
    public var earliestParent: Number? { return rawEarliestParent }
    public var tipNumber: Number { return rawTipNumber }
    public var lastBlockNumber: Number { return rawLastBlockNumber }
    public var firstBlockNumber: Number { return rawFirstBlockNumber }
    public var latestBlockDifficultyTarget: Digest { return rawLatestBlockDifficultyTarget }
    public var blocks: Mapping<Number, BlockRepresentationType> { return rawBlocks }
    public var childSegments: Mapping<SegmentID, Self> { return rawChildSegments }
    
    public init(tipNumber: Number, earliestParent: Number?, lastBlockNumber: Number, firstBlockNumber: Number, latestBlockDifficultyTarget: Digest, blocks: Mapping<Number, BlockRepresentationType>, childSegments: Mapping<SegmentID, Self>) {
        self.rawTipNumber = tipNumber
        self.rawEarliestParent = earliestParent
        self.rawLastBlockNumber = lastBlockNumber
        self.rawFirstBlockNumber = firstBlockNumber
        self.rawLatestBlockDifficultyTarget = latestBlockDifficultyTarget
        self.rawBlocks = blocks
        self.rawChildSegments = childSegments
    }
}
