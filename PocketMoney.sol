// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PocketMoneyWithDelegation {
    struct Allowance {
        uint256 weeklyLimit;
        uint256 withdrawn;
        uint256 weekStart;
    }
    
    struct Delegation {
        address delegator; // Parent
        address delegate;  // Enfant
        uint256 expiry;
        bool active;
    }
    
    mapping(address => mapping(address => Allowance)) public allowances;
    mapping(address => address) public childToParent;
    
    // Nouveau: Mapping pour les délégations
    // delegationId => Delegation
    mapping(bytes32 => Delegation) public delegations;
    
    // parent => child => delegationId
    mapping(address => mapping(address => bytes32)) public activeDelegations;
    
    event AllowanceSet(address indexed parent, address indexed child, uint256 weeklyLimit);
    event Withdrawal(address indexed child, uint256 amount);
    event Deposit(address indexed parent, uint256 amount);
    event DelegationCreated(bytes32 indexed delegationId, address indexed delegator, address indexed delegate, uint256 expiry);
    event DelegationRevoked(bytes32 indexed delegationId);
    
    function setAllowance(address child, uint256 weeklyLimit) external payable {
        require(msg.value > 0, "Must deposit funds");
        
        allowances[msg.sender][child] = Allowance({
            weeklyLimit: weeklyLimit,
            withdrawn: 0,
            weekStart: block.timestamp
        });
        
        childToParent[child] = msg.sender;
        
        emit AllowanceSet(msg.sender, child, weeklyLimit);
        emit Deposit(msg.sender, msg.value);
    }
    
    // Créer une délégation
    function createDelegation(address child, uint256 expiryTimestamp) external {
        require(childToParent[child] == msg.sender, "Not child's parent");
        require(expiryTimestamp > block.timestamp, "Expiry must be in future");
        
        bytes32 delegationId = keccak256(abi.encodePacked(msg.sender, child, block.timestamp));
        
        delegations[delegationId] = Delegation({
            delegator: msg.sender,
            delegate: child,
            expiry: expiryTimestamp,
            active: true
        });
        
        activeDelegations[msg.sender][child] = delegationId;
        
        emit DelegationCreated(delegationId, msg.sender, child, expiryTimestamp);
    }
    
    // Révoquer une délégation
    function revokeDelegation(address child) external {
        bytes32 delegationId = activeDelegations[msg.sender][child];
        require(delegationId != bytes32(0), "No active delegation");
        require(delegations[delegationId].delegator == msg.sender, "Not delegator");
        
        delegations[delegationId].active = false;
        delete activeDelegations[msg.sender][child];
        
        emit DelegationRevoked(delegationId);
    }
    
    // Vérifier si une délégation est valide
    function isDelegationValid(address parent, address child) public view returns (bool) {
        bytes32 delegationId = activeDelegations[parent][child];
        if (delegationId == bytes32(0)) return false;
        
        Delegation memory delegation = delegations[delegationId];
        return delegation.active && 
               delegation.expiry > block.timestamp &&
               delegation.delegate == child &&
               delegation.delegator == parent;
    }
    
    // Retrait normal (sans délégation)
    function withdraw(uint256 amount) external {
        address parent = childToParent[msg.sender];
        require(parent != address(0), "No parent set for this child");
        
        _executeWithdrawal(parent, msg.sender, amount);
    }
    
    // Retrait avec délégation (l'enfant peut appeler directement)
    function withdrawWithDelegation(address parent, uint256 amount) external {
        require(isDelegationValid(parent, msg.sender), "Invalid or expired delegation");
        
        _executeWithdrawal(parent, msg.sender, amount);
    }
    
    // Fonction interne pour exécuter le retrait
    function _executeWithdrawal(address parent, address child, uint256 amount) internal {
        Allowance storage allowance = allowances[parent][child];
        
        // Reset if new week
        if (block.timestamp >= allowance.weekStart + 1 weeks) {
            allowance.withdrawn = 0;
            allowance.weekStart = block.timestamp;
        }
        
        require(allowance.weeklyLimit > 0, "No allowance set");
        require(allowance.withdrawn + amount <= allowance.weeklyLimit, "Exceeds weekly limit");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        allowance.withdrawn += amount;
        
        payable(child).transfer(amount);
        
        emit Withdrawal(child, amount);
    }
    
    function getMyAvailableAmount() external view returns (uint256) {
        address parent = childToParent[msg.sender];
        if (parent == address(0)) return 0;
        
        Allowance memory allowance = allowances[parent][msg.sender];
        
        if (allowance.weeklyLimit == 0) return 0;
        
        if (block.timestamp >= allowance.weekStart + 1 weeks) {
            return allowance.weeklyLimit;
        }
        
        return allowance.weeklyLimit - allowance.withdrawn;
    }
    
    function getMyParent() external view returns (address) {
        return childToParent[msg.sender];
    }
    
    function getAvailableAmount(address parent, address child) external view returns (uint256) {
        Allowance memory allowance = allowances[parent][child];
        
        if (allowance.weeklyLimit == 0) return 0;
        
        if (block.timestamp >= allowance.weekStart + 1 weeks) {
            return allowance.weeklyLimit;
        }
        
        return allowance.weeklyLimit - allowance.withdrawn;
    }
    
    function getDelegationInfo(address parent, address child) external view returns (
        bool isValid,
        uint256 expiry,
        bool active
    ) {
        bytes32 delegationId = activeDelegations[parent][child];
        if (delegationId == bytes32(0)) {
            return (false, 0, false);
        }
        
        Delegation memory delegation = delegations[delegationId];
        return (
            isDelegationValid(parent, child),
            delegation.expiry,
            delegation.active
        );
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}