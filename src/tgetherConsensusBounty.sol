// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
interface tgetherArtifactConsensusInterface {
    function getReviewsForSubmission(uint256 _submissionId) external view returns (uint256[] memory);
    function getArtifactConsesous(uint256 _submissionId) external view returns (Consensus);
    function getReview(uint256 _reviewId) external view returns (Review memory);
    function getArtifactSubmissionCommunity(uint256 _artifactId) external view returns (string memory);
    
    struct Review {
        address member;
        string content;
        uint256 consensus;
        string consensusType;
        uint256 creds;
        bool afterConsensus;
    }
    
    enum Consensus { NotProcessed, Pending, Accepted, Rejected }
}

interface CommunityConsensusInterface {
    function getCommunityReviewParams(string memory _communityName) external view returns (uint256 numReviewsForAcceptance, uint256 credsNeededForReview, uint256 percentAcceptsNeeded);
}

interface tgetherIncentivesInterface {
    enum IncentiveStructure { Equal, consensusAligned }

    function getInctiveStructure(string memory _communityName) external view returns (IncentiveStructure);
    function getCommunityFeeInfo(string memory _communityName) external view returns (uint256 _communityFee, address _contractRecieveAddress);
    
    // Function to check if incentive parameters are set
    function getIncentiveParamsExist(string memory _communityName) external view returns (bool _isSet);
}


interface tgFundInterface {
    function fundUpkeep(address _contractAddress) external payable returns (bool);
}

