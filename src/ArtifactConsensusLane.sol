// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";


// Interface for FundContract
interface FundContractInterface {
    function fundUpkeep(address _contractAddress) external payable returns (bool);
}

// Interface for CommunitiesContract (to fetch artifact data)
interface ArtifactConsensusInterface is AutomationCompatibleInterface {
    function getSubmissionExpiration(uint256 _submissionId) external view returns(uint256);
    function getCheckSubmissionForUpkeep(uint256 submissionId) external view returns (bool upkeepNeeded, int256 resultId);
    function performUpkeep(bytes calldata performData) external;
}

// Interface for the LaneRegistry to update lane size
interface LRInterface {
    function reportLaneLength(uint256 laneId, uint256 newLength) external;
    function addLane(address _contractAddress) external  returns (uint256);
}

// CommunitiesLane Contract
contract ArtifactConsensusLane  is AutomationCompatibleInterface {

    uint256[] public artifacts;  // Array to store artifact IDs
    mapping(uint256 => uint256) public artifactIndex;  // Mapping from artifactId to index in artifacts array
    address public owner;
    address public registry;
    address public artifactConsensus;
    address public laneRegistryContract;
    address public automationForwarder;

    uint256 public laneId;

    FundContractInterface public fundContract;

    uint256 constant NOT_IN_MAPPING = type(uint256).max;  // Sentinel value for non-existent artifacts

    event IndexChange(uint256 artifactId, uint256 newIndex);  // Event to emit when an index changes
    event ArtifactRemoved(uint256 artifactId);  // Event emitted when a artifact is removed

    constructor(address _fundContractAddress, address _artifactConsensus, address _laneRegistryContract) {
        owner = msg.sender;
        artifactConsensus = _artifactConsensus;
        laneRegistryContract = _laneRegistryContract;
        fundContract = FundContractInterface(_fundContractAddress);
        laneId = LRInterface(laneRegistryContract).addLane(address(this));
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier onlyRegistry() {
        require(msg.sender == laneRegistryContract, "Not the registry");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || msg.sender == artifactConsensus, "Not authorized");
        _;
    }

    modifier onlyAutomationForwarder(){
        require(msg.sender == automationForwarder, "Not the automation forwarder");
        _;
    }



    // Append artifact ID to the lane (only callable by the registry)
    function appendToLane(uint256 artifactId) external payable onlyRegistry returns (uint256) {
        // Call the FundContract to handle the upkeep payment

        bool _isFunded = fundContract.fundUpkeep{value: msg.value}(address(this));
        require(_isFunded, "Upkeep payment failed");

        // Append the new artifact ID to the array and update the index mapping
        artifacts.push(artifactId);
        artifactIndex[artifactId] = artifacts.length - 1;  // Store the index of the new artifact

        // Return the new length of the lane
        return artifacts.length;
    }

    // Automated checkUpkeep function
    /*
     * @notice Checks if there are any submissions that need upkeep based on their review periods.
     * @param checkData Additional data passed to the function (not used in this implementation).
     * @return upkeepNeeded A boolean indicating if upkeep is needed.
     * @return performData Encoded data indicating the submission ID to be processed during performUpkeep.
     */

    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = false;
        uint256 lowestId = 0;

        if (artifacts.length > 0) {
            uint256 lowestTimestamp = 0;


            // Find the lowest expired submission
            for (uint256 i = 0; i < artifacts.length; i++) {
                uint256 submissionId = artifacts[i];
                uint256 reviewPeriodExpired = ArtifactConsensusInterface(artifactConsensus).getSubmissionExpiration(submissionId);

                // Ensure review period is expired and is the lowest in the list
                if (reviewPeriodExpired <= block.timestamp && (reviewPeriodExpired <= lowestTimestamp || lowestTimestamp == 0)) {
                    upkeepNeeded = true;
                    lowestId = submissionId;
                    lowestTimestamp = reviewPeriodExpired;
                }
            }

            int256 resultId;

            if (lowestId != 0) {
                (upkeepNeeded,resultId) = ArtifactConsensusInterface(artifactConsensus).getCheckSubmissionForUpkeep(lowestId);
                performData = abi.encode(resultId);
            }
        }
    }
    

    // Perform the upkeep (calls the Communities contract and then updates the lane size)
    function performUpkeep(bytes calldata _performData) external onlyAutomationForwarder{
        int256 resultId = abi.decode(_performData, (int256));
        uint256 artifactId;
        if (resultId < 0) {
            artifactId = uint256(-resultId);
        }else
        {
            artifactId = uint256(resultId);
        }

        // Call the Communities contract to perform the upkeep
        ArtifactConsensusInterface(artifactConsensus).performUpkeep(_performData);

        // After upkeep, remove the artifact
        _removeArtifact(artifactId);

        // Report the new lane length back to the registry
        LRInterface(laneRegistryContract).reportLaneLength( laneId, artifacts.length);
    }

    // Internal function for removing a artifact
    function _removeArtifact(uint256 artifactId) internal {
        uint256 indexToRemove = artifactIndex[artifactId];
        require(indexToRemove != NOT_IN_MAPPING || artifacts[0] == artifactId, "Artifact does not exist");

        uint256 lastartifactIndex = artifacts.length - 1;
        uint256 lastArtifactId = artifacts[lastartifactIndex];

        if (indexToRemove != lastartifactIndex) {
            // Swap the artifact to remove with the last one
            artifacts[indexToRemove] = lastArtifactId;
            
            // Update the index in the mapping for the swapped artifact
            artifactIndex[lastArtifactId] = indexToRemove;

            // Emit event about index change
            emit IndexChange(lastArtifactId, indexToRemove);
        }

        // Remove the last element from the array
        artifacts.pop();
        artifactIndex[artifactId] = NOT_IN_MAPPING;  // Set the index to the sentinel value

        // Emit artifact removal event
        emit ArtifactRemoved(artifactId);
    }

    // External call for the owner or communities contract to remove a artifact
    function removeArtifact(uint256 artifactId) external onlyAuthorized {
        _removeArtifact(artifactId);
        
    }

    // Getter to retrieve the artifact count
    function getArtifactCount() external view returns (uint256) {
        return artifacts.length;
    }

    // Getter to retrieve a specific artifact ID by index
    function getArtifactByIndex(uint256 index) external view returns (uint256) {
        require(index < artifacts.length, "Invalid index");
        return artifacts[index];
    }

    // Getter to retrieve the index of a artifact by ID
    function getartifactIndex(uint256 artifactId) external view returns (uint256) {
        uint256 index = artifactIndex[artifactId];
        require(index != NOT_IN_MAPPING || artifacts[0] == artifactId, "Artifact does not exist");
        return index;
    }


    function setRegistry(address _registry) external ownerOnly {
        laneRegistryContract = _registry;
    }

    function setFundContract(address _fundContractAddress) external ownerOnly {
        fundContract = FundContractInterface(_fundContractAddress);
    }
    function setForwarder(address _forwarder) external ownerOnly {
        automationForwarder = _forwarder;
    }

}
