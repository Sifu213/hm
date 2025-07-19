// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MonadTogetherNFT
 * @dev Contrat NFT simple pour les victoires dans Monad Together
 * - Mint gratuit
 * - Pas de limite de nombre
 * - Un wallet peut minter plusieurs fois
 * - Image IPFS fixe pour tous les NFTs
 */
contract MonadTogetherNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    // Compteur pour les token IDs
    Counters.Counter private _tokenIdCounter;
    
    // URI de l'image IPFS (même pour tous les NFTs)
    string private _baseTokenURI;
    
    // Events
    event VictoryNFTMinted(address indexed to, uint256 indexed tokenId, uint256 timestamp);
    
    /**
     * @dev Constructeur
     * @param baseTokenURI_ L'URI IPFS de base pour les métadonnées
     */
    constructor(string memory baseTokenURI_) ERC721("Monad Together NFT", "MTNFT") Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI_;
        // Commencer les IDs à 1 au lieu de 0
        _tokenIdCounter.increment();
    }
    
    /**
     * @dev Mint un NFT de victoire (gratuit)
     * @param to L'adresse qui recevra le NFT
     * @return tokenId L'ID du token minté
     */
    function mintVictoryNFT(address to) public returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        
        emit VictoryNFTMinted(to, tokenId, block.timestamp);
        
        return tokenId;
    }
    
    /**
     * @dev Mint un NFT pour soi-même (fonction de convenance)
     * @return tokenId L'ID du token minté
     */
    function mintMyVictoryNFT() external returns (uint256) {
        return mintVictoryNFT(msg.sender);
    }
    
    /**
     * @dev Retourne l'URI des métadonnées pour un token
     * Comme tous les NFTs ont la même image, on retourne toujours la même URI
     */
    function tokenURI(uint256) public view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Met à jour l'URI de base (seulement le owner)
     * @param newBaseTokenURI Le nouvel URI de base
     */
    function setBaseTokenURI(string memory newBaseTokenURI) external onlyOwner {
        _baseTokenURI = newBaseTokenURI;
    }
    
    /**
     * @dev Retourne l'URI de base actuel
     * @return L'URI de base
     */
    function getBaseTokenURI() external view returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Retourne le nombre total de NFTs mintés
     * @return Le nombre total de tokens
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
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
            if (ownerOf(tokenId) == owner) {
                tokenIds[index] = tokenId;
                index++;
            }
        }
        
        return tokenIds;
    }
    
    
    /**
     * @dev Support des interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}