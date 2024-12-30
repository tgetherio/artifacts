// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract SendArtifact {
    address public link;
    address public router;
    uint256 public chainId;
    uint64 public destinationChainSelector;
    address public receiver;

    // Event to log details of the sent artifact
    event ArtifactSent(
        uint256 indexed tokenId,
        address indexed nftContract,
        address indexed currentOwner,
        uint64 destinationChainSelector,
        bytes32 messageId,
        uint256 timestamp
    );

    constructor(
        address _router,
        uint256 _chainId,
        uint64 _destinationChainSelector,
        address _receiver
    ) {
        router = _router;
        chainId = _chainId;
        destinationChainSelector = _destinationChainSelector;
        receiver = _receiver;
    }

    /**
     * @notice Sends an NFT or token data cross-chain.
     * Supports ERC-721 and ERC-1155 standards.
     * @param nftContract Address of the NFT contract.
     * @param tokenId Token ID of the NFT or token.
     */
    function sendArtifact(address nftContract, uint256 tokenId) external payable returns (bytes32 messageId) {
        string memory tokenURI;
        string memory name;
        string memory symbol;
        address currentOwner;

        // Check which token standard the contract adheres to
        if (IERC165(nftContract).supportsInterface(type(IERC721Metadata).interfaceId)) {
            // Handle ERC-721
            currentOwner = IERC721(nftContract).ownerOf(tokenId);
            tokenURI = IERC721Metadata(nftContract).tokenURI(tokenId);
            name = IERC721Metadata(nftContract).name();
            symbol = IERC721Metadata(nftContract).symbol();
        } else if (IERC165(nftContract).supportsInterface(type(IERC1155MetadataURI).interfaceId)) {
            // Handle ERC-1155
            currentOwner = msg.sender; // For ERC-1155, assume sender owns it since ownership isn't tracked
            tokenURI = IERC1155MetadataURI(nftContract).uri(tokenId);
            name = "ERC1155 Collection"; // Placeholder for ERC-1155
            symbol = "ERC1155"; // Placeholder for ERC-1155
        } else {
            revert("Unsupported token standard");
        }

        uint256 timestamp = block.timestamp;

        // Encode the data payload with tokenURI included
        bytes memory dataPayload = abi.encode(
            tokenId,
            nftContract,
            chainId,
            currentOwner,
            name,
            symbol,
            tokenURI, // Include tokenURI in the cross-chain message
            timestamp
        );

        // Prepare the message for Chainlink CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: dataPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})),
            feeToken: address(0)
        });

        uint256 fees = IRouterClient(router).getFee(destinationChainSelector, message);
        require(msg.value >= fees, "Insufficient funds to send artifact");

        messageId = IRouterClient(router).ccipSend{value: fees}(destinationChainSelector, message);

        emit ArtifactSent(tokenId, nftContract, currentOwner, destinationChainSelector, messageId, timestamp);
    }

    /**
     * @notice Tests the fee price for sending an artifact cross-chain.
     * @param nftContract Address of the NFT contract.
     * @param tokenId Token ID of the NFT or token.
     * @return fees Fee amount required to send the artifact.
     */
    function testFeePrice(address nftContract, uint256 tokenId) external view returns (uint256 fees) {
        string memory tokenURI;
        string memory name;
        string memory symbol;
        address currentOwner;

        // Check which token standard the contract adheres to
        if (IERC165(nftContract).supportsInterface(type(IERC721Metadata).interfaceId)) {
            // Handle ERC-721
            currentOwner = IERC721(nftContract).ownerOf(tokenId);
            tokenURI = IERC721Metadata(nftContract).tokenURI(tokenId);
            name = IERC721Metadata(nftContract).name();
            symbol = IERC721Metadata(nftContract).symbol();
        } else if (IERC165(nftContract).supportsInterface(type(IERC1155MetadataURI).interfaceId)) {
            // Handle ERC-1155
            currentOwner = msg.sender; // For ERC-1155, assume sender owns it since ownership isn't tracked
            tokenURI = IERC1155MetadataURI(nftContract).uri(tokenId);
            name = "ERC1155 Collection"; // Placeholder for ERC-1155
            symbol = "ERC1155"; // Placeholder for ERC-1155
        } else {
            revert("Unsupported token standard");
        }

        uint256 timestamp = block.timestamp;

        // Encode the data payload with tokenURI included
        bytes memory dataPayload = abi.encode(
            tokenId,
            nftContract,
            chainId,
            currentOwner,
            name,
            symbol,
            tokenURI, // Include tokenURI in the cross-chain message
            timestamp
        );

        // Prepare the message for Chainlink CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: dataPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})),
            feeToken: address(0)
        });

        fees = IRouterClient(router).getFee(destinationChainSelector, message);
    }
}
