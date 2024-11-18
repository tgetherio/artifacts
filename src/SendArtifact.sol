// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "forge-std/console.sol";
contract SendArtifact {
    address public link;
    address public router;
    uint256 public chainId;
    uint64 public destinationChainSelector;
    address public reciver;
    // Event to log details of the sent artifact
    event ArtifactSent(uint256 indexed tokenId, address indexed nftContract, address indexed currentOwner, uint64 destinationChainSelector, bytes32 messageId, uint256 timestamp);

    constructor(address _router, uint256 _chainId, uint64 _destinationChainSelector, address _reciver) {
        router = _router;
        chainId = _chainId;
        destinationChainSelector = _destinationChainSelector;
        reciver = _reciver; 

    }

    // Function to send an NFT's data cross-chain
     function sendArtifact(
        address nftContract,
        uint256 tokenId
    ) external payable returns (bytes32 messageId) {

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

        console.log("chainId: ", chainId);
        bytes memory dataPayload = abi.encode(
            tokenId,
            nftContract,
            chainId,
            currentOwner,
            name,
            symbol,
            tokenURI,  // Include tokenURI in the cross-chain message
            timestamp
        );

        // Prepare the message for Chainlink CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(reciver),
            data: dataPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})),
            feeToken: address(0)
        });

        uint256 fees = IRouterClient(router).getFee(destinationChainSelector, message);
        require(msg.value >= fees, "Insufficient funds to send artifact");
        messageId = IRouterClient(router).ccipSend{value: fees}(destinationChainSelector, message);

        // Approve the fee and send the message
        emit ArtifactSent(tokenId, nftContract, currentOwner, destinationChainSelector, messageId, timestamp);
    }

    function TestFeePrice(
        address nftContract,
        uint256 tokenId
    ) external view returns (uint256 fees){
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
            chainId,
            currentOwner,
            name,
            symbol,
            tokenURI,  // Include tokenURI in the cross-chain message
            timestamp
        );

        // Prepare the message for Chainlink CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(reciver),
            data: dataPayload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000})),
            feeToken: address(0)
        });

        fees = IRouterClient(router).getFee(destinationChainSelector, message);
    }
}