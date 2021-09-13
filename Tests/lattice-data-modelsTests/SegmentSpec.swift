import Foundation
import Nimble
import Quick
import AwesomeDictionary
import AwesomeTrie
@testable import lattice_data_models

final class SegmentSpec: QuickSpec {
    override func spec() {
        typealias SegmentType = SegmentImpl
        typealias BlockRepresentationType = SegmentType.BlockRepresentationType
        typealias Number = BlockRepresentationType.Number
        typealias Digest = BlockRepresentationType.Digest
        typealias SegmentID = SegmentType.SegmentID
        typealias ChainName = BlockRepresentationType.ChainName
        // segment comparisons
        describe("segment comparisons") {
            it("should choose segment with earlier parent") {
                let firstSegmentParentNumber = Number(12)
                let secondSegmentParentNumber = firstSegmentParentNumber.advanced(by: 1)
                let segment1 = SegmentType(tipNumber: Number(15), earliestParent: firstSegmentParentNumber, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                let segment2 = SegmentType(tipNumber: Number(14), earliestParent: secondSegmentParentNumber, lastBlockNumber: Number(14), firstBlockNumber: Number(14), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                expect(segment1 > segment2).to(beTrue())
            }
            it("should choose segment with parent if other segment parent is nil") {
                let firstSegmentParentNumber = Number(12)
                let segment1 = SegmentType(tipNumber: Number(15), earliestParent: firstSegmentParentNumber, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                let segment2 = SegmentType(tipNumber: Number(14), earliestParent: nil, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                expect(segment1 > segment2).to(beTrue())
            }
            it("should choose segment with greater tip number if earlier parents are nil") {
                let firstTipNumber = Number(12)
                let secondTipNumber = firstTipNumber.advanced(by: 1)
                let segment1 = SegmentType(tipNumber: firstTipNumber, earliestParent: nil, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                let segment2 = SegmentType(tipNumber: secondTipNumber, earliestParent: nil, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: Digest.random(), blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                expect(segment1 < segment2).to(beTrue())
            }
            it("should choose segment with greater difficulty target if tip numbers are equal") {
                let tipNumber = Number(12)
                let firstDifficultyTarget = Digest.random()
                let secondDifficultyTarget = firstDifficultyTarget.advanced(by: 1)
                let segment1 = SegmentType(tipNumber: tipNumber, earliestParent: nil, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: firstDifficultyTarget, blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                let segment2 = SegmentType(tipNumber: tipNumber, earliestParent: nil, lastBlockNumber: Number(15), firstBlockNumber: Number(15), latestBlockDifficultyTarget: secondDifficultyTarget, blocks: Mapping<Number, BlockRepresentationType>(), childSegments: Mapping<SegmentID, SegmentType>())
                expect(segment1 < segment2).to(beTrue())
            }
        }
        describe("get child confirmations") {
            let blockHash1 = Digest.random()
            let childChain1 = "Left"
            let childHash1 = Digest.random()
            let childConfirmations1 = Mapping<ChainName, Digest>().setting(key: childChain1, value: childHash1)
            let block1 = BlockRepresentationType(blockHash: blockHash1, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: childConfirmations1)
            let blockHash2 = Digest.random()
            let childChain2 = "Right"
            let childHash2 = Digest.random()
            let childConfirmations2 = Mapping<ChainName, Digest>().setting(key: childChain2, value: childHash2)
            let block2 = BlockRepresentationType(blockHash: blockHash2, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: childConfirmations2)
            let blockHash3 = Digest.random()
            let childChain3 = "Bottom"
            let childHash3 = Digest.random()
            let childConfirmations3 = Mapping<ChainName, Digest>().setting(key: childChain3, value: childHash3)
            let block3 = BlockRepresentationType(blockHash: blockHash3, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: childConfirmations3)
            let block3Number = Number(20)
            let segement2Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block3Number, value: block3)
            let segment2 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block3Number, firstBlockNumber: (15), latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segement2Blocks, childSegments: Mapping<SegmentID, SegmentType>())
            let segment2ID = SegmentID.random()
            let block2Number = block3Number.advanced(by: -1)
            let block1Number = block2Number.advanced(by: -1)
            let segment1Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block2Number, value: block2).setting(key: block1Number, value: block1)
            let segment1ID = SegmentID.random()
            let segment1 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block2Number, firstBlockNumber: block1Number, latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segment1Blocks, childSegments: Mapping<SegmentID, SegmentType>().setting(key: segment2ID, value: segment2))
            let segments = Mapping<SegmentID, SegmentType>().setting(key: segment1ID, value: segment1)
            it("should get all child confirmations") {
                let childConfs = segments.getAllChildConfirmations(keep: ArraySlice<SegmentID>([segment1ID, segment2ID]))
                expect(childConfs[childChain1]?[childHash1]?[blockHash1]).toNot(beNil())
                expect(childConfs[childChain1]?[childHash1]?[blockHash1]).to(equal(block1Number))
                expect(childConfs[childChain2]?[childHash2]?[blockHash2]).toNot(beNil())
                expect(childConfs[childChain2]?[childHash2]?[blockHash2]).to(equal(block2Number))
                expect(childConfs[childChain3]?[childHash3]?[blockHash3]).toNot(beNil())
                expect(childConfs[childChain3]?[childHash3]?[blockHash3]).to(equal(block3Number))
            }
        }
        describe("parent confirmations") {
            let blockHash1 = Digest.random()
            let block1 = BlockRepresentationType(blockHash: blockHash1, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let blockHash2 = Digest.random()
            let block2 = BlockRepresentationType(blockHash: blockHash2, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let blockHash3 = Digest.random()
            let block3 = BlockRepresentationType(blockHash: blockHash3, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block3Number = Number(20)
            let block2Number = block3Number.advanced(by: -1)
            let block1Number = block2Number.advanced(by: -1)
            let segement2Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block3Number, value: block3)
            let segment2 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block3Number, firstBlockNumber: block3Number, latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segement2Blocks, childSegments: Mapping<SegmentID, SegmentType>())
            let block3Parent = Digest.random()
            let block3ParentNumber = Number(10)
            let segment2ID = SegmentID.random()
            let block3Parents = Mapping<Digest, Number>().setting(key: block3Parent, value: block3ParentNumber)
            let segment2WithAParent = segment2.addParents(blockNumber: block3Number, parents: block3Parents)
            let segment1Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block2Number, value: block2).setting(key: block1Number, value: block1)
            let segment1 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block2Number, firstBlockNumber: block1Number, latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segment1Blocks, childSegments: Mapping<SegmentID, SegmentType>().setting(key: segment2ID, value: segment2WithAParent))
            let block2Parent = Digest.random()
            let block2ParentNumber = Number(9)
            let block2Parents = Mapping<Digest, Number>().setting(key: block2Parent, value: block2ParentNumber)
            let segment1WithAParent = segment1.addParents(blockNumber: block2Number, parents: block2Parents)
            it("should add and remove parent confirmations") {
                expect(segment1WithAParent.blocks[block2Number]).toNot(beNil())
                expect(segment1WithAParent.blocks[block2Number]!.directParents).to(contain(block2Parent))
                expect(segment1WithAParent.childSegments.first()!.1.blocks[block3Number]).toNot(beNil())
                expect(segment1WithAParent.childSegments.first()!.1.blocks[block3Number]!.directParents).to(contain(block3Parent))
                expect(segment2WithAParent.earliestParent).to(equal(block3ParentNumber))
                expect(segment1WithAParent.earliestParent).to(equal(block2ParentNumber))
                let block1Parent = Digest.random()
                let block1ParentNumber = Number(8)
                let currentAddition = Mapping<Digest, Mapping<Digest, Number>>().setting(key: blockHash1, value: Mapping<Digest, Number>().setting(key: block1Parent, value: block1ParentNumber))
                let blockParent4 = Digest.random()
                let blockParent4Number = Number(15)
                let currentRemoval = Mapping<Digest, Mapping<Digest, Number>>().setting(key: blockHash2, value: Mapping<Digest, Number>().setting(key: block2Parent, value: block2ParentNumber))
                let additions = Mapping<Digest, Mapping<Digest, Number>>().setting(key: blockHash3, value: Mapping<Digest, Number>().setting(key: blockParent4, value: blockParent4Number))
                let removals = Mapping<Digest, Mapping<Digest, Number>>().setting(key: blockHash3, value: Mapping<Digest, Number>().setting(key: block3Parent, value: block3ParentNumber))
                let additionsTrie = TrieMapping<SegmentID, [Digest]>().setting(keys: [segment2ID], value: [blockHash3])
                let removalsTrie = TrieMapping<SegmentID, [Digest]>().setting(keys: [segment2ID], value: [blockHash3])
                let blockNumbers = Mapping<Digest, Number>().setting(key: blockHash1, value: block1Number).setting(key: blockHash2, value: block2Number).setting(key: blockHash3, value: block3Number)
                let newSegment = segment1WithAParent.changeParentConfirmations(currentAdditions: currentAddition, currentRemovals: currentRemoval, additions: additions, removals: removals, additionsTrie: additionsTrie, removalsTrie: removalsTrie, blockNumbers: blockNumbers)
                expect(newSegment.blocks[block1Number]).toNot(beNil())
                expect(newSegment.blocks[block2Number]).toNot(beNil())
                expect(newSegment.blocks[block1Number]!.directParents).to(contain(block1Parent))
                expect(newSegment.blocks[block2Number]!.directParents).toNot(contain(block2Parent))
                expect(newSegment.childSegments.first()!).toNot(beNil())
                expect(newSegment.childSegments.first()!.1.blocks[block3Number]).toNot(beNil())
                expect(newSegment.childSegments.first()!.1.blocks[block3Number]!.directParents).toNot(contain(block3Parent))
                expect(newSegment.childSegments.first()!.1.blocks[block3Number]!.directParents).to(contain(blockParent4))
                expect(newSegment.earliestParent).to(equal(block1ParentNumber))
                let segment1WithWrongTip = segment1WithAParent.changing(tipNumber: Number(100))
                let parentsRemoved = segment1WithWrongTip.changeParentConfirmations(currentAdditions: Mapping<Digest, Mapping<Digest, Number>>(), currentRemovals: currentRemoval, additions: Mapping<Digest, Mapping<Digest, Number>>(), removals: removals, additionsTrie: TrieMapping<SegmentID, [Digest]>(), removalsTrie: removalsTrie, blockNumbers: blockNumbers)
                expect(parentsRemoved.earliestParent).to(equal(block2ParentNumber))
            }
        }
        describe("insert segment") {
            let blockHash1 = Digest.random()
            let block1 = BlockRepresentationType(blockHash: blockHash1, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block1Number = Number(1)
            let blockHash2 = Digest.random()
            let block2 = BlockRepresentationType(blockHash: blockHash2, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block2Number = Number(2)
            let blockHash3 = Digest.random()
            let block3 = BlockRepresentationType(blockHash: blockHash3, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block3Number = Number(3)
            let blockHash3Alt = Digest.random()
            let block3Alt = BlockRepresentationType(blockHash: blockHash3Alt, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block3NumberAlt = Number(3)
            let blockHash4 = Digest.random()
            let block4 = BlockRepresentationType(blockHash: blockHash4, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
            let block4Number = Number(4)
            let segement2Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block3Number, value: block3)
            let segment2 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block3Number, firstBlockNumber: block3Number, latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segement2Blocks, childSegments: Mapping<SegmentID, SegmentType>())
            let segement2BlocksAlt = Mapping<Number, BlockRepresentationType>().setting(key: block3NumberAlt, value: block3Alt)
            let segment2Alt = SegmentType(tipNumber: block3NumberAlt, earliestParent: nil, lastBlockNumber: block3NumberAlt, firstBlockNumber: block3NumberAlt, latestBlockDifficultyTarget: block3Alt.nextDifficulty, blocks: segement2BlocksAlt, childSegments: Mapping<SegmentID, SegmentType>())
            let segment2ID = SegmentID.random()
            let segment2IDAlt = SegmentID.random()
            let segment1Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block2Number, value: block2).setting(key: block1Number, value: block1)
            let segment1 = SegmentType(tipNumber: block3Number, earliestParent: nil, lastBlockNumber: block2Number, firstBlockNumber: block1Number, latestBlockDifficultyTarget: block3.nextDifficulty, blocks: segment1Blocks, childSegments: Mapping<SegmentID, SegmentType>().setting(key: segment2ID, value: segment2).setting(key: segment2IDAlt, value: segment2Alt))
            let segment1ID = SegmentID.random()
            it("should increase tip number if inserting dominanat segment at end") {
                let segement3Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block4Number, value: block4)
                let segment3 = SegmentType(tipNumber: block4Number, earliestParent: nil, lastBlockNumber: block4Number, firstBlockNumber: block4Number, latestBlockDifficultyTarget: block4.nextDifficulty, blocks: segement3Blocks, childSegments: Mapping<SegmentID, SegmentType>())
                let segment3ID = SegmentID.random()
                let newSegment = segment1.insert(currentSegmentID: segment1ID, path: ArraySlice([segment2ID]), segment: segment3, segmentID: segment3ID, previousBlockFingerprint: blockHash3)
                expect(newSegment.0.tipNumber).to(equal(block4Number))
                expect(newSegment.1.keys().contains(blockHash4)).to(beTrue())
                expect(newSegment.1[blockHash4]!).to(equal(segment2ID))
                expect(newSegment.0.childSegments[segment2ID]).toNot(beNil())
                expect(newSegment.0.childSegments[segment2ID]!.childSegments.keys()).to(beEmpty())
            }
            it("should add to child and increase tip number") {
                let block3NumberSegment3 = Number(3)
                let blockHash3InSegment3 = Digest.random()
                let block3InSegment3 = BlockRepresentationType(blockHash: blockHash3InSegment3, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
                let segement3Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block4Number, value: block4).setting(key: block3NumberSegment3, value: block3InSegment3)
                let segment3 = SegmentType(tipNumber: block4Number, earliestParent: nil, lastBlockNumber: block4Number, firstBlockNumber: block3NumberSegment3, latestBlockDifficultyTarget: block4.nextDifficulty, blocks: segement3Blocks, childSegments: Mapping<SegmentID, SegmentType>())
                let segment3ID = SegmentID.random()
                let newSegment = segment1.insert(currentSegmentID: segment1ID, path: ArraySlice([]), segment: segment3, segmentID: segment3ID, previousBlockFingerprint: blockHash2)
                expect(newSegment.0.tipNumber).to(equal(block4Number))
                expect(newSegment.1.keys().contains(blockHash3InSegment3)).to(beTrue())
                expect(newSegment.1[blockHash3InSegment3]!).to(equal(segment3ID))
                expect(newSegment.2.keys().contains(segment3ID)).to(beTrue())
                expect(newSegment.2[segment3ID]).to(equal(segment1ID))
                expect(newSegment.0.childSegments[segment3ID]).toNot(beNil())
                expect(newSegment.0.childSegments[segment3ID]!.childSegments.elements()).to(beEmpty())
            }
            it("should split up segment if added to middle of segment") {
                let block2AltNumber = Number(2)
                let blockHash2Alt = Digest.random()
                let block2Alt = BlockRepresentationType(blockHash: blockHash2Alt, nextDifficulty: Digest.random(), directParents: [], parentBlockNumbers: Mapping<Digest, Number>(), childBlockConfirmations: Mapping<ChainName, Digest>())
                let segement3Blocks = Mapping<Number, BlockRepresentationType>().setting(key: block2AltNumber, value: block2Alt)
                let segment3 = SegmentType(tipNumber: block2AltNumber, earliestParent: nil, lastBlockNumber: block2AltNumber, firstBlockNumber: block2AltNumber, latestBlockDifficultyTarget: block2Alt.nextDifficulty, blocks: segement3Blocks, childSegments: Mapping<SegmentID, SegmentType>())
                let segment3ID = SegmentID.random()
                let block2Parent = Digest.random()
                let blockNumberOfParent = Number(10)
                let segment3WithParent = segment3.addParent(blockNumber: block2AltNumber, parent: block2Parent, blockNumberOfParent: blockNumberOfParent)
                let newSegment = segment1.insert(currentSegmentID: segment1ID, path: ArraySlice([]), segment: segment3WithParent, segmentID: segment3ID, previousBlockFingerprint: blockHash1)
                expect(newSegment.0.tipNumber).to(equal(block2AltNumber))
                expect(newSegment.0.earliestParent).to(equal(blockNumberOfParent))
                expect(newSegment.1[blockHash2]).toNot(beNil())
                expect(newSegment.1[blockHash2Alt]).to(equal(segment3ID))
                expect(newSegment.2[segment3ID]).to(equal(segment1ID))
                expect(newSegment.2.elements().count).to(equal(2))
            }
        }
    }
}
