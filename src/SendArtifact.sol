// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract SendArtifact {
    address public link;
    address public router;

    // Event to log details of the sent artifact
    event ArtifactSent(uint256 indexed tokenId, address indexed nftContract, address indexed currentOwner, uint64 destinationChainSelector, bytes32 messageId, uint256 timestamp);

    constructor(address _link, address _router) {
        link = _link;
        router = _router;
    }

    // Function to send an NFT's data cross-chain
     function sendArtifact(
        address nftContract,
        uint256 tokenId,
        uint64 destinationChainSelector,
        address receiver
    ) external returns (bytes32 messageId) {
        // Get the current owner of the NFT
        address currentOwner = IERC721(nftContract).ownerOf(tokenId);

        // Retrieve metadata from the NFT contract
        string memory tokenURI;
        try IERC721Metadata(nftContract).tokenURI(tokenId) returns (string memory _tokenURI) {
            tokenURI = _tokenURI;
        } catch {
            tokenURI = "Metadata not available";  // Fallback in case of error
        }

        string memory name = IERC721Metadata(nftContract).name();
        string memory symbol = IERC721Metadata(nftContract).symbol();
        uint256 timestamp = block.timestamp;

        // Encode the data payload with tokenURI included
        bytes memory dataPayload = abi.encode(
            tokenId,
            nftContract,
            currentOwner,
            name,
            symbol,
            tokenURI,  // Include tokenURI in the cross-chain message
            timestamp
        );

        // Prepare the message for Chainlink CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: dataPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})),
            feeToken: link
        });

        uint256 fee = IRouterClient(router).getFee(destinationChainSelector, message);
        require(IERC20(link).balanceOf(address(this)) >= fee, "Insufficient LINK balance");

        // Approve the LINK fee and send the message
        IERC20(link).approve(address(router), fee);
        messageId = IRouterClient(router).ccipSend(destinationChainSelector, message);
        emit ArtifactSent(tokenId, nftContract, currentOwner, destinationChainSelector, messageId, timestamp);
    }
}