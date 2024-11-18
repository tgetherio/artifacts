// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@tgether/communities/tgetherCommunities.sol";
import "@tgether/communities/CommunitiesLane.sol";
import "@tgether/communities/tgetherMembers.sol";
import "@tgether/communities/MOCKFundContract.sol";
import "../src/tgetherCommunityConsensus.sol";
import {tgetherPosts} from "../src/tgetherPosts.sol";
import "../src/ArtifactConsensusLane.sol";
import "../src/tgetherArtifactConsensus.sol";
import "../src/tgetherConsensusBounty.sol";
import "../src/tgetherIncentives.sol";
import "@tgether/communities/LaneRegistry.sol";
import "../src/Artifacts.sol";
import "../src/SendLocalArtifact.sol";
import "../src/MockCCIP.sol";

contract ConsensusBountyTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    // Contracts
    tgetherCommunities public tgc;
    tgetherMembers public tgm;
    MOCKFundContract public tgf;
    tgetherCommunityConsensus public tgcc;
    tgetherPosts public tgp;
    tgetherArtifactConsensus public tgpc;
    tgetherIncentives public tgIncentives;
    tgetherConsensusBounty public tgb;
    Artifacts public artifacts;
    SendLocalArtifact public sla;

    // Two LaneRegistry instances for each lane
    LaneRegistry public laneRegistryForCommunity;
    LaneRegistry public laneRegistryForArtifact;
    CommunitiesLane public communityLane;
    ArtifactConsensusLane public artifactConsensusLane;

    // Define users
    address public owner;
    address public autoAddr;
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
        autoAddr = address(9);
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
        laneRegistryForArtifact = new LaneRegistry(address(tgpc));

        // Step 14: Deploy ArtifactConsensusLane and set its forwarder
        artifactConsensusLane = new ArtifactConsensusLane(address(tgf), address(tgpc), address(laneRegistryForArtifact));
        artifactConsensusLane.setForwarder(autoAddr);

        // Step 15: Configure necessary settings in Artifact Consensus
        tgpc.setLaneRegistry(address(laneRegistryForArtifact));

        // Step 16: Deploy Incentives contract
        tgIncentives = new tgetherIncentives(ccFeeAmount, address(tgc), feeAmount, address(tgf));

        // Step 17: Deploy Consensus Bounty contract
        tgb = new tgetherConsensusBounty(address(tgf), address(tgpc), address(tgcc), address(tgIncentives), ccFeeAmount);

        // Step 18: Set automation contract address in Consensus Bounty
        tgb.setAutomationContractAddress(autoAddr);
        vm.stopPrank();

        vm.startPrank(owner, owner);

        // Step 5: Create Communities
        tgc.createCommunity(communityName, 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);
        tgc.createCommunity("No Consensus Community", 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);
        tgc.createCommunity("NoCommunityFEE", 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);
        tgc.createCommunity("UnsetCommunity", 1, 1, 10, 1, address(0), proposalTime, proposalDelay, false);

        // Step 6: Add Members
        tgm.addSelfAsMember(communityName);
        tgm.addSelfAsMember("NoCommunityFEE");
        tgm.addSelfAsMember("UnsetCommunity");
        vm.stopPrank();

        vm.startPrank(addr1,addr1);
        tgm.addSelfAsMember(communityName);
        tgm.addSelfAsMember("NoCommunityFEE");
        tgm.addSelfAsMember("UnsetCommunity");
        vm.stopPrank();

        vm.prank(addr2,addr2);
        tgm.addSelfAsMember(communityName);
        vm.prank(addr3,addr3);
        tgm.addSelfAsMember(communityName);

        // Step 7: Add Positive Creds
        vm.startPrank(owner,owner);
        tgm.addPosCredsToMember(communityName, addr1);
        tgm.addPosCredsToMember(communityName, addr2);
        tgm.addPosCredsToMember(communityName, addr3);

        // Step 8: Set Consensus Parameters
        tgcc.setCCParams(communityName, numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        tgcc.setCCParams("No Consensus Community", numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, 0, consensusTypes);
        tgcc.setCCParams("NoCommunityFEE", numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        tgcc.setCCParams("UnsetCommunity", numReviewsForAcceptance, credsNeededForReview, percentAcceptsNeeded, consensusTime, consensusTypes);
        
        tgIncentives.setParams(communityName, tgetherIncentives.IncentiveStructure.Equal, 10, payable(addr1));
        tgIncentives.setParams("NoCommunityFEE", tgetherIncentives.IncentiveStructure.consensusAligned, 0, payable(addr1));

        vm.stopPrank();


        // Step 9: Mint Posts
        console.log("Minting Posts");
        for (uint256 i = 1; i <= 6; i++) {
            vm.prank(addr1,addr1);
            tgp.mintPost(string(abi.encodePacked("endpoint.com/post", i)), string(abi.encodePacked("Post ", i)), "Author", string(abi.encodePacked("Description of Post ", i)));
        }
        console.log("after Minting Posts");


        // Step 11: Submit Posts to Communities
        for (uint256 i = 1; i <= 6; i++) {
            vm.prank(addr1, addr1);
            vm.deal(addr1, feeAmount);
            tgpc.submitToCommunity{value: feeAmount}(i, communityName);
        }


        // Submitting reviews for submission 1
        vm.prank(addr3);
        tgpc.submitReview(1, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr1);
        tgpc.submitReview(1, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr2);
        tgpc.submitReview(1, "Endpoint for review.com/thissicool", 3);

        // Submitting reviews for submission 2
        tgpc.submitReview(2, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr1);
        tgpc.submitReview(2, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr3);
        tgpc.submitReview(2, "Endpoint for review.com/thissicool", 3);

        // Submitting reviews for submission 4
        tgpc.submitReview(4, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr1);
        tgpc.submitReview(4, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr3);
        tgpc.submitReview(4, "Endpoint for review.com/thissicool", 3);

        // Submitting reviews for submission 5
        tgpc.submitReview(5, "Endpoint for review.com/thissicool", 3);
        vm.prank(addr1);
        tgpc.submitReview(5, "Endpoint for review.com/thissicool", 3);
        vm.prank(addr3);
        tgpc.submitReview(5, "Endpoint for review.com/thissicool", 2);

        // Submitting reviews for submission 6
        tgpc.submitReview(6, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr1);
        tgpc.submitReview(6, "Endpoint for review.com/thissicool", 2);
        vm.prank(addr3);
        tgpc.submitReview(6, "Endpoint for review.com/thissicool", 3);

    }


    function testCreateBounties() public {
        uint256 submissionId = 1;

        vm.prank(addr1,addr1);
        vm.deal(addr1, feeAmount + ccFeeAmount);
        tgb.createBounty{value: feeAmount + ccFeeAmount}(submissionId);
        ( uint256 amount,address creator,) = tgb.bounties(1);


        assertEq(creator, addr1);
        assertEq(amount, feeAmount);

        vm.prank(addr2,addr2);
        vm.deal(addr2, feeAmount + ccFeeAmount);

        tgb.createBounty{value: feeAmount + ccFeeAmount}(submissionId);
        (amount, creator, ) = tgb.bounties(2);

        assertEq(creator, addr2);
        assertEq(amount, feeAmount );

        uint256[] memory bounties = tgb.GetArtifactSubmissionBounties(submissionId);
        assertEq(bounties.length, 2);
        assertEq(bounties[0], 1);
        assertEq(bounties[1], 2);
    }



    function testCheckLog() public {
        uint256 submissionId = 1;

        vm.prank(addr1,addr1);
        vm.deal(addr1, feeAmount + ccFeeAmount);
        tgb.createBounty{value: feeAmount + ccFeeAmount}(submissionId);

        Log memory log;
        log.source = address(tgc);
        log.topics = new bytes32[](4);
        log.topics[0] = bytes32(uint256(uint160(address(tgb))));
        log.topics[1] = bytes32(submissionId);

        (bool upkeepNeeded, bytes memory performData) = tgb.checkLog(log, "0x");

        assertTrue(upkeepNeeded, "Upkeep should be needed");
        (address[] memory addresses, uint256[] memory amounts, uint256 id) = abi.decode(performData, (address[], uint256[], uint256));
        assertEq(id, submissionId);
        assertEq(addresses.length, 1);
        assertEq(addresses[0], addr1);
        assertEq(amounts[0], feeAmount);
    }

    function testPerformUpkeep() public {
        uint256 submissionId = 1;
        // Simulate time passing

        // Create a bounty for the submission
        vm.prank(addr1,addr1);
        vm.deal(addr1, feeAmount + ccFeeAmount);
        uint256 val= feeAmount + ccFeeAmount ;
        tgb.createBounty{value: val }(submissionId);

        // Prepare the payees and payouts arrays
        address[] memory payees = new address[](3);
        uint256[] memory payouts= new uint256[](3);

        // Populate arrays with data
        payees[0] = addr1;
        payees[1] = addr2;
        payees[2] = addr3;
        // 10 percent of `feeAmount` is the fee for the contract
        uint256 bountyAMT = feeAmount - 10;

        payouts[0] = bountyAMT / 3;
        payouts[1] = bountyAMT / 3;
        payouts[2] = bountyAMT / 3;


        // Encode performData for performUpkeep
        bytes memory performData = abi.encode(payees, payouts, submissionId);

        // Capture initial balance of addr1

        vm.warp(block.timestamp + consensusTime);

        vm.prank(autoAddr, autoAddr);
        artifactConsensusLane.performUpkeep(abi.encode(uint256(submissionId)));

        // Call performUpkeep
        uint256 initialBalance = addr1.balance;

        tgb.performUpkeep(performData);

        // Capture final balance of addr1
        uint256 finalBalance = addr1.balance;

        // Assert that the payout was correctly distributed
        assertEq(finalBalance, initialBalance + bountyAMT/3 + 10  , "Payout should be credited to addr1");
    }

}
