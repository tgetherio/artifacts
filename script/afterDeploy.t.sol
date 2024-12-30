// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";


interface ArtifactConsensusLaneInterface {
    function setForwarder(address _forwarder) external;

}

interface BountyInterface {
    function setAutomationContractAddress(address _AutomationContractAddress) external;
}

interface FUNDInterface {
    function setUpkeeps(address _address, uint256 _upkeep) external;
}   
contract DeployContracts is Script {
    function run() external {
        // Load variables (customize these as needed)

        vm.startBroadcast();

        // ArtifactConsensusLaneInterface(0x4C1D15500afb7820dA33e8d34dEeDdB89690C46b).setForwarder(0x7cCD1ee7FEf1DCdf864f680291f0f3c9bDDd0C7a);

        // BountyInterface(0x993651330444828f774e06096e97ed86E019065f).setAutomationContractAddress(0x092eAB59C131a1Be8D20455f5d687b3b6E61CaBa);

        FUNDInterface(0x775a6E264F2424853746F9cB0d356B79b948097c).setUpkeeps(0x4C1D15500afb7820dA33e8d34dEeDdB89690C46b,27924969115238790120707268241278549811305918814232845604303478267823613154066 );

        FUNDInterface(0x775a6E264F2424853746F9cB0d356B79b948097c).setUpkeeps(0x6E0861A2135E80FeD88541Bc92650721B70FC5A9,89221996528466580782696434962662928418117840074302985856535011947834003188820 );
        FUNDInterface(0x775a6E264F2424853746F9cB0d356B79b948097c).setUpkeeps(0x993651330444828f774e06096e97ed86E019065f,77358580230657187274317987401603429835597238006847160980888291420545546288209 );


        vm.stopBroadcast();
    }
}

