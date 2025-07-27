// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MonadTogetherNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    // Compteur pour les token IDs
    Counters.Counter private _tokenIdCounter;
    
    // Mapping des niveaux pour chaque token (1, 2, ou 3)
    mapping(uint256 => uint8) public tokenLevel;
    
    // URIs des métadonnées pour chaque niveau
    mapping(uint8 => string) private _levelTokenURIs;
    
    // Compteurs pour chaque niveau
    mapping(uint8 => uint256) public levelCounts;
    
    // Mapping pour compter les NFT par niveau pour chaque utilisateur
    mapping(address => mapping(uint8 => uint256)) public userLevelCounts;
    
    // Events
    event VictoryNFTMinted(address indexed to, uint256 indexed tokenId, uint8 level, uint256 timestamp);
    event LevelTokenURISet(uint8 level, string tokenURI);
    
    /**
     * @dev Constructeur
     * @param lightningURI L'URI IPFS pour les NFT Lightning (niveau 3)
     * @param swiftURI L'URI IPFS pour les NFT Swift (niveau 2)
     * @param clutchURI L'URI IPFS pour les NFT Clutch (niveau 1)
     */
    constructor(
        string memory lightningURI,
        string memory swiftURI,
        string memory clutchURI
    ) ERC721("Monad Together Victory", "MTV") Ownable(msg.sender) {
        // Initialiser les URIs pour chaque niveau
        _levelTokenURIs[3] = lightningURI;  // Lightning Victory
        _levelTokenURIs[2] = swiftURI;      // Swift Victory
        _levelTokenURIs[1] = clutchURI;     // Clutch Victory
        
        // Commencer les IDs à 1 au lieu de 0
        _tokenIdCounter.increment();
    }
    
    /**
     * @dev Mint un NFT de victoire avec niveau spécifié
     * @param to L'adresse qui recevra le NFT
     * @param level Le niveau de victoire (1, 2, ou 3)
     * @return tokenId L'ID du token minté
     */
    function mintVictoryNFT(address to, uint8 level) public returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        require(level >= 1 && level <= 3, "Invalid level: must be 1, 2, or 3");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Enregistrer le niveau du token
        tokenLevel[tokenId] = level;
        
        // Incrémenter les compteurs
        levelCounts[level]++;
        userLevelCounts[to][level]++;
        
        _safeMint(to, tokenId);
        
        emit VictoryNFTMinted(to, tokenId, level, block.timestamp);
        
        return tokenId;
    }
    
    /**
     * @dev Mint un NFT Lightning Victory (niveau 3) - 20-30s restants
     * @param to L'adresse qui recevra le NFT
     * @return tokenId L'ID du token minté
     */
    function mintLightningVictoryNFT(address to) external returns (uint256) {
        return mintVictoryNFT(to, 3);
    }
    
    /**
     * @dev Mint un NFT Swift Victory (niveau 2) - 10-20s restants
     * @param to L'adresse qui recevra le NFT
     * @return tokenId L'ID du token minté
     */
    function mintSwiftVictoryNFT(address to) external returns (uint256) {
        return mintVictoryNFT(to, 2);
    }
    
    /**
     * @dev Mint un NFT Clutch Victory (niveau 1) - 0-10s restants
     * @param to L'adresse qui recevra le NFT
     * @return tokenId L'ID du token minté
     */
    function mintClutchVictoryNFT(address to) external returns (uint256) {
        return mintVictoryNFT(to, 1);
    }
    
    /**
     * @dev Mint un NFT pour soi-même avec niveau spécifié
     * @param level Le niveau de victoire (1, 2, ou 3)
     * @return tokenId L'ID du token minté
     */
    function mintMyVictoryNFT(uint8 level) external returns (uint256) {
        return mintVictoryNFT(msg.sender, level);
    }
    
    /**
     * @dev Retourne l'URI des métadonnées pour un token selon son niveau
     * FONCTION CRUCIALE POUR LES MARKETPLACES
     * @param tokenId L'ID du token
     * @return L'URI des métadonnées
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721: URI query for nonexistent token");
        
        uint8 level = tokenLevel[tokenId];
        string memory uri = _levelTokenURIs[level];
        
        // Vérifier que l'URI n'est pas vide
        require(bytes(uri).length > 0, "Token URI not set for this level");
        
        return uri;
    }
    
    /**
     * @dev Met à jour l'URI pour un niveau spécifique (seulement le owner)
     * @param level Le niveau (1, 2, ou 3)
     * @param newTokenURI Le nouvel URI
     */
    function setLevelTokenURI(uint8 level, string memory newTokenURI) external onlyOwner {
        require(level >= 1 && level <= 3, "Invalid level");
        require(bytes(newTokenURI).length > 0, "URI cannot be empty");
        _levelTokenURIs[level] = newTokenURI;
        emit LevelTokenURISet(level, newTokenURI);
    }
    
    /**
     * @dev Retourne l'URI pour un niveau spécifique
     * @param level Le niveau (1, 2, ou 3)
     * @return L'URI du niveau
     */
    function getLevelTokenURI(uint8 level) external view returns (string memory) {
        require(level >= 1 && level <= 3, "Invalid level");
        return _levelTokenURIs[level];
    }
    
    /**
     * @dev Retourne le niveau d'un token
     * @param tokenId L'ID du token
     * @return Le niveau du token
     */
    function getTokenLevel(uint256 tokenId) external view returns (uint8) {
        require(ownerOf(tokenId) != address(0), "Query for nonexistent token");
        return tokenLevel[tokenId];
    }
    
    /**
     * @dev Retourne le nombre total de NFTs mintés
     * @return Le nombre total de tokens
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }
    
    /**
     * @dev Retourne le nombre de NFTs mintés pour chaque niveau
     * @return lightning Le nombre de NFT Lightning (niveau 3)
     * @return swift Le nombre de NFT Swift (niveau 2)
     * @return clutch Le nombre de NFT Clutch (niveau 1)
     */
    function getTotalSupplyByLevel() external view returns (uint256 lightning, uint256 swift, uint256 clutch) {
        return (levelCounts[3], levelCounts[2], levelCounts[1]);
    }
    
    /**
     * @dev Retourne le nombre de NFTs possédés par un utilisateur pour chaque niveau
     * @param user L'adresse de l'utilisateur
     * @return lightning Le nombre de NFT Lightning possédés
     * @return swift Le nombre de NFT Swift possédés
     * @return clutch Le nombre de NFT Clutch possédés
     */
    function getUserNFTCountByLevel(address user) external view returns (uint256 lightning, uint256 swift, uint256 clutch) {
        return (userLevelCounts[user][3], userLevelCounts[user][2], userLevelCounts[user][1]);
    }
    
    /**
     * @dev Retourne le prochain token ID qui sera minté
     * @return Le prochain token ID
     */
    function nextTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }
    
    /**
     * @dev Retourne tous les token IDs possédés par une adresse
     * @param owner L'adresse du propriétaire
     * @return tokenIds La liste des token IDs
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        }
        
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 index = 0;
        uint256 totalTokens = _tokenIdCounter.current() - 1;
        
        for (uint256 tokenId = 1; tokenId <= totalTokens && index < tokenCount; tokenId++) {
            if (_ownerOf(tokenId) == owner) {
                tokenIds[index] = tokenId;
                index++;
            }
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Retourne tous les token IDs avec leurs niveaux pour un propriétaire
     * @param owner L'adresse du propriétaire
     * @return tokenIds La liste des token IDs
     * @return levels La liste des niveaux correspondants
     */
    function tokensOfOwnerWithLevels(address owner) external view returns (uint256[] memory tokenIds, uint8[] memory levels) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return (new uint256[](0), new uint8[](0));
        }
        
        tokenIds = new uint256[](tokenCount);
        levels = new uint8[](tokenCount);
        uint256 index = 0;
        uint256 totalTokens = _tokenIdCounter.current() - 1;
        
        for (uint256 tokenId = 1; tokenId <= totalTokens && index < tokenCount; tokenId++) {
            if (_ownerOf(tokenId) == owner) {
                tokenIds[index] = tokenId;
                levels[index] = tokenLevel[tokenId];
                index++;
            }
        }
        
        return (tokenIds, levels);
    }
    
 
    
    /**
     * @dev Support des interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}