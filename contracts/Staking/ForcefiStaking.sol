// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";

// Interface for an ERC20 token with a burn function
interface IERC20Burnable {
    function burn(uint256 amount) external;
}

contract ForcefiStaking is BaseStaking {

    address public forcefiTokenAddress;

    mapping(uint => address) public silverNftOwner;
    mapping(uint => address) public goldNftOwner;
    mapping(address => bool) public isCurator;

    uint public minStakingAmount;
    uint public curatorTreshholdAmount;

    address public silverNftContract;
    address public goldNftContract;

    mapping(address => uint16[]) public chainList;

    // Event to emit when a new chain is added to a user's list
    event ChainAdded(address indexed user, uint16 chainId);

    /// @notice Constructor initializes the ForcefiStaking contract with necessary addresses
    /// @param _silverNftAddress The address of the silver NFT contract
    /// @param _goldNftAddress The address of the gold NFT contract
    /// @param _forcefiTokenAddress The address of the FORCEFI token contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    /// @param _lzContractAddress The LayerZero contract address used for cross-chain communication
    constructor(
        address _silverNftAddress,
        address _goldNftAddress,
        address _forcefiTokenAddress,
        address _forcefiFundraisingAddress,
        address _lzContractAddress
    ) BaseStaking(_forcefiFundraisingAddress, _lzContractAddress) {
        silverNftContract = _silverNftAddress;
        goldNftContract = _goldNftAddress;
        forcefiTokenAddress = _forcefiTokenAddress;
    }

    /// @notice Handles incoming messages from LayerZero (not implemented in this contract)
    /// @param _srcChainId The source chain ID from which the message originated
    /// @param _srcAddress The source address from which the message was sent
    /// @param _nonce The unique nonce of the message
    /// @param _payload The payload containing the staking or unstaking details
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        // No logic to implement
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
    /// @param _goldNftId The ID of the gold NFT associated with the stake (0 if not applicable)
    function stake(uint _stakeAmount, uint _goldNftId) public {
        require(_stakeAmount >= minStakingAmount || _goldNftId != 0, "Not enough tokens to stake");
        if (_goldNftId != 0 && goldNftOwner[_goldNftId] == address(0)) {
            goldNftOwner[_goldNftId] = msg.sender;
            _setStaker(investorTreshholdAmount, msg.sender, _goldNftId);
        } else {
            ERC20(forcefiTokenAddress).transferFrom(msg.sender, address(this), _stakeAmount);
            _setStaker(_stakeAmount, msg.sender, _goldNftId);
        }
    }

    /// @notice Sets a staker with the given stake amount, address, and optional gold NFT
    /// @param _stakeAmount The amount of tokens staked
    /// @param _stakerAddress The address of the user who staked
    /// @param _goldNftId The ID of the gold NFT associated with the stake (0 if not applicable)
    function _setStaker(uint _stakeAmount, address _stakerAddress, uint _goldNftId) private {
        uint stakeId = _stakeIdCounter;
        _stakeIdCounter += 1;
        activeStake[stakeId] = ActiveStake(stakeId, _stakerAddress, _stakeAmount, block.timestamp, _goldNftId);
        userStakes[msg.sender].push(stakeId);
        if (_stakeAmount >= curatorTreshholdAmount) {
            isCurator[msg.sender] = true;
        }
        if (_stakeAmount >= investorTreshholdAmount) {
            investors.push(stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, stakeId);
    }

    /// @notice Unstakes a given stake by ID and handles associated logic including penalties and bridging
    /// @param _stakeId The ID of the stake to be unstaked
    /// @param gasForDestinationLzReceive The gas amount provided for the LayerZero receive function on the destination chain
    function unstake(uint _stakeId, uint gasForDestinationLzReceive) public {
        require(activeStake[_stakeId].goldNftId == 0, "Can't unstake gold nft");
        uint stakeAmount = activeStake[_stakeId].stakeAmount;

        // If unstake event happens before stake becomes eligible to receive fees, then investor gets penalty
        if (activeStake[_stakeId].stakeEventTimestamp + feeMultiplier.eligibleToReceiveFee > block.timestamp) {
            // Calculate the amount of tokens to burn based on earlyUnstakePercent
            uint256 burnAmount = stakeAmount * feeMultiplier.earlyUnstakePercent / 100;

            // Adjust the stake amount after applying the early unstake penalty
            stakeAmount = stakeAmount - burnAmount;

            // Burn the calculated amount of tokens
            IERC20Burnable(forcefiTokenAddress).burn(burnAmount);
        }

        ERC20(forcefiTokenAddress).transfer(msg.sender, stakeAmount);
        isCurator[msg.sender] = false;
        removeInvestor(_stakeId);
        bridgeStakingAccess(chainList[msg.sender], gasForDestinationLzReceive, _stakeId, true);
        activeStake[_stakeId].stakeAmount = 0;
        removeStakeFromUser(msg.sender, _stakeId);
        emit Unstaked(msg.sender, _stakeId);
    }

    /// @notice Bridges the staking access to multiple destination chains
    /// @param _destChainIds An array of destination chain IDs to which staking access is bridged
    /// @param gasForDestinationLzReceive The gas amount provided for the LayerZero receive function on the destination chains
    /// @param _stakeId The ID of the stake being bridged
    /// @param _unstake Boolean indicating if the bridging is for unstaking
    function bridgeStakingAccess(uint16[] memory _destChainIds, uint gasForDestinationLzReceive, uint _stakeId, bool _unstake) public payable {
        require(activeStake[_stakeId].stakerAddress == msg.sender, "Not an owner of a stake");
        // Check if user eligibility to bridge
        require(hasStaked(msg.sender), "Sender doesn't have active stake");

        // Get the amount of the stake; if unstake is true, set the amount to 0
        uint stakeAmount = activeStake[_stakeId].stakeAmount;
        if (_unstake) {
            stakeAmount = 0;
        } else {
            // Loop through all destination chain IDs and add them to the user's chain list
            for (uint i = 0; i < _destChainIds.length; i++) {
                addChain(_destChainIds[i]);
            }
        }

        bytes memory payload = abi.encode(msg.sender, stakeAmount, _stakeId);
        executeBridge(_destChainIds, payload, gasForDestinationLzReceive);
    }

    /// @notice Executes the bridge operation to multiple destination chains
    /// @param _destChainIds An array of destination chain IDs to bridge to
    /// @param payload The payload data to send to the destination chains
    /// @param gasForDestinationLzReceive The gas amount provided for the LayerZero receive function on the destination chains
    function executeBridge(uint16[] memory _destChainIds, bytes memory payload, uint gasForDestinationLzReceive) internal {
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
        for (uint256 i = 0; i < _destChainIds.length; i++) {
            _lzSend(_destChainIds[i], payload, payable(tx.origin), address(0x0), adapterParams);
        }
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

    // TODO: add nftContract checks
    //    // Function to check if a user has active stakes
    //    function hasStaked(address _stakerAddress) public view returns (bool) {
    //        uint[] memory stakes = userStakes[_stakerAddress];
    //
    //        for (uint i = 0; i < stakes.length; i++) {
    //            uint stakeId = stakes[i];
    //            if (activeStake[stakeId].stakeAmount > 0) {
    //                return true;
    //            }
    //        }
    //        return false;
    ////        return activeStake[msg.sender].stakeAmount >= minStakingAmount || IERC20(silverNftContract).balanceOf(msg.sender) >= 1 || IERC20(goldNftContract).balanceOf(msg.sender) >= 1;
    //    }
}
