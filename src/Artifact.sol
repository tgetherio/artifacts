// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract Artifacts is CCIPReceiver {
    using Client for Client.Any2EVMMessage;

    enum ArtifactType { Local, Imported }

    struct Artifact {
        address nftContract;            // Contract address of the NFT
        uint256 tokenId;                // Token ID of the NFT
        address owner;                  // Original owner of the NFT
        string name;                    // Name of the NFT
        string symbol;                  // Symbol of the NFT
        string tokenURI;                // Metadata URI of the NFT
        uint256 timestamp;              // Timestamp of when the artifact was sent
        ArtifactType artifactType;      // Type of artifact: Local or Imported
    }

    // Mapping of artifact ID to artifact data
    mapping(uint256 => Artifact) public artifacts;
    uint256 public artifactCounter;

    // Chainlink CCIP Router and Link token addresses
    address public link;
    address public router;

    // Events
    event ArtifactCreated(uint256 indexed artifactId, ArtifactType artifactType, address creator);
    event ImportedArtifactReceived(uint256 indexed artifactId, address nftContract, uint256 tokenId);

    constructor(address _link, address _router) CCIPReceiver(_router) {
        link = _link;
        router = _router;
        artifactCounter = 0;
    }

    // Function to handle received artifacts from other chains
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
    (
        uint256 tokenId,
        address nftContract,
        address owner,
        string memory name,
        string memory symbol,
        string memory tokenURI,  // Added to handle URI for metadata
        uint256 timestamp
    ) = abi.decode(
        message.data,
        (uint256, address, address, string, string, string, uint256)
    );

    artifactCounter++;
    artifacts[artifactCounter] = Artifact({
        nftContract: nftContract,
        tokenId: tokenId,
        owner: owner,
        name: name,
        symbol: symbol,
        tokenURI: tokenURI,  // Store the URI for metadata reference
        timestamp: timestamp,
        artifactType: ArtifactType.Imported
    });

    emit ImportedArtifactReceived(artifactCounter, nftContract, tokenId);
}
}