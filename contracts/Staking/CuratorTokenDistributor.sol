//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.0;
//
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//
//contract CuratorTokenDistributor is Ownable {
//
//    struct Curator {
//        uint256 percentage; // Percentage share of tokens (e.g., 10% = 1000 -> use basis points, 10000 == 100%)
//        uint256 pendingTokens; // Tokens allocated but not yet claimed
//    }
//
//    struct Project {
//        string name;
//        address[] curatorAddresses; // List of curator addresses for the project
//        mapping(address => Curator) curators; // Mapping from curator address to Curator struct
//    }
//
//    // Project name to Project struct
//    mapping(string => Project) private projects;
//
//    // List of project names
//    string[] public projectNames;
//
//    // Managers (can be set by the owner)
//    mapping(address => bool) public managers;
//
//    // Whitelisted contracts
//    mapping(address => bool) public whitelistedContracts;
//
//    // Events
//    event ManagerAdded(address manager);
//    event ManagerRemoved(address manager);
//    event ProjectCreated(string projectName);
//    event TokensAllocated(string projectName, address token, uint256 amount);
//    event TokensClaimed(string projectName, address curator, address token, uint256 amount);
//    event ContractWhitelisted(address contractAddress);
//    event ContractRemovedFromWhitelist(address contractAddress);
//    event CuratorAdded(string projectName, address curator, uint256 percentage);
//
//    modifier onlyManager() {
//        require(managers[msg.sender] || msg.sender == owner(), "Not authorized");
//        _;
//    }
//
//    modifier projectExists(string memory _projectName) {
//        require(bytes(projects[_projectName].name).length != 0, "Project does not exist");
//        _;
//    }
//
//    modifier onlyWhitelistedContract() {
//        require(whitelistedContracts[msg.sender], "Not whitelisted contract");
//        _;
//    }
//
//    constructor() {
//        // Owner is a manager by default
//        managers[msg.sender] = true;
//    }
//
//    // Owner can add managers
//    function addManager(address _manager) external onlyOwner {
//        managers[_manager] = true;
//        emit ManagerAdded(_manager);
//    }
//
//    // Owner can remove managers
//    function removeManager(address _manager) external onlyOwner {
//        managers[_manager] = false;
//        emit ManagerRemoved(_manager);
//    }
//
//    // Manager can create new projects
//    function createProject(string memory _projectName) external onlyManager {
//        require(bytes(_projectName).length > 0, "Invalid project name");
//        require(bytes(projects[_projectName].name).length == 0, "Project already exists");
//
//        projects[_projectName].name = _projectName;
//        projectNames.push(_projectName);
//
//        emit ProjectCreated(_projectName);
//    }
//
//    // Manager can add curators with a percentage for a project
//    function addCurator(
//        string memory _projectName,
//        address _curator,
//        uint256 _percentage
//    ) external onlyManager projectExists(_projectName) {
//        require(_curator != address(0), "Invalid curator address");
//        require(_percentage > 0 && _percentage <= 10000, "Invalid percentage"); // Max 10000 = 100%
//
//        Project storage project = projects[_projectName];
//        require(project.curators[_curator].percentage == 0, "Curator already added");
//
//        project.curators[_curator].percentage = _percentage;
//        project.curatorAddresses.push(_curator);
//
//        emit CuratorAdded(_projectName, _curator, _percentage);
//    }
//
//    // Owner can whitelist external contracts
//    function whitelistContract(address _contractAddress) external onlyOwner {
//        whitelistedContracts[_contractAddress] = true;
//        emit ContractWhitelisted(_contractAddress);
//    }
//
//    // Owner can remove external contracts from the whitelist
//    function removeWhitelistedContract(address _contractAddress) external onlyOwner {
//        whitelistedContracts[_contractAddress] = false;
//        emit ContractRemovedFromWhitelist(_contractAddress);
//    }
//
//    // Whitelisted external contracts can allocate ERC20 tokens for a specific project
//    function allocateTokensFromExternal(
//        string memory _projectName,
//        address _token,
//        uint256 _amount
//    ) external onlyWhitelistedContract projectExists(_projectName) {
//        require(_amount > 0, "Invalid amount");
//
//        Project storage project = projects[_projectName];
//        require(project.curatorAddresses.length > 0, "No curators for this project");
//
//        // Transfer tokens from the external contract to this contract
//        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
//
//        // Distribute tokens based on curator percentages
//        for (uint256 i = 0; i < project.curatorAddresses.length; i++) {
//            address curatorAddress = project.curatorAddresses[i];
//            Curator storage curator = project.curators[curatorAddress];
//
//            uint256 curatorShare = (_amount * curator.percentage) / 10000;
//            curator.pendingTokens += curatorShare;
//        }
//
//        emit TokensAllocated(_projectName, _token, _amount);
//    }
//
//    // Curator can claim their tokens for a specific project
//    function claimTokens(string memory _projectName, address _token) external projectExists(_projectName) {
//        Project storage project = projects[_projectName];
//        Curator storage curator = project.curators[msg.sender];
//
//        require(curator.percentage > 0, "You are not a curator for this project");
//        uint256 balance = curator.pendingTokens;
//        require(balance > 0, "No tokens to claim");
//
//        // Update curator's balance before transferring
//        curator.pendingTokens = 0;
//
//        // Transfer tokens to curator
//        IERC20(_token).transfer(msg.sender, balance);
//
//        emit TokensClaimed(_projectName, msg.sender, _token, balance);
//    }
//
//    // Curator can view their pending token balance for a specific project
//    function getCuratorPendingTokens(
//        string memory _projectName,
//        address _curator,
//        address _token
//    ) external view projectExists(_projectName) returns (uint256) {
//        return projects[_projectName].curators[_curator].pendingTokens;
//    }
//
//    // Get list of curators for a project
//    function getCuratorsForProject(string memory _projectName) external view projectExists(_projectName) returns (address[] memory) {
//        return projects[_projectName].curatorAddresses;
//    }
//
//    // Get total number of projects
//    function getTotalProjects() external view returns (uint256) {
//        return projectNames.length;
//    }
//}
