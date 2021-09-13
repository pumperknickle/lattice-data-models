import Foundation
import Bedrock
import AwesomeDictionary

public struct BlockRepresentationImpl {
    private let rawBlockHash: Digest
    private let rawNextDifficulty: Digest
    private let rawDirectParents: [Digest]
    private let rawParentBlockNumbers: Mapping<Digest, Number>
    private let rawChildBlockConfirmations: Mapping<ChainName, Digest>
}

extension BlockRepresentationImpl: BlockRepresentation {
    public typealias Digest = UInt256
    public typealias Number = UInt256
    public typealias ChainName = String
    
    public var blockHash: UInt256 { return rawBlockHash }
    public var nextDifficulty: UInt256 { return rawNextDifficulty }
    public var directParents: [UInt256] { return rawDirectParents }
    public var parentBlockNumbers: Mapping<UInt256, UInt256> { return rawParentBlockNumbers }
    public var childBlockConfirmations: Mapping<String, UInt256> { return rawChildBlockConfirmations }
    
    public init(blockHash: Digest, nextDifficulty: Digest, directParents: [Digest], parentBlockNumbers: Mapping<Digest, Number>, childBlockConfirmations: Mapping<ChainName, Digest>) {
        rawBlockHash = blockHash
        rawNextDifficulty = nextDifficulty
        rawDirectParents = directParents
        rawParentBlockNumbers = parentBlockNumbers
        rawChildBlockConfirmations = childBlockConfirmations
    }
}
