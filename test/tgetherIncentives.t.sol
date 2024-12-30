// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@tgether/communities/tgetherCommunities.sol";
import "@tgether/communities/tgetherMembers.sol";
import "@tgether/communities/MOCKFundContract.sol";
import "@tgether/communities/LaneRegistry.sol";
import "@tgether/communities/CommunitiesLane.sol";
import "../src/tgetherCommunityConsensus.sol";
import {tgetherPosts} from "../src/tgetherPosts.sol";
import "../src/ArtifactConsensusLane.sol";
import "../src/tgetherArtifactConsensus.sol";
import "../src/tgetherIncentives.sol";
import "../src/Artifacts.sol";
import {SendLocalArtifact} from "../src/SendLocalArtifact.sol";
import "../src/MockCCIP.sol";


contract tgetherIncentivesTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    // Assume setup variables and contracts from previous examples are available here

    // Declare contracts
    tgetherCommunities public tgc;
    tgetherMembers public tgm;
    MOCKFundContract public tgf;
    tgetherCommunityConsensus public tgcc;
    tgetherPosts public tgp;
    tgetherArtifactConsensus public tgpc;
    tgetherIncentives public tgIncentives;
    Artifacts public artifacts;
    SendLocalArtifact public sla;

    // Two LaneRegistry instances for each lane
    LaneRegistry public laneRegistryForCommunity;
    LaneRegistry public laneRegistryForPost;
    CommunitiesLane public communityLane;
    ArtifactConsensusLane public artifactConsensusLane;

    // Define users
    address public owner;
    address public autoaddr;
    address public addr1;
    address public addr2;
    address public addr3;

    // Define constants
    string constant communityName = "Cryptography";
    uint256 constant feeAmount = 1 ether;
    uint256 constant ccFeeAmount = 0.5 ether;
    uint256 constant proposalTime = 2630000;
    uint256 constant proposalDelay = 604800;
    uint256 constant numReviewsForAcceptance = 1;
    uint256 constant credsNeededForReview = 0;
    uint256 constant percentAcceptsNeeded = 50;
    uint256 constant consensusTime = 2630000;
    string[] consensusTypes = ["Hello", "World"];

 function setUp() public {
        // Assign addresses
        owner = address(this);
        autoaddr = address(9);
        addr1 = address(1);
        addr2 = address(2);
        addr3 = address(3);

        vm.startPrank(owner, owner);

        // Step 1: Deploy mock fund contract
        tgf = new MOCKFundContract();

        // Step 2: Deploy Members contract
        tgm = new tgetherMembers();

        // Step 3: Deploy Communities contract
        tgc = new tgetherCommunities(feeAmount);

        // Step 4: Deploy the first LaneRegistry for CommunitiesLane
        laneRegistryForCommunity = new LaneRegistry(address(tgc));

        // Step 5: Deploy CommunitiesLane and set its LaneRegistry
        communityLane = new CommunitiesLane(address(tgf), address(tgc), address(laneRegistryForCommunity));
        tgc.setLaneRegistryContract(address(laneRegistryForCommunity));

        // Step 6: Deploy Community Consensus contract and configure
        tgcc = new tgetherCommunityConsensus(ccFeeAmount, address(tgc), feeAmount, address(tgf));
        tgm.settgetherCommunities(address(tgc));
        tgc.settgetherMembersContract(address(tgm));

        // Step 7: Create community in the Communities contract
        tgc.createCommunity(communityName, 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);
    
        // Step 8: Add members to the community
        tgm.addSelfAsMember(communityName);

        vm.stopPrank();
        vm.prank(addr1,addr1);
        tgm.addSelfAsMember(communityName);
        vm.prank(addr2);
        tgm.addSelfAsMember(communityName);
        vm.prank(addr3);
        tgm.addSelfAsMember(communityName);

        // Step 9: Add positive creds to members
        vm.startPrank(owner,owner);
        tgm.addPosCredsToMember(communityName, addr1);
        tgm.addPosCredsToMember(communityName, addr2);
        tgm.addPosCredsToMember(communityName, addr3);

        // Step 10: Set consensus parameters for the community
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            ,
            ,
            ,
            ,
        ) = ccipLocalSimulator.configuration();

        sla = new SendLocalArtifact();
        artifacts = new Artifacts(address(sourceRouter),  chainSelector, address(sla) );
        sla.setArtifactContract(address(artifacts));



        // Step 11: Deploy the Post contract
        tgp = new tgetherPosts(address(sla));



        // Step 12: Deploy Post Consensus contract with tgetherPosts and other addresses
        tgpc = new tgetherArtifactConsensus(address(tgcc), address(tgm), address(tgp), feeAmount);

        // Step 13: Deploy the LaneRegistry contract for ArtifactConsensusLane
        laneRegistryForPost = new LaneRegistry(address(tgpc));

        // Step 14: Deploy ArtifactConsensusLane and set its forwarder
        artifactConsensusLane = new ArtifactConsensusLane(address(tgf), address(tgpc), address(laneRegistryForPost));
        artifactConsensusLane.setForwarder(autoaddr);

        // Step 15: Configure necessary settings in Post Consensus
        tgpc.setLaneRegistry(address(laneRegistryForPost));
    
        vm.stopPrank();

        vm.prank(addr1,addr1);
        tgp.mintPost("content", "title", "authorName", "description");  
        vm.deal(addr1, feeAmount);
        tgIncentives = new tgetherIncentives(ccFeeAmount, address(tgc), feeAmount, address(tgf));




    }

    // ========== Initial Incentive Setup Tests ==========

    function testSetInitialIncentiveParameters() public {
        vm.prank(owner, owner);
        tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

        (,, address contractReceiveAddress,bool isSet) = tgIncentives.IncentiveStructures(communityName);
        assertTrue(isSet);
        assertEq(contractReceiveAddress, owner);
    }


    // ========== Create Incentive Proposal Tests ==========

    function testCreateIncentiveProposal() public {
        vm.prank(owner, owner);
        tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

        // Submit proposal
        vm.deal(addr1, feeAmount + ccFeeAmount);
        vm.prank(addr1,addr1);
        tgIncentives.createProposal{value: feeAmount + ccFeeAmount}(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

        // Verify the proposal details
        tgetherIncentives.IncentiveProposal memory proposal = tgIncentives.getProposal(1);
        assertEq(proposal.proposer, addr1);
    }

    // ========== Check Log Function Tests ==========

function testCheckLog() public {
    // Initialize incentive parameters
    vm.prank(owner, owner);
    tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

    vm.deal(addr1, feeAmount + ccFeeAmount);

    // Create a proposal
    vm.prank(addr1,addr1);
    tgIncentives.createProposal{value: feeAmount + ccFeeAmount}(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

    // Set up a log entry for checkLog function
    uint256 fakeProposalId = 1;  // Proposal ID for the test
    Log memory log;
    log.index = 1;
    log.timestamp = block.timestamp;
    log.txHash = bytes32(uint256(0x1234)); // Replace with actual txHash if available
    log.blockNumber = block.number;
    log.blockHash = bytes32(uint256(0x5678)); // Replace with actual blockHash if available
    log.source = address(tgIncentives);  // Use the correct source contract

    // Set up topics array with contract addresses and proposal ID
    log.topics = new bytes32[](4);
    log.topics[0] = bytes32(0);  // Placeholder
    log.topics[1] = bytes32(uint256(uint160(address(tgIncentives)))); // Contract address
    log.topics[2] = bytes32(fakeProposalId); // Proposal ID as bytes32
    log.topics[3] = bytes32(0);  // Placeholder

    log.data = bytes("0x");  // Empty data field

    // Perform checkLog to verify log entry is interpreted as expected
    (bool upkeepNeeded, bytes memory performData) = tgIncentives.checkLog(log, "");

    // Assertions based on the expected output
    assertTrue(upkeepNeeded, "Upkeep should be needed for the given log entry");
    assertEq(performData, abi.encode(fakeProposalId), "performData should contain the correct proposal ID");
}


    // ========== Perform Upkeep Tests ==========

function testPerformUpkeepPassedProposal() public {
    // Fund `addr1` with enough balance
    vm.deal(addr1, feeAmount + ccFeeAmount);

    // Set initial incentive parameters
    vm.prank(owner, owner);
    tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

    // Create an incentive proposal
    vm.prank(addr1,addr1);
    tgIncentives.createProposal{value: feeAmount + ccFeeAmount}(communityName, tgetherIncentives.IncentiveStructure.Equal, 6, payable(owner));

    // Simulate the passage of time for proposal delay
    vm.warp(block.timestamp + proposalDelay);

    // Approve the proposal
    vm.prank(addr1,addr1);
    tgc.vote(1, true);

    // Simulate more time passing to allow upkeep
    vm.warp(block.timestamp + proposalTime);

    // Perform upkeep via lane and incentives contract
    vm.prank(owner, owner);
    communityLane.performUpkeep(abi.encode(uint256(1)));

    vm.prank(owner, owner);
    tgIncentives.performUpkeep(abi.encode(uint256(1)));

    // Verify that the incentive parameters were updated
    (,uint256 communityFee,,) = tgIncentives.IncentiveStructures(communityName);
    assertEq(communityFee, 6);
}

function testPerformUpkeepFailedProposal() public {
    // Fund `addr1` with enough balance
    vm.deal(addr1, feeAmount + ccFeeAmount);

    // Set initial incentive parameters
    vm.prank(owner, owner);
    tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 5, payable(owner));

    // Create an incentive proposal
    vm.prank(addr1,addr1);
    tgIncentives.createProposal{value: feeAmount + ccFeeAmount}(communityName, tgetherIncentives.IncentiveStructure.Equal, 6, payable(owner));

    // Simulate the passage of time for proposal delay
    vm.warp(block.timestamp + proposalDelay);

    // Reject the proposal
    vm.prank(addr1,addr1);
    tgc.vote(1, false);

    // Simulate more time passing to allow upkeep
    vm.warp(block.timestamp + proposalTime);

    // Perform upkeep via lane and incentives contract
    vm.prank(owner, owner);
    communityLane.performUpkeep(abi.encode(uint256(1)));

    vm.prank(owner, owner);
    tgIncentives.performUpkeep(abi.encode(uint256(1)));

    // Verify that the incentive parameters were not updated
    (,uint256 communityFee,,) = tgIncentives.IncentiveStructures(communityName);
    assertEq(communityFee, 5);
}

}
