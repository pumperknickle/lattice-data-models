//
//  Tree of Chains
//
//

import Foundation
import AwesomeDictionary
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
    func insert(rootChainName: ChainName, path: [ChainName], block: BlockRepresentationType, previousBlockFingerprint: Digest) -> Self {
        guard let rootChain = rootChains[rootChainName] else { return self }
        return Self(rootChains: rootChains.setting(key: rootChainName, value: rootChain.insert(path: Array(path.dropFirst()), block: block, previousBlockFingerprint: previousBlockFingerprint)))
    }
}
