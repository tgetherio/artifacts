// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface tgetherArtifacts {
    function receiveLocalChain(
        uint256 tokenId,
        address nftContract,
        address owner,
        string memory name,
        string memory symbol,
        string memory tokenURI
    ) external returns (uint256);
}

contract SendLocalArtifact {
    address owner;
    address public artifactContract;

    modifier ownerOnly() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Sends an artifact to the artifact contract.
     * Supports both ERC-721 and ERC-1155 tokens.
     * @param nftContract Address of the NFT contract.
     * @param tokenId ID of the token to send.
     * @return artifactId The ID of the artifact created in the artifact contract.
     */
    function sendArtifact(address nftContract, uint256 tokenId) external returns (uint256 artifactId) {
        string memory tokenURI;
        string memory name;
        string memory symbol;
        address currentOwner;

        // Check which token standard the contract adheres to
        if (IERC165(nftContract).supportsInterface(type(IERC721Metadata).interfaceId)) {
            // Handle ERC-721
            currentOwner = IERC721Metadata(nftContract).ownerOf(tokenId);
            tokenURI = getERC721Metadata(nftContract, tokenId);
            name = IERC721Metadata(nftContract).name();
            symbol = IERC721Metadata(nftContract).symbol();
        } else if (IERC165(nftContract).supportsInterface(type(IERC1155MetadataURI).interfaceId)) {
            // Handle ERC-1155
            currentOwner = msg.sender; // Assume the sender owns the token for ERC-1155
            tokenURI = getERC1155Metadata(nftContract, tokenId);
            name = "ERC1155 Collection"; // Placeholder for ERC-1155
            symbol = "ERC1155"; // Placeholder for ERC-1155
        } else {
            revert("Unsupported token standard");
        }

        // Send data to the artifact contract
        artifactId = tgetherArtifacts(artifactContract).receiveLocalChain(tokenId, nftContract, currentOwner, name, symbol, tokenURI);
    }

    /**
     * @notice Sets the artifact contract address.
     * @param _artifactContract Address of the artifact contract.
     */
    function setArtifactContract(address _artifactContract) external ownerOnly {
        artifactContract = _artifactContract;
    }

    /**
     * @dev Retrieves metadata for an ERC-721 token.
     * @param nftContract Address of the ERC-721 contract.
     * @param tokenId ID of the token.
     * @return tokenURI The metadata URI for the token.
     */
    function getERC721Metadata(address nftContract, uint256 tokenId) internal view returns (string memory) {
        try IERC721Metadata(nftContract).tokenURI(tokenId) returns (string memory _tokenURI) {
            return _tokenURI;
        } catch {
            return "Metadata not available";
        }
    }

    /**
     * @dev Retrieves metadata for an ERC-1155 token.
     * @param nftContract Address of the ERC-1155 contract.
     * @param tokenId ID of the token.
     * @return tokenURI The metadata URI for the token.
     */
    function getERC1155Metadata(address nftContract, uint256 tokenId) internal view returns (string memory) {
        try IERC1155MetadataURI(nftContract).uri(tokenId) returns (string memory _uri) {
            return _uri;
        } catch {
            return "Metadata not available";
        }
    }
}
