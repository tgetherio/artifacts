// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract Artifacts is CCIPReceiver {
    using Client for Client.Any2EVMMessage;


    struct Artifact {
        address nftContract;
        uint256 chainId;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
        uint256 timestamp;
    }

    mapping(uint256 => Artifact) public artifacts;
    uint256 public artifactCounter;

    address public router;
    address public localSenderContract;
    uint256 public chainId;
    address contractOwner;
    // Events
    event ArtifactCreated(
        uint256 indexed artifactId,
        address nftContract,
        uint256 chainid,
        uint256 tokenId,
        address owner,
        string name,
        string symbol,
        string tokenURI,
        uint256 timestamp
    );
    event ImportedArtifactReceived(uint256 indexed artifactId, address nftContract, uint256 chainId, uint256 tokenId);

    constructor(address _router, uint256 _chainId, address _localSenderContract) CCIPReceiver(_router){
        router = _router;
        artifactCounter = 0;
        chainId = _chainId;
        localSenderContract = _localSenderContract;
        contractOwner = msg.sender;
        artifactCounter = 1;
    }

    modifier ownerOnly() {
        require(msg.sender == contractOwner, "Not the contract owner");
        _;
    }

    modifier onlyLocalSender() {
        require(msg.sender == localSenderContract, "Not the local sender contract");
        _;
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (
            uint256 _tokenId,
            address _nftContract,
            uint256 _chainId,
            address _owner,
            string memory _name,
            string memory _symbol,
            string memory _tokenURI,
            uint256 _timestamp
        ) = abi.decode(message.data, (uint256, address, uint256, address, string, string, string, uint256));
        
        emit ImportedArtifactReceived(artifactCounter, _nftContract, _chainId, _tokenId);
        artifacts[artifactCounter] = Artifact({
            nftContract: _nftContract,
            tokenId: _tokenId,
            chainId: _chainId,
            owner: _owner,
            name: _name,
            symbol: _symbol,
            tokenURI: _tokenURI,
            timestamp: _timestamp
        });

        emit ArtifactCreated(artifactCounter, _nftContract, _chainId, _tokenId, _owner, _name, _symbol, _tokenURI, _timestamp);
        artifactCounter++;

    }


    function receiveLocalChain(  
            uint256 tokenId,
            address nftContract,
            address owner,
            string memory name,
            string memory symbol,
            string memory tokenURI) external  onlyLocalSender returns (uint256) { 
        uint256 timestamp = block.timestamp;

        artifacts[artifactCounter] = Artifact({
            nftContract: nftContract,
            tokenId: tokenId,
            chainId: chainId,
            owner: owner,
            name: name,
            symbol: symbol,
            tokenURI: tokenURI,
            timestamp: timestamp
        });

        emit ArtifactCreated(artifactCounter, nftContract, chainId, tokenId, owner, name, symbol, tokenURI, timestamp);
        artifactCounter++;

        return artifactCounter - 1;

    }

    function getArtifactExists(uint256 artifactId) public view returns (bool) {
        return artifacts[artifactId].tokenId != 0;
    }

    function setLocalSenderContract(address _localSenderContract) external ownerOnly {
        localSenderContract = _localSenderContract;
    }
}
