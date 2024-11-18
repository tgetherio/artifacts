// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@tgether/communities/tgetherCommunities.sol";
import "@tgether/communities/tgetherMembers.sol";
import "@tgether/communities/MOCKFundContract.sol";
import "@tgether/communities/LaneRegistry.sol";
import "@tgether/communities/CommunitiesLane.sol";
import "../src/tgetherCommunityConsensus.sol";

contract CommunityConsensusTest is Test {
    tgetherCommunities public tgc;
    tgetherMembers public tgm;
    MOCKFundContract public tgf;
    LaneRegistry public laneRegistry;
    CommunitiesLane public lane1;
    tgetherCommunityConsensus public tgcc;

    address public owner;
    address public addr1;
    address public addr2;
    address public addr3;

    string constant communityName = "Cryptography";
    uint256 constant feeAmount = 1 ether;
    uint256 constant ccFeeAmount = 0.5 ether;
    uint256 constant proposalTime = 2630000;
    uint256 constant proposalDelay = 604800;
    uint256 constant numReviewsForAcceptance = 1;
    uint256 constant credsNeededForReview = 1;
    uint256 constant percentAcceptsNeeded = 50;
    uint256 constant consensusTime = 2630000;
    string[] consensusTypes = ["Hello", "World"];
    
    function setUp() public {
        owner = address(this);
        addr1 = address(1);
        addr2 = address(2);
        addr3 = address(3);

        tgm = new tgetherMembers();
        tgf = new MOCKFundContract();
        tgc = new tgetherCommunities(feeAmount);

        vm.startPrank(owner,owner);

        laneRegistry = new LaneRegistry(address(tgc));
        lane1 = new CommunitiesLane(address(tgf), address(tgc), address(laneRegistry));
        tgc.setLaneRegistryContract(address(laneRegistry));

        tgcc = new tgetherCommunityConsensus(ccFeeAmount, address(tgc), feeAmount, address(tgf));
        tgm.settgetherCommunities(address(tgc));
        tgc.settgetherMembersContract(address(tgm));

        tgc.createCommunity(communityName, 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);
        tgm.addSelfAsMember(communityName);
        vm.stopPrank();
    }


    function setUpMemebrship() public {        
        vm.startPrank(addr1, addr1);
        tgm.addSelfAsMember("Cryptography");
        vm.stopPrank();

        vm.startPrank(owner, owner);
        tgm.addPosCredsToMember("Cryptography", addr1);
        vm.stopPrank();
    }

    function testSetCCParams() public {
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        (uint256 reviews, uint256 creds, uint256 percent, uint256 time, string[] memory types, bool isSet) = tgcc.getCCParams(communityName);
        assertEq(reviews, numReviewsForAcceptance);
        assertEq(creds, credsNeededForReview);
        assertEq(percent, percentAcceptsNeeded);
        assertEq(time, consensusTime);
        assertEq(types.length, consensusTypes.length);
        assertTrue(isSet);
    }

    function testCreateCCProposal() public {
        
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        uint256 initialBalance = address(tgf).balance;
        setUpMemebrship();
        vm.deal(addr1, feeAmount + ccFeeAmount);
        vm.prank(addr1,addr1);
        tgcc.CreateCCProposal{value: feeAmount + ccFeeAmount}(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        
        assertEq(address(tgf).balance, initialBalance + feeAmount + ccFeeAmount);
    }

    function testCheckLog() public {
        // Initialize community consensus parameters
        vm.prank(owner,owner);
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);

        vm.deal(addr1, feeAmount + ccFeeAmount);

        setUpMemebrship();
        // Create a proposal
        vm.prank(addr1, addr1);
        tgcc.CreateCCProposal{value: feeAmount + ccFeeAmount}(
            communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes
        );

        // Set up a log entry for checkLog function
        uint256 fakeProposalId = 1;  // Assuming this is the proposal ID you want to test
        Log memory log;
        log.index = 1;
        log.timestamp = block.timestamp;
        log.txHash = bytes32(uint256(0x1234)); // Replace with actual txHash if available
        log.blockNumber = block.number;
        log.blockHash = bytes32(uint256(0x5678)); // Replace with actual blockHash if available
        log.source = address(tgcc);  // Set to the correct source contract

        // Set up topics array with contract addresses and proposal ID
        log.topics = new bytes32[](4);
        log.topics[0] = bytes32(0);  // Assuming this is placeholder
        log.topics[1] = bytes32(uint256(uint160(address(tgcc)))); // Correct contract address for `tgcc`
        log.topics[2] = bytes32(fakeProposalId); // Proposal ID as bytes32
        log.topics[3] = bytes32(0);  // Assuming this is placeholder

        log.data = bytes("0x");  // Empty data field, modify if actual data needed

        // Perform checkLog to verify log entry is interpreted as expected
        (bool upkeepNeeded, bytes memory performData) = tgcc.checkLog(log, "");

        // Assertions based on the expected output
        assertTrue(upkeepNeeded, "Upkeep should be needed for the given log entry");
        assertEq(performData, abi.encode(fakeProposalId), "performData should contain the correct proposal ID");
    }


    function testPerformUpkeepPassedProposal() public {
        vm.deal(addr1, feeAmount + ccFeeAmount);
        setUpMemebrship();
        // Create a proposal
        vm.prank(owner, owner);
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        vm.prank(addr1,addr1);
        tgcc.CreateCCProposal{value: feeAmount + ccFeeAmount}(communityName, 2, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
       
        vm.warp(block.timestamp + proposalDelay);

        vm.prank(addr1,addr1);
        tgc.vote(1, true);
        vm.warp(block.timestamp + proposalTime);
        vm.prank(owner,owner);
        lane1.performUpkeep(abi.encode(uint256(1)));
        tgcc.performUpkeep(abi.encode(uint256(1)));

        (uint256 reviews, , , , ,) = tgcc.getCCParams(communityName);
        assertEq(reviews, 2);
    }

    function testPerformUpkeepFailedProposal() public {

        tgcc.setCCParams(communityName, numReviewsForAcceptance , credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        vm.deal(addr1, feeAmount + ccFeeAmount);
        setUpMemebrship();
        vm.prank(addr1,addr1);
        tgcc.CreateCCProposal{value: feeAmount + ccFeeAmount}(communityName, 0, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        vm.warp(block.timestamp + proposalDelay);

        vm.prank(addr1,addr1);
        tgc.vote(1, false);
        vm.warp(block.timestamp + proposalTime);

        vm.prank(owner,owner);
        lane1.performUpkeep(abi.encode(uint256(1)));
        tgcc.performUpkeep(abi.encode(uint256(1)));

        (uint256 reviews, , , , , ) = tgcc.getCCParams(communityName);
        assertEq(reviews, 1);
    }
}
