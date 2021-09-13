//
//  Represents a validated block in memory/storage

import Foundation
import Bedrock
import AwesomeDictionary

public protocol BlockRepresentation: Codable {
    associatedtype Digest: Stringable
    associatedtype Number: BinaryEncodable, FixedWidthInteger, IntConvertible
    associatedtype ChainName: Stringable

    var blockHash: Digest { get }
    var nextDifficulty: Digest { get }
    var directParents: [Digest] { get }
    var parentBlockNumbers: Mapping<Digest, Number> { get }
    var childBlockConfirmations: Mapping<ChainName, Digest> { get }
    
    init(blockHash: Digest, nextDifficulty: Digest, directParents: [Digest], parentBlockNumbers: Mapping<Digest, Number>, childBlockConfirmations: Mapping<ChainName, Digest>)
}

public extension BlockRepresentation {
    func earliestParent() -> Number? {
        guard let firstParentHash = directParents.first else { return nil }
        return parentBlockNumbers[firstParentHash]
    }
    
    func totalParents() -> Int {
        return directParents.count
    }
    
    func addParent(hash: Digest, parentBlockNumber: Number) -> Self {
        return addParent(hash: hash, parentBlockNumber: parentBlockNumber, index: 0)
    }
    
    func addParent(hash: Digest, parentBlockNumber: Number, index: Int) -> Self {
        if index >= directParents.count { return Self(blockHash: blockHash, nextDifficulty: nextDifficulty, directParents: directParents + [hash], parentBlockNumbers: parentBlockNumbers.setting(key: hash, value: parentBlockNumber), childBlockConfirmations: childBlockConfirmations) }
        let comparableBlock = directParents[index]
        if parentBlockNumber < parentBlockNumbers[comparableBlock]! {
            return Self(blockHash: blockHash, nextDifficulty: nextDifficulty, directParents: Array(directParents[0..<index]) + [hash] + Array(directParents[index..<directParents.count]), parentBlockNumbers: parentBlockNumbers.setting(key: hash, value: parentBlockNumber), childBlockConfirmations: childBlockConfirmations)
        }
        return addParent(hash: hash, parentBlockNumber: parentBlockNumber, index: index + 1)
    }

    func removeParent(hash: Digest) -> Self? {
        return removeParent(hash: hash, index: 0)
    }
    
    func removeParent(hash: Digest, index: Int) -> Self? {
        if index >= directParents.count { return nil }
        let comparableBlock = directParents[index]
        if comparableBlock == hash {
            return Self(blockHash: blockHash, nextDifficulty: nextDifficulty, directParents: Array(directParents[0..<index]) + Array(directParents[index+1..<directParents.count]), parentBlockNumbers: parentBlockNumbers.deleting(key: hash), childBlockConfirmations: childBlockConfirmations)
        }
        return removeParent(hash: hash, index: index + 1)
    }
}


