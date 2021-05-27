//
//  Tree of Chains
//
//

import Foundation
import AwesomeDictionary
import AwesomeTrie
import Bedrock

public protocol Lattice {
    associatedtype ChainType: Graph
    typealias Digest = ChainType.Digest
    typealias Number = ChainType.Number
    typealias ChainName = ChainType.ChainName
    typealias BlockRepresentationType = ChainType.BlockRepresentationType
    
    var rootChains: Mapping<ChainName, ChainType> { get }
    
    init(rootChains: Mapping<ChainName, ChainType>)
}

public extension Lattice {
    func insert(rootChainName: ChainName, block: BlockRepresentationType, blockTrie: TrieMapping<ChainName, BlockRepresentationType>, blockNumber: Number, blockNumbers: TrieMapping<ChainName, Number>, previousBlockFingerprint: Digest, previousBlockFingerprints: TrieMapping<ChainName, Digest>) -> Self {
        guard let rootChain = rootChains[rootChainName] else { return self }
        let newRootChain = rootChain.insert(block: block, blockNumber: blockNumber, previousBlockFingerprint: previousBlockFingerprint, blockTrie: blockTrie, blockNumbers: blockNumbers, previousBlockFingerprints: previousBlockFingerprints)
        let newRootChains = rootChains.setting(key: rootChainName, value: newRootChain)
        return Self(rootChains: newRootChains)
    }
//    
//    func insert(rootChainName: ChainName, path: ArraySlice<ChainName>, block: BlockRepresentationType, blockNumber: Number, previousBlockFingerprint: Digest) -> Self {
//        guard let rootChain = rootChains[rootChainName] else { return self }
//        let newRoot = rootChain.insert(path: path.dropFirst(), block: block, blockNumber: blockNumber, previousBlockFingerprint: previousBlockFingerprint)
//        return Self(rootChains: rootChains.setting(key: rootChainName, value: newRoot))
//    }
}