contract tgetherConsensusBounty is ReentrancyGuard, ILogAutomation {
    // Variables
    struct Bounty {
        uint256 bountyAmount;
        address bountyCreator;
        bool bountyPaid;
    }

    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => uint256[]) public artifactSubmissionBounties;
    uint256 public bountiesId;

    tgFundInterface public tgetherFundContract;
    tgetherArtifactConsensusInterface public tgetherArtifactConsensusContract;
    CommunityConsensusInterface public tgetherCommunityConsensusContract;
    tgetherIncentivesInterface public tgetherIncentivesContract;
    address public AutomationContractAddress;

    uint256 public fee;
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier ownerOrAutomation() {
        require(msg.sender == owner || msg.sender == AutomationContractAddress, "Not the contract owner or Automation Forwarder Contract");
        _;
    }

    // Events
    event BountyCreated(uint256 bountyId, uint256 submissionId, address creator, uint256 amount);
    event BountyPaid(address recipient, uint256 amount);

    // Constructor
    constructor(
        address _tgetherFundAddress, 
        address _tgetherArtifactConsensusAddress, 
        address _tgetherCommunityConsensusAddress, 
        address _tgetherIncentivesAddress, 
        uint256 _fee
    ) {
        tgetherFundContract = tgFundInterface(_tgetherFundAddress);
        tgetherArtifactConsensusContract = tgetherArtifactConsensusInterface(_tgetherArtifactConsensusAddress);
        tgetherCommunityConsensusContract = CommunityConsensusInterface(_tgetherCommunityConsensusAddress);
        tgetherIncentivesContract = tgetherIncentivesInterface(_tgetherIncentivesAddress);
        fee = _fee;
        owner = msg.sender;
        bountiesId = 1;
    }

    // Functions
    function createBounty(uint256 _submissionId) external payable returns (uint256) {
        require(tgetherArtifactConsensusContract.getArtifactConsesous(_submissionId) == tgetherArtifactConsensusInterface.Consensus.Pending, "Artifact must be pending consensus");

        (uint256 comFee,) = tgetherIncentivesContract.getCommunityFeeInfo(tgetherArtifactConsensusContract.getArtifactSubmissionCommunity(_submissionId));

        require(msg.value > fee + comFee, "Fee must be paid to create a bounty");

        // Check if the community has an incentive structure
        require(tgetherIncentivesContract.getIncentiveParamsExist(
            tgetherArtifactConsensusContract.getArtifactSubmissionCommunity(_submissionId)
        ), "Community must have an incentive structure");
            
        bool _isFunded = tgetherFundContract.fundUpkeep{value: fee}(address(this));
        require(_isFunded, "Upkeep funding failed");

        bounties[bountiesId] = Bounty(msg.value - fee, msg.sender, false);
        artifactSubmissionBounties[_submissionId].push(bountiesId);
        emit BountyCreated(bountiesId, _submissionId, msg.sender, msg.value - fee);
        
        bountiesId++;
        return bountiesId - 1;
    }

    function groupMembers(uint256 _artifactSubmission, uint256 _credsNeededForReview) internal view returns (address[] memory acceptMembers, address[] memory rejectMembers) {
        uint256[] memory reviews = tgetherArtifactConsensusContract.getReviewsForSubmission(_artifactSubmission);
        address[] memory tempAccept = new address[](reviews.length);
        address[] memory tempReject = new address[](reviews.length);
        uint256 acceptCount = 0;
        uint256 rejectCount = 0;

        for (uint256 i = 0; i < reviews.length; i++) {
            tgetherArtifactConsensusInterface.Review memory review = tgetherArtifactConsensusContract.getReview(reviews[i]);
            if (review.afterConsensus || review.creds < _credsNeededForReview) {
                continue;
            }
            if (review.consensus == 2) {
                tempAccept[acceptCount] = review.member;
                acceptCount++;
            } else {
                tempReject[rejectCount] = review.member;
                rejectCount++;
            }
        }

        // Resize arrays
        acceptMembers = new address[](acceptCount);
        rejectMembers = new address[](rejectCount);

        for (uint256 i = 0; i < acceptCount; i++) {
            acceptMembers[i] = tempAccept[i];
        }
        for (uint256 j = 0; j < rejectCount; j++) {
            rejectMembers[j] = tempReject[j];
        }
    }

    function whoToPay(
        address[] memory acceptMembers, 
        address[] memory rejectMembers, 
        string memory _communityName,
        uint256 _artifactSubmission,
        uint256 _numReviewsForAcceptance
    ) internal view returns (address[] memory membersToPay) {
        tgetherIncentivesInterface.IncentiveStructure incentiveStructure = tgetherIncentivesContract.getInctiveStructure(_communityName);
        tgetherArtifactConsensusInterface.Consensus consensus = tgetherArtifactConsensusContract.getArtifactConsesous(_artifactSubmission); 
        uint256 totalLength = acceptMembers.length + rejectMembers.length;
        if (consensus == tgetherArtifactConsensusInterface.Consensus.NotProcessed || consensus == tgetherArtifactConsensusInterface.Consensus.Pending || totalLength < _numReviewsForAcceptance) {
            return membersToPay;
        }

        if (incentiveStructure == tgetherIncentivesInterface.IncentiveStructure.Equal) {
            membersToPay = new address[](totalLength);
            for (uint256 i = 0; i < acceptMembers.length; i++) {
                membersToPay[i] = acceptMembers[i];
            }
            for (uint256 j = 0; j < rejectMembers.length; j++) {
                membersToPay[acceptMembers.length + j] = rejectMembers[j];
            }
        } else if (incentiveStructure == tgetherIncentivesInterface.IncentiveStructure.consensusAligned) {            
            if (consensus == tgetherArtifactConsensusInterface.Consensus.Accepted) {
                membersToPay = acceptMembers;
            } else if (consensus == tgetherArtifactConsensusInterface.Consensus.Rejected) {
                membersToPay = rejectMembers;
            }
        }
        return membersToPay;
    }

    function getRefundBountyArrays(uint256[] memory submissionBounties) internal view returns (address[] memory, uint256[] memory) {
        address[] memory tempAddresses = new address[](submissionBounties.length);
        uint256[] memory tempAmounts = new uint256[](submissionBounties.length);
        uint256 count = 0;

        for (uint256 i = 0; i < submissionBounties.length; i++) {
            Bounty memory bounty = bounties[submissionBounties[i]];
            if (!bounty.bountyPaid) {
                tempAddresses[count] = bounty.bountyCreator;
                tempAmounts[count] = bounty.bountyAmount;
                count++;
            }
        }

        address[] memory membersToRefund = new address[](count);
        uint256[] memory bountiesToRefund = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            membersToRefund[i] = tempAddresses[i];
            bountiesToRefund[i] = tempAmounts[i];
        }

        return (membersToRefund, bountiesToRefund);
    }


    function getPaymentAmount(uint256 _submissionId, uint256 reviewCount, string memory _communityName) internal view returns (uint256 amount) {
        uint256 totalPayment = 0;
        uint256[] memory submissionBounties = artifactSubmissionBounties[_submissionId];
        for (uint256 i = 0; i < submissionBounties.length; i++) {
            Bounty memory bounty = bounties[submissionBounties[i]];
            if (!bounty.bountyPaid) {
                totalPayment += bounty.bountyAmount;
            }
        }

        (uint256 _communityFee, ) = tgetherIncentivesContract.getCommunityFeeInfo(_communityName);
        amount = (totalPayment - _communityFee) / reviewCount;
        
    }

    function getPaymentArrays(uint256 _submissionId) internal view returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory submissionBounties = artifactSubmissionBounties[_submissionId];
        if (submissionBounties.length == 0) {
            return (false, "");
        }

        upkeepNeeded = true;
        string memory _communityName = tgetherArtifactConsensusContract.getArtifactSubmissionCommunity(_submissionId);

        (uint256 numReviewsForAcceptance, uint256 credsNeededForReview, ) = tgetherCommunityConsensusContract.getCommunityReviewParams(_communityName);
        (address[] memory acceptMembers, address[] memory rejectMembers) = groupMembers(_submissionId, credsNeededForReview);
        address[] memory membersToPay = whoToPay(acceptMembers, rejectMembers, _communityName, _submissionId, numReviewsForAcceptance);

        if (membersToPay.length == 0) {
            (address[] memory addresses, uint256[] memory amounts) = getRefundBountyArrays(submissionBounties);
            performData = abi.encode(addresses, amounts, _submissionId);
        } else {
            uint256 amount = getPaymentAmount(_submissionId, membersToPay.length, _communityName);
            uint256[] memory amounts = new uint256[](membersToPay.length);
            for (uint256 i = 0; i < membersToPay.length; i++) {
                amounts[i] = amount;
            }
            performData = abi.encode(membersToPay, amounts, _submissionId);
        }
    }

    function processIncentives(bytes memory _performData) internal {
        (address[] memory addresses, uint256[] memory amounts, uint256 submissionId) = abi.decode(_performData, (address[], uint256[], uint256));
        require(addresses.length == amounts.length, "Addresses and amounts must be the same length");
        tgetherArtifactConsensusInterface.Consensus consensus = tgetherArtifactConsensusContract.getArtifactConsesous(submissionId); 
        require(consensus == tgetherArtifactConsensusInterface.Consensus.Accepted || consensus == tgetherArtifactConsensusInterface.Consensus.Rejected, "Artifact must be accepted or rejected");

        
        for (uint256 i = 0; i < addresses.length; i++) {
            _sendReward(addresses[i], amounts[i]);
        }

        string memory _communityName = tgetherArtifactConsensusContract.getArtifactSubmissionCommunity(submissionId);
        (uint256 _communityFee, address _contractRecieveAddress) = tgetherIncentivesContract.getCommunityFeeInfo(_communityName);
        if (_communityFee > 0) {
            _sendReward(_contractRecieveAddress, _communityFee);
        }

        uint256[] memory submissionBounties = artifactSubmissionBounties[submissionId];
        for (uint256 i = 0; i < submissionBounties.length; i++) {
            bounties[submissionBounties[i]].bountyPaid = true;
        }
    }

    function checkLog(
        Log calldata log,
        bytes memory 
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256 _submissionId = uint256(log.topics[1]);

        if(artifactSubmissionBounties[_submissionId].length > 0) {
            upkeepNeeded = true;
            (upkeepNeeded, performData) = getPaymentArrays(_submissionId); 

            
        }
    }

    function performUpkeep(bytes calldata _performData) external ownerOrAutomation nonReentrant {
        processIncentives(_performData);
    }

    function _sendReward(address recipient, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than zero");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        emit BountyPaid(recipient, amount);
    }



    function manualUpkeep(uint256 _submissionId) external nonReentrant {
        (bool upkeepNeeded, bytes memory performData) = getPaymentArrays(_submissionId); 
        if (upkeepNeeded) {
            processIncentives(performData);
        }
    }


    // Getters:
    function GetArtifactSubmissionBounties(uint256 _submissionId) external view returns (uint256[] memory) {
        return artifactSubmissionBounties[_submissionId];
    }

    // Setters
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setTgetherFundAddress(address _tgetherFundAddress) external onlyOwner {
        tgetherFundContract = tgFundInterface(_tgetherFundAddress);
    }

    function setTgetherArtifactConsensusAddress(address _tgetherArtifactConsensusAddress) external onlyOwner {
        tgetherArtifactConsensusContract = tgetherArtifactConsensusInterface(_tgetherArtifactConsensusAddress);
    }

    function setTgetherCommunityConsensusAddress(address _tgetherCommunityConsensusAddress) external onlyOwner {
        tgetherCommunityConsensusContract = CommunityConsensusInterface(_tgetherCommunityConsensusAddress);
    }

    function setTgetherIncentivesAddress(address _tgetherIncentivesAddress) external onlyOwner {
        tgetherIncentivesContract = tgetherIncentivesInterface(_tgetherIncentivesAddress);
    }

    function setAutomationContractAddress(address _AutomationContractAddress) external onlyOwner {
        AutomationContractAddress = _AutomationContractAddress;
    }
}
