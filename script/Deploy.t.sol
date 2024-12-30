// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SendLocalArtifact.sol";
import {Artifacts} from "../src/Artifacts.sol";
import "../src/tgetherPosts.sol";
import "../src/tgetherArtifactConsensus.sol";
import "@tgether/communities/LaneRegistry.sol";
import "../src/ArtifactConsensusLane.sol";
import "../src/tgetherIncentives.sol";
import "../src/tgetherConsensusBounty.sol";

contract DeployContracts is Script {
    function run() external {
        // Load variables (customize these as needed)
        address sourceRouter = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
        uint256 chain = 421614;
        address tgcc = 0x540a219225CD93a5A0A9BB710D3f33e88BC0FEd3;
        address tgm = 0xad9b4Ba52Cc728ac9D4E0b899016d29d731730F1;
        address tgf = 0x775a6E264F2424853746F9cB0d356B79b948097c;
        uint256 feeAmount = 0;
        uint256 ccFeeAmount = 0;
        vm.startBroadcast();

        // Step 1: Deploy SendLocalArtifact contract
        SendLocalArtifact sla = new SendLocalArtifact();
        console.log("SendLocalArtifact contract address: ", address(sla));

        // Step 2: Deploy Artifacts contract
        Artifacts artifacts = new Artifacts(sourceRouter, chain, address(sla));
        sla.setArtifactContract(address(artifacts));
        console.log("Artifacts contract address: ", address(artifacts));

        // Step 3: Deploy tgetherPosts contract
        tgetherPosts tgp = new tgetherPosts(address(sla));
        console.log("tgetherPosts contract address: ", address(tgp));

        // Step 4: Deploy tgetherArtifactConsensus contract
        tgetherArtifactConsensus tgpc = new tgetherArtifactConsensus(tgcc, tgm, address(artifacts), feeAmount);
        console.log("tgetherArtifactConsensus contract address: ", address(tgpc));
        // Step 5: Deploy LaneRegistry contract for ArtifactConsensusLane
        LaneRegistry laneRegistryForArtifact = new LaneRegistry(address(tgpc));
        console.log("LaneRegistry contract address: ", address(laneRegistryForArtifact));
        // Step 6: Deploy ArtifactConsensusLane contract
        ArtifactConsensusLane artifactConsensusLane = new ArtifactConsensusLane(tgf, address(tgpc), address(laneRegistryForArtifact));
        // artifactConsensusLane.setForwarder(autoAddr);
        console.log("ArtifactConsensusLane contract address: ", address(artifactConsensusLane));
        // Step 7: Configure settings in ArtifactConsensus
        tgpc.setLaneRegistry(address(laneRegistryForArtifact));

        // Step 8: Deploy tgetherIncentives contract
        tgetherIncentives tgIncentives = new tgetherIncentives(ccFeeAmount, tgcc, feeAmount, tgf);
        console.log("tgetherIncentives contract address: ", address(tgIncentives));
        // Step 9: Deploy tgetherConsensusBounty contract
        tgetherConsensusBounty tgb = new tgetherConsensusBounty(tgf, address(tgpc), tgcc, address(tgIncentives), ccFeeAmount);
        console.log("tgetherConsensusBounty contract address: ", address(tgb));
        // Step 10: Set automation contract address in ConsensusBounty
        // tgb.setAutomationContractAddress(autoAddr);

        vm.stopBroadcast();
    }
}
