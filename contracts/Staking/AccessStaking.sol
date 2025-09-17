// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for an ERC20 token with a burn function
interface IERC20Burnable {
    function burn(uint256 amount) external;
}

contract AccessStaking is BaseStaking {

    using SafeERC20 for IERC20;

    IERC20 public immutable forcefiTokenAddress;  // ERC20 token used for staking

    mapping(uint => address) public silverNftOwner;
    mapping(uint => address) public goldNftOwner;
    mapping(address => bool) public isCurator;
    mapping(address => uint) public currentStakeId;

    uint public minStakingAmount;
    uint public curatorTreshholdAmount;

    mapping(address => uint16[]) public chainList;

    // Event to emit when a new chain is added to a user's list
    event ChainAdded(address indexed user, uint16 chainId);

    /// @notice Constructor initializes the ForcefiStaking contract with necessary addresses
    /// @param _forcefiTokenAddress The address of the FORCEFI token contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    constructor(
        address _forcefiTokenAddress,
        address _forcefiFundraisingAddress,
        address _endpoint,
        address _delegate
    ) BaseStaking(_forcefiFundraisingAddress, _endpoint, _delegate) {
        forcefiTokenAddress = IERC20(_forcefiTokenAddress);
    }

    // No logic to implement
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address _stakerAddress, uint _silverNftId, uint _goldNftId) = abi.decode(payload, (address, uint, uint));
        if(_silverNftId != 0){
            silverNftOwner[_silverNftId] = msg.sender;
            hasStaked[_stakerAddress] = true;
            uint stakeId = _stakeIdCounter;
            _stakeIdCounter += 1;
            activeStake[_stakerAddress] = ActiveStake(stakeId, investorTreshholdAmount, block.timestamp, _silverNftId, _goldNftId);
        } else if(_goldNftId != 0){
            goldNftOwner[_goldNftId] = _stakerAddress;
            uint stakeId = _stakeIdCounter;
            _stakeIdCounter += 1;
            investors.push(_stakerAddress);
            activeStake[_stakerAddress] = ActiveStake(stakeId, investorTreshholdAmount, block.timestamp, _silverNftId, _goldNftId);
            emit Staked(_stakerAddress, investorTreshholdAmount, stakeId);
        }
    }

    /// @notice Sets the minimum staking amount required for staking
    /// @param _stakingAmount The minimum amount of tokens required for staking
    function setMinStakingAmount(uint _stakingAmount) external onlyOwner {
        minStakingAmount = _stakingAmount;
    }

    /// @notice Sets the threshold amount required for a user to become a curator
    /// @param _curatorTreshholdAmount The amount of tokens required to become a curator
    function setCuratorTreshholdAmount(uint _curatorTreshholdAmount) external onlyOwner {
        curatorTreshholdAmount = _curatorTreshholdAmount;
    }

    /// @notice Stakes a given amount of tokens and associates an optional gold NFT
    /// @param _stakeAmount The amount of tokens to stake
    function stake(uint _stakeAmount, address _stakerAddress) public {
        require(_stakeAmount > 0, "Stake amount must be greater than zero");

        ActiveStake storage userStake = activeStake[_stakerAddress]; // Renamed variable
        uint newTotalStake = _stakeAmount + userStake.stakeAmount;

        require(
            (newTotalStake == minStakingAmount ||
        newTotalStake == curatorTreshholdAmount ||
        newTotalStake == investorTreshholdAmount),
            "Invalid stake amount"
        );

        // Transfer tokens from the staker to the contract
        forcefiTokenAddress.safeTransferFrom(_stakerAddress, address(this), _stakeAmount);

        hasStaked[_stakerAddress] = true;

        uint stakeId = _stakeIdCounter;

        if (newTotalStake == investorTreshholdAmount) {
            isCurator[_stakerAddress] = true;
            _stakeIdCounter += 1;
            investors.push(_stakerAddress);
            currentStakeId[_stakerAddress] = stakeId;
            activeStake[_stakerAddress] = ActiveStake(stakeId, newTotalStake, block.timestamp, 0, 0);
        }
        else if (newTotalStake == curatorTreshholdAmount) {
            isCurator[_stakerAddress] = true;
            emit CuratorAdded(_stakerAddress);
        }
        emit Staked(_stakerAddress, _stakeAmount, stakeId);
    }
    
    /// @notice Bridges the staking access to a destination chain
    /// @param _destChainId The destination chain ID to which staking access is bridged
    /// @param _unstake Boolean indicating if the bridging is for unstaking
    function bridgeStakingAccess(uint16 _destChainId, bytes calldata _options, bool _unstake) public payable {
        ActiveStake storage activeStake = activeStake[msg.sender];

        bytes memory payload = abi.encode(msg.sender, activeStake.stakeAmount, activeStake.stakeId);

        if (_unstake) {
            require(hasStaked[msg.sender], "Sender doesn't have active stake");
            if(activeStake.silverNftId != 0){
                silverNftOwner[activeStake.silverNftId] = address(0);
            }
            if(activeStake.goldNftId != 0){
                goldNftOwner[activeStake.goldNftId] = address(0);
            }            activeStake.stakeAmount = 0;
            isCurator[msg.sender] = false;
            hasStaked[msg.sender] = false;
            currentStakeId[msg.sender] = 0;
            removeInvestor(msg.sender);
            forcefiTokenAddress.safeTransfer(msg.sender, activeStake.stakeAmount);
            emit Unstaked(msg.sender, activeStake.stakeId);
            // Bridge unstake to all chains in user's chain list
            uint16[] memory userChains = chainList[msg.sender];
            for (uint256 i = 0; i < userChains.length; i++) {
                executeBridge(userChains[i], payload, _options);
            }
        } else {
            // Add the destination chain ID to the user's chain list and execute bridge
            addChain(_destChainId);
            executeBridge(_destChainId, payload, _options);
        }
    }
    
    /// @notice Executes the bridge operation to a destination chain
    /// @param _destChainId The destination chain ID to bridge to
    /// @param payload The payload data to send to the destination chain
    function executeBridge(uint16 _destChainId, bytes memory payload, bytes calldata _options) internal {
        _lzSend(_destChainId, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /// @notice Adds a new chain ID to a user's list of chains
    /// @param _chainId The ID of the chain to be added
    function addChain(uint16 _chainId) private {
        require(!chainExists(msg.sender, _chainId), "Chain ID already added for this address");
        chainList[msg.sender].push(_chainId);
        emit ChainAdded(msg.sender, _chainId);
    }

    /// @notice Checks if a chain ID already exists in a user's list of chains
    /// @param _user The address of the user whose chain list is being checked
    /// @param _chainId The ID of the chain to check for existence
    /// @return bool True if the chain ID exists in the user's list, false otherwise
    function chainExists(address _user, uint16 _chainId) internal view returns (bool) {
        uint16[] memory chains = chainList[_user];
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == _chainId) {
                return true;
            }
        }
        return false;
    }

    /// @notice Retrieves the list of chain IDs associated with a specific address
    /// @param _user The address of the user whose chain list is being retrieved
    /// @return uint16[] An array of chain IDs associated with the user's address
    function getChainList(address _user) public view returns (uint16[] memory) {
        return chainList[_user];
    }
}
