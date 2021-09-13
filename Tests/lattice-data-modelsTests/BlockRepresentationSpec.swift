import Foundation
import Nimble
import Quick
import AwesomeDictionary
@testable import lattice_data_models

final class BlockRepresentationSpec: QuickSpec {
    override func spec() {
        typealias BlockRepresenationType = BlockRepresentationImpl
        typealias Digest = BlockRepresenationType.Digest
        typealias Number = BlockRepresenationType.Number
        typealias ChainName = BlockRepresenationType.ChainName
        let firstParentBlockHash = Digest.random()
        let directParents = [firstParentBlockHash]
        let parentBlockNumber = Digest(20)
        let parentBlockNumbers = Mapping<Digest, Number>().setting(key: firstParentBlockHash, value: parentBlockNumber)
        let childBlockHash = Digest.random()
        let childBlockConfirmations = Mapping<ChainName, Digest>().setting(key: "testChildChain", value: childBlockHash)
        let block = BlockRepresenationType(blockHash: Digest.random(), nextDifficulty: Digest.random(), directParents: directParents, parentBlockNumbers: parentBlockNumbers, childBlockConfirmations: childBlockConfirmations)
        let newParentHash = Digest.random()
        let newParentBlocknumber = parentBlockNumber.advanced(by: -1)
        let blockWithAddedParent = block.addParent(hash: newParentHash, parentBlockNumber: newParentBlocknumber)
        it("should correctly add parent before current single parent with lower block number") {
            expect(block.directParents.first).toNot(beNil())
            expect(block.directParents.first!).to(equal(firstParentBlockHash))
            expect(block.earliestParent()).to(equal(parentBlockNumber))
            expect(blockWithAddedParent.directParents.first).toNot(beNil())
            expect(blockWithAddedParent.directParents.first!).to(equal(newParentHash))
            expect(blockWithAddedParent.earliestParent()).to(equal(newParentBlocknumber))
        }
        it("should correctly remove parent") {
            let blockWithRemoval = blockWithAddedParent.removeParent(hash: newParentHash)
            expect(blockWithRemoval).toNot(beNil())
            expect(blockWithRemoval!.directParents.first).toNot(beNil())
            expect(blockWithRemoval!.directParents.first!).to(equal(firstParentBlockHash))
            expect(blockWithRemoval!.earliestParent()).to(equal(parentBlockNumber))
            let secondBlockWithRemoval = blockWithAddedParent.removeParent(hash: firstParentBlockHash)
            expect(secondBlockWithRemoval).toNot(beNil())
            expect(secondBlockWithRemoval!.directParents.first).toNot(beNil())
            expect(secondBlockWithRemoval!.directParents.first!).to(equal(newParentHash))
            expect(secondBlockWithRemoval!.earliestParent()).to(equal(newParentBlocknumber))
        }
    }
}
