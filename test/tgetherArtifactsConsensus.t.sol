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
import "../src/Artifacts.sol";
import "../src/SendLocalArtifact.sol";
import "../src/MockCCIP.sol";

contract ArtifactConsensusTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    // Declare contracts
    tgetherCommunities public tgc;
    tgetherMembers public tgm;
    MOCKFundContract public tgf;
    tgetherCommunityConsensus public tgcc;
    tgetherPosts public tgp;
    tgetherArtifactConsensus public tgpc;
    Artifacts public artifacts;
    SendLocalArtifact public sla;

    // Two LaneRegistry instances for each lane
    LaneRegistry public laneRegistryForCommunity;
    LaneRegistry public laneRegistryForPost;
    CommunitiesLane public communityLane;
    ArtifactConsensusLane public artifactConsensusLane;
    Artifacts public tga;
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
        vm.prank(addr1);
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

        //Step 7 deploy the Artifact contract
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
        tgpc = new tgetherArtifactConsensus(address(tgcc), address(tgm), address(artifacts), feeAmount);

        // Step 13: Deploy the LaneRegistry contract for ArtifactConsensusLane
        laneRegistryForPost = new LaneRegistry(address(tgpc));

        // Step 14: Deploy ArtifactConsensusLane and set its forwarder
        artifactConsensusLane = new ArtifactConsensusLane(address(tgf), address(tgpc), address(laneRegistryForPost));
        artifactConsensusLane.setForwarder(autoaddr);

        // Step 15: Configure necessary settings in Post Consensus
        tgpc.setLaneRegistry(address(laneRegistryForPost));
    
        vm.stopPrank();

        vm.prank(addr1);
        tgp.mintPost("content", "title", "authorName", "description");  
        vm.deal(addr1, feeAmount);



    }

    function testCommunitySubmission() public {
        // Set up initial balances and member credentials
        
        // Test community submission and verify
        vm.prank(addr1,addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        // Retrieve and assert submission details
        (tgetherArtifactConsensus.CommunitySubmission memory cs) = tgpc.getCommunitySubmission(1);
        assertEq(cs.communityName, communityName);
        assertEq(uint(cs.consensus), uint(tgetherArtifactConsensus.Consensus.Pending));  // Compare as integers
    }

        // ========== Reviews Tests ==========
    
    function testReviewPostAccept() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        tgetherArtifactConsensus.Review memory review = tgpc.getReview(1);
        assertEq(review.consensusType, "Accepted");
    }

    function testReviewPostRejectCustom() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 4);

        tgetherArtifactConsensus.Review memory review = tgpc.getReview(1);
        assertEq(review.consensusType, "Hello");
    }

    function testReviewFailAboveBounds() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        vm.expectRevert("Consensous Not In Bounds");
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 10);
    }

    function testReviewFailDuplicate() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);
        
        vm.expectRevert("You've already reviewed this artifact");
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);
    }

    // ========== CheckUpkeep Tests ==========

    function testCheckUpkeepNotNeeded() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        (bool upkeepNeeded,) = artifactConsensusLane.checkUpkeep('0x');
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepNeededAndAccept() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        (bool upkeepNeeded, bytes memory resultId) = artifactConsensusLane.checkUpkeep('0x');
        assertTrue(upkeepNeeded);
        assertEq(resultId, abi.encode(1));
    }

    function testCheckUpkeepNeededAndReject() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(addr1);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);
        vm.prank(addr2);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        (bool upkeepNeeded, bytes memory resultId) = artifactConsensusLane.checkUpkeep('0x');
        assertTrue(upkeepNeeded);
        assertEq(resultId, abi.encode(int256(-1)));
    }

    // ========== performUpkeep Tests ==========

    function testPerformUpkeepNotNeeded() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        // Attempt upkeep too early
        vm.expectRevert("Upkeep not needed for this submission");
        vm.prank(autoaddr);
        artifactConsensusLane.performUpkeep(abi.encode(uint256(1)));
    }

    function testPerformUpkeepAcceptSubmission() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        vm.prank(autoaddr, autoaddr);
        artifactConsensusLane.performUpkeep(abi.encode(uint256(1)));

        tgetherArtifactConsensus.CommunitySubmission memory submission = tgpc.getCommunitySubmission(1);
        assertEq(uint(submission.consensus), uint(tgetherArtifactConsensus.Consensus.Accepted));
    }

    function testPerformUpkeepRejectSubmission() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(addr1);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);
        vm.prank(addr2);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        vm.prank(autoaddr);
        artifactConsensusLane.performUpkeep(abi.encode(int256(-1)));

        tgetherArtifactConsensus.CommunitySubmission memory submission = tgpc.getCommunitySubmission(1);
        assertEq(uint(submission.consensus), uint(tgetherArtifactConsensus.Consensus.Rejected));
    }

    // ========== Manual Upkeep Tests ==========

    function testManualUpkeepNotReady() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);
        
        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        vm.expectRevert("Upkeep not needed for this submission");
        vm.prank(owner);
        tgpc.manualUpkeepArtifact(1);
    }

    function testManualUpkeepInvalidSubmissionID() public {
        vm.expectRevert("Invalid submission ID");
        vm.prank(owner);
        tgpc.manualUpkeepArtifact(0);
    }

    function testManualUpkeepAcceptSubmission() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(owner);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 2);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        vm.prank(owner);
        tgpc.manualUpkeepArtifact(1);

        tgetherArtifactConsensus.CommunitySubmission memory submission = tgpc.getCommunitySubmission(1);
        assertEq(uint(submission.consensus), uint(tgetherArtifactConsensus.Consensus.Accepted));
    }

    function testManualUpkeepRejectSubmission() public {
        vm.prank(addr1);
        tgpc.submitToCommunity{value: feeAmount}(1, communityName);

        vm.prank(addr1);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);
        vm.prank(addr2);
        tgpc.submitReview(1, "Endpoint for review.com/thisiscool", 3);

        // Simulate time passing
        vm.warp(block.timestamp + consensusTime);

        vm.prank(owner);
        tgpc.manualUpkeepArtifact(1);

        tgetherArtifactConsensus.CommunitySubmission memory submission = tgpc.getCommunitySubmission(1);
        assertEq(uint(submission.consensus), uint(tgetherArtifactConsensus.Consensus.Rejected));
    }

    function testManualUpkeepIncorrectResultEncoding() public {
        vm.warp(block.timestamp + consensusTime);

        vm.expectRevert("Submission does not exist or is not active");
        vm.prank(owner);
        tgpc.manualUpkeepArtifact(999);
    }
}
