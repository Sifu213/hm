// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HotMolandak is ERC721, Ownable {
    uint256 public constant MINT_PRICE = 5 ether; // 5 MON (assuming 18 decimals)
    uint256 public constant INITIAL_LIFETIME = 7 days;
    uint256 public constant TRANSFER_BONUS = 2 days;
    uint256 public constant BURN_REWARD = 0.1 ether; // 0.1 MON reward for burning expired NFTs
    
    uint256 private _tokenIdCounter;
    
    struct NFTData {
        uint256 expiryTime;
        uint256 transferCount;
        address[] ownerHistory;
        bool isAlive;
    }
    
    mapping(uint256 => NFTData) public nftData;
    mapping(address => bool) public hasMinted;
    
    event NFTMinted(uint256 indexed tokenId, address indexed to, uint256 expiryTime);
    event NFTTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 newExpiryTime, uint256 transferCount);
    event NFTBurned(uint256 indexed tokenId, address indexed burner, string reason);
    event NFTExpired(uint256 indexed tokenId);
    
    constructor() ERC721("HotMolandak", "HMDK") Ownable(msg.sender) {}
    
    modifier onlyAlive(uint256 tokenId) {
        require(nftData[tokenId].isAlive, "NFT is dead");
        require(block.timestamp < nftData[tokenId].expiryTime, "NFT has expired");
        _;
    }
    
    function mint() external payable {
        require(msg.value == MINT_PRICE, "Incorrect mint price");
        require(!hasMinted[msg.sender], "Already minted");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _safeMint(msg.sender, tokenId);
        
        // Initialize NFT data
        nftData[tokenId].expiryTime = block.timestamp + INITIAL_LIFETIME;
        nftData[tokenId].transferCount = 0;
        nftData[tokenId].ownerHistory.push(msg.sender);
        nftData[tokenId].isAlive = true;
        
        hasMinted[msg.sender] = true;
        
        emit NFTMinted(tokenId, msg.sender, nftData[tokenId].expiryTime);
    }
    
    function transfer(address to, uint256 tokenId) external onlyAlive(tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(to != address(0), "Cannot transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");
        
        // Check if 'to' address has already owned this NFT
        address[] memory history = nftData[tokenId].ownerHistory;
        for (uint i = 0; i < history.length; i++) {
            if (history[i] == to) {
                _burnNFT(tokenId, "Transferred to previous owner");
                return;
            }
        }
        
        // Update NFT data
        nftData[tokenId].expiryTime = block.timestamp + TRANSFER_BONUS;
        nftData[tokenId].transferCount++;
        nftData[tokenId].ownerHistory.push(to);
        
        // Transfer the NFT
        _transfer(msg.sender, to, tokenId);
        
        emit NFTTransferred(tokenId, msg.sender, to, nftData[tokenId].expiryTime, nftData[tokenId].transferCount);
    }
    
    function burnExpiredNFTs(uint256[] calldata tokenIds) external {
        uint256 burnCount = 0;
        
        for (uint i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            
            if (nftData[tokenId].isAlive && block.timestamp >= nftData[tokenId].expiryTime) {
                _burnNFT(tokenId, "Expired");
                burnCount++;
            }
        }
        
        if (burnCount > 0) {
            uint256 reward = burnCount * BURN_REWARD;
            require(address(this).balance >= reward, "Insufficient contract balance");
            payable(msg.sender).transfer(reward);
        }
    }
    
    function _burnNFT(uint256 tokenId, string memory reason) internal {
        nftData[tokenId].isAlive = false;
        _burn(tokenId);
        emit NFTBurned(tokenId, msg.sender, reason);
    }
    
    // View functions
    function getNFTData(uint256 tokenId) external view returns (
        uint256 expiryTime,
        uint256 transferCount,
        address[] memory ownerHistory,
        bool isAlive,
        uint256 timeLeft
    ) {
        NFTData memory data = nftData[tokenId];
        uint256 remainingTime = data.expiryTime > block.timestamp ? data.expiryTime - block.timestamp : 0;
        
        return (
            data.expiryTime,
            data.transferCount,
            data.ownerHistory,
            data.isAlive,
            remainingTime
        );
    }
    
    function getExpiredNFTs() external view returns (uint256[] memory) {
        uint256[] memory expired = new uint256[](_tokenIdCounter);
        uint256 expiredCount = 0;
        
        for (uint256 i = 1; i <= _tokenIdCounter; i++) {
            if (nftData[i].isAlive && block.timestamp >= nftData[i].expiryTime) {
                expired[expiredCount] = i;
                expiredCount++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](expiredCount);
        for (uint256 i = 0; i < expiredCount; i++) {
            result[i] = expired[i];
        }
        
        return result;
    }
    
    function getTotalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    function isNFTAlive(uint256 tokenId) external view returns (bool) {
        return nftData[tokenId].isAlive && block.timestamp < nftData[tokenId].expiryTime;
    }
    
    // Emergency functions
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
    
    function emergencyBurn(uint256 tokenId) external onlyOwner {
        _burnNFT(tokenId, "Emergency burn");
    }
    
    // Allow the contract to receive ETH for rewards
    receive() external payable {}
}