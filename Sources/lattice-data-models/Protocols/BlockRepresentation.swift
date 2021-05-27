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
    
    init(blockHash: Digest, nextDiffiiculty: Digest, directParents: [Digest], parentBlockNumbers: Mapping<Digest, Number>, childBlockConfirmations: Mapping<ChainName, Digest>)
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
        return addParent(hash: hash, parentBlockNumber: parentBlockNumber, prefix: [], suffix: directParents)
    }
    
    func addParent(hash: Digest, parentBlockNumber: Number, prefix: [Digest], suffix: [Digest]) -> Self {
        guard let comparableBlock = suffix.first else { return Self(blockHash: blockHash, nextDiffiiculty: nextDifficulty, directParents: prefix + [hash], parentBlockNumbers: parentBlockNumbers.setting(key: hash, value: parentBlockNumber), childBlockConfirmations: childBlockConfirmations) }
        if parentBlockNumber < parentBlockNumbers[comparableBlock]! { return Self(blockHash: blockHash, nextDiffiiculty: nextDifficulty, directParents: prefix + [hash] + suffix, parentBlockNumbers: parentBlockNumbers.setting(key: hash, value: parentBlockNumber), childBlockConfirmations: childBlockConfirmations) }
        return addParent(hash: hash, parentBlockNumber: parentBlockNumber, prefix: prefix + [comparableBlock], suffix: Array(suffix.dropFirst()))
    }
    
    func removeParent(hash: Digest) -> Self? {
        return removeParent(hash: hash, prefix: [], suffix: directParents)
    }
    
    func removeParent(hash: Digest, prefix: [Digest], suffix: [Digest]) -> Self? {
        guard let comparableBlock = suffix.first else { return nil }
        if comparableBlock == hash { return Self(blockHash: blockHash, nextDiffiiculty: nextDifficulty, directParents: prefix + Array(suffix.dropFirst()), parentBlockNumbers: parentBlockNumbers.deleting(key: hash), childBlockConfirmations: childBlockConfirmations) }
        return removeParent(hash: hash, prefix: prefix + [comparableBlock], suffix: Array(suffix.dropFirst()))
    }
    
    // chain -> child hashes
    func allBlockInfoAndChildConfirmations() -> Mapping<ChainName, [Self]> {
        return childBlockConfirmations.keys().reduce(Mapping<ChainName, [Self]>()) { (result, entry) -> Mapping<ChainName, [Self]> in
            return result.setting(key: entry, value: [self])
        }
    }
}


