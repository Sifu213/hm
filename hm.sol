// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bombadak is ERC721, Ownable {
    uint256 public constant MINT_PRICE = 1 ether;
    uint256 public constant INITIAL_LIFETIME = 1 days;
    uint256 public constant TRANSFER_BONUS = 1 days;
    uint256 public constant MAX_SUPPLY = 100;
    
    uint256 private _tokenIdCounter;
    bool public gameEnded = false;
    
    // Tracking du champion de longévité
    uint256 public longestLivingTokenId = 0;
    uint256 public longestLifetime = 0;
    
    // URIs pour les métadonnées des NFTs
    string private _baseTokenURIAlive;
    string private _baseTokenURIDead;
    
    struct NFTData {
        uint256 expiryTime;
        uint256 transferCount;
        address[] ownerHistory;
        bool isAlive;
        bool isDead; // Nouveau: état mort (non-transférable mais pas burn)
    }
    
    mapping(uint256 => NFTData) public nftData;
    mapping(address => bool) public hasMinted;
    
    event NFTMinted(uint256 indexed tokenId, address indexed to, uint256 expiryTime);
    event NFTTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 newExpiryTime, uint256 transferCount);
    event NFTDied(uint256 indexed tokenId, address indexed killer, string reason);
    event GameEnded(uint256 indexed championTokenId, uint256 totalRewards, uint256 winnersCount);
    event RewardDistributed(address indexed winner, uint256 amount);
    
    constructor(string memory baseTokenURIAlive, string memory baseTokenURIDead) 
        ERC721("Bombadak", "BMDK") Ownable(msg.sender) {
        _baseTokenURIAlive = baseTokenURIAlive;
        _baseTokenURIDead = baseTokenURIDead;
    }
    
    modifier onlyAlive(uint256 tokenId) {
        require(nftData[tokenId].isAlive && !nftData[tokenId].isDead, "NFT is dead");
        require(block.timestamp < nftData[tokenId].expiryTime, "NFT has expired");
        _;
    }
    
    function mint() external payable {
        require(msg.value == MINT_PRICE, "Incorrect mint price");
        require(!hasMinted[msg.sender], "Already minted");
        require(_tokenIdCounter < MAX_SUPPLY, "Maximum supply reached");
        require(!gameEnded, "Game has ended");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _safeMint(msg.sender, tokenId);
        
        // Initialize NFT data
        nftData[tokenId].expiryTime = block.timestamp + INITIAL_LIFETIME;
        nftData[tokenId].transferCount = 0;
        nftData[tokenId].ownerHistory.push(msg.sender);
        nftData[tokenId].isAlive = true;
        nftData[tokenId].isDead = false;
        
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
                _killNFT(tokenId, "Transferred to previous owner");
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
    
    // Nouvelle fonction pour "tuer" un NFT sans le burn
    function _killNFT(uint256 tokenId, string memory reason) internal {
        // Calculer la durée de vie totale avant de tuer le NFT
        uint256 totalLifetime = nftData[tokenId].transferCount * TRANSFER_BONUS + INITIAL_LIFETIME;
        
        // Vérifier si c'est un nouveau record de longévité
        if (totalLifetime > longestLifetime) {
            longestLifetime = totalLifetime;
            longestLivingTokenId = tokenId;
        }
        
        nftData[tokenId].isAlive = false;
        nftData[tokenId].isDead = true;
        nftData[tokenId].expiryTime = block.timestamp; // Mettre le temps de vie à zéro
        emit NFTDied(tokenId, msg.sender, reason);
    }
    
    // Fonction publique pour marquer les NFTs expirés comme morts
    function markExpiredNFTs(uint256[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            
            // Vérifier que le NFT existe et est expiré
            if (nftData[tokenId].isAlive && 
                !nftData[tokenId].isDead && 
                block.timestamp >= nftData[tokenId].expiryTime) {
                _killNFT(tokenId, "Expired");
            }
        }
    }
    
    // Override du tokenURI pour images dynamiques
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        NFTData memory data = nftData[tokenId];
        
        // Si le NFT est mort ou expiré, retourner l'URI "dead"
        if (data.isDead || !data.isAlive || block.timestamp >= data.expiryTime) {
            return _baseTokenURIDead;
        }
        
        // Sinon retourner l'URI "alive"
        return _baseTokenURIAlive;
    }
    
    // Fonctions pour mettre à jour les URIs (owner only)
    function setBaseTokenURIAlive(string memory newURI) external onlyOwner {
        _baseTokenURIAlive = newURI;
    }
    
    function setBaseTokenURIDead(string memory newURI) external onlyOwner {
        _baseTokenURIDead = newURI;
    }
    
    // View functions
    function getNFTData(uint256 tokenId) external view returns (
        uint256 expiryTime,
        uint256 transferCount,
        address[] memory ownerHistory,
        bool isAlive,
        bool isDead,
        uint256 timeLeft
    ) {
        NFTData memory data = nftData[tokenId];
        uint256 remainingTime = data.expiryTime > block.timestamp ? data.expiryTime - block.timestamp : 0;
        
        return (
            data.expiryTime,
            data.transferCount,
            data.ownerHistory,
            data.isAlive,
            data.isDead,
            remainingTime
        );
    }
    
    function getExpiredNFTs() external view returns (uint256[] memory) {
        uint256[] memory expired = new uint256[](_tokenIdCounter);
        uint256 expiredCount = 0;
        
        for (uint256 i = 1; i <= _tokenIdCounter; i++) {
            if (nftData[i].isAlive && 
                !nftData[i].isDead && 
                block.timestamp >= nftData[i].expiryTime) {
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
    
    function getDeadNFTs() external view returns (uint256[] memory) {
        uint256[] memory dead = new uint256[](_tokenIdCounter);
        uint256 deadCount = 0;
        
        for (uint256 i = 1; i <= _tokenIdCounter; i++) {
            if (nftData[i].isDead || !nftData[i].isAlive) {
                dead[deadCount] = i;
                deadCount++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](deadCount);
        for (uint256 i = 0; i < deadCount; i++) {
            result[i] = dead[i];
        }
        
        return result;
    }
    
    function getTotalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    function isNFTAlive(uint256 tokenId) external view returns (bool) {
        return nftData[tokenId].isAlive && 
               !nftData[tokenId].isDead && 
               block.timestamp < nftData[tokenId].expiryTime;
    }
    
    function isNFTDead(uint256 tokenId) external view returns (bool) {
        return nftData[tokenId].isDead || 
               !nftData[tokenId].isAlive || 
               block.timestamp >= nftData[tokenId].expiryTime;
    }
    
    // Emergency functions
    // Fonction pour terminer le jeu et distribuer les récompenses
    function endGameAndDistribute() external onlyOwner {
        require(!gameEnded, "Game already ended");
        require(_tokenIdCounter == MAX_SUPPLY, "Not all NFTs minted yet");
        require(areAllNFTsDead(), "Not all NFTs are dead yet");
        require(longestLivingTokenId > 0, "No champion found");
        
        gameEnded = true;
        
        // Récupérer la liste des gagnants (propriétaires du NFT champion)
        address[] memory winners = nftData[longestLivingTokenId].ownerHistory;
        uint256 totalRewards = address(this).balance;
        uint256 rewardPerWinner = totalRewards / winners.length;
        
        // Distribuer les récompenses
        for (uint i = 0; i < winners.length; i++) {
            if (rewardPerWinner > 0) {
                payable(winners[i]).transfer(rewardPerWinner);
                emit RewardDistributed(winners[i], rewardPerWinner);
            }
        }
        
        emit GameEnded(longestLivingTokenId, totalRewards, winners.length);
    }
    
    // Fonction pour vérifier si tous les NFTs sont morts
    function areAllNFTsDead() public view returns (bool) {
        for (uint256 i = 1; i <= _tokenIdCounter; i++) {
            if (nftData[i].isAlive && !nftData[i].isDead && block.timestamp < nftData[i].expiryTime) {
                return false;
            }
        }
        return true;
    }
    
    function emergencyKill(uint256 tokenId) external onlyOwner {
        _killNFT(tokenId, "Emergency kill");
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Allow the contract to receive ETH
        // Fonction withdraw modifiée (seulement si le jeu est terminé)
    function withdraw() external onlyOwner {
        require(gameEnded, "Cannot withdraw before game ends");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Nouvelle fonction pour voir les infos du champion
    function getChampionInfo() external view returns (
        uint256 tokenId,
        uint256 lifetime,
        address[] memory owners,
        uint256 transferCount
    ) {
        if (longestLivingTokenId == 0) {
            return (0, 0, new address[](0), 0);
        }
        
        return (
            longestLivingTokenId,
            longestLifetime,
            nftData[longestLivingTokenId].ownerHistory,
            nftData[longestLivingTokenId].transferCount
        );
    }
    receive() external payable {}
}