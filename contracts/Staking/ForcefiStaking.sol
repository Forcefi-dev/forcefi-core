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
    mapping(address => uint) public currentStakeId;

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
    constructor(
        address _silverNftAddress,
        address _goldNftAddress,
        address _forcefiTokenAddress,
        address _forcefiFundraisingAddress,
        address _endpoint,
        address _delegate
    ) BaseStaking(_forcefiFundraisingAddress, _endpoint, _delegate) {
        silverNftContract = _silverNftAddress;
        goldNftContract = _goldNftAddress;
        forcefiTokenAddress = _forcefiTokenAddress;
    }

    // No logic to implement
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
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
//        require(_stakeAmount == minStakingAmount - totalStaked[msg.sender]
//            || _stakeAmount == curatorTreshholdAmount - totalStaked[msg.sender]
//            || _stakeAmount - totalStaked[msg.sender] == investorTreshholdAmount
//            || _stakeAmount - totalStaked[msg.sender] == curatorTreshholdAmount
//            || _goldNftId != 0, "Invalid stake amount");

        require(
            (_stakeAmount + totalStaked[msg.sender] == minStakingAmount
                || _stakeAmount + totalStaked[msg.sender] == curatorTreshholdAmount
                || _stakeAmount + totalStaked[msg.sender] == investorTreshholdAmount
                || _goldNftId != 0),
            "Invalid stake amount"
        );

        if(_goldNftId == 0) {
            ERC20(forcefiTokenAddress).transferFrom(msg.sender, address(this), _stakeAmount);
        }
        hasStaked[msg.sender] = true;

        if(_stakeAmount + totalStaked[msg.sender] == investorTreshholdAmount ){
            require(isInvestor[msg.sender] == false, "Only one investor stake is available per address");
            isInvestor[msg.sender] = true;
            isCurator[msg.sender] = true;
            _stakeIdCounter += 1;
            uint stakeId = _stakeIdCounter;
            investors.push(stakeId);
            currentStakeId[msg.sender] = stakeId;
            activeStake[stakeId] = ActiveStake(stakeId, msg.sender, _stakeAmount + totalStaked[msg.sender], block.timestamp, _goldNftId);
            emit Staked(msg.sender, _stakeAmount, stakeId);
        }
        else if (_goldNftId != 0 && goldNftOwner[_goldNftId] != address(0)) {
            goldNftOwner[_goldNftId] = msg.sender;
            isInvestor[msg.sender] = true;
            uint stakeId = _stakeIdCounter;
            _stakeIdCounter += 1;
            investors.push(stakeId);
            activeStake[stakeId] = ActiveStake(stakeId, msg.sender, _stakeAmount + totalStaked[msg.sender], block.timestamp, _goldNftId);

            emit Staked(msg.sender, _stakeAmount, stakeId);
        } else if (_stakeAmount + totalStaked[msg.sender] == curatorTreshholdAmount) {
            isCurator[msg.sender] = true;
            emit CuratorAdded(msg.sender);
        }
        totalStaked[msg.sender] += _stakeAmount;
    }

    /// @notice Unstakes a given stake by ID and handles associated logic including penalties and bridging
    /// @param _stakeId The ID of the stake to be unstaked
    function unstake(uint _stakeId, bytes calldata _options) public {
//        require(activeStake[_stakeId].goldNftId == 0, "Can't unstake gold nft");

        bridgeStakingAccess(chainList[msg.sender], _options, _stakeId, true);
        ERC20(forcefiTokenAddress).transfer(msg.sender, totalStaked[msg.sender]);
        //        activeStake[_stakeId].stakeAmount = 0;
        emit Unstaked(msg.sender, _stakeId);
    }

    /// @notice Bridges the staking access to multiple destination chains
    /// @param _destChainIds An array of destination chain IDs to which staking access is bridged
    /// @param _stakeId The ID of the stake being bridged
    /// @param _unstake Boolean indicating if the bridging is for unstaking
    function bridgeStakingAccess(uint16[] memory _destChainIds, bytes calldata _options, uint _stakeId, bool _unstake) public payable {
//        require(activeStake[_stakeId].stakerAddress == msg.sender, "Not an owner of a stake");
        // Check if user eligibility to bridge

        // Get the amount of the stake; if unstake is true, set the amount to 0
        uint stakeAmount = totalStaked[msg.sender];
        if (_unstake) {
            require(hasStaked[msg.sender], "Sender doesn't have active stake");
            stakeAmount = 0;
            isCurator[msg.sender] = false;
            hasStaked[msg.sender] = false;
            currentStakeId[msg.sender] = 0;
            removeInvestor(_stakeId);
        } else {
            // Loop through all destination chain IDs and add them to the user's chain list
            for (uint i = 0; i < _destChainIds.length; i++) {
                addChain(_destChainIds[i]);
            }
        }

        bytes memory payload = abi.encode(msg.sender, stakeAmount, _stakeId);
        executeBridge(_destChainIds, payload, _options);
    }

    /// @notice Executes the bridge operation to multiple destination chains
    /// @param _destChainIds An array of destination chain IDs to bridge to
    /// @param payload The payload data to send to the destination chains
    function executeBridge(uint16[] memory _destChainIds, bytes memory payload, bytes calldata _options) internal {
        for (uint256 i = 0; i < _destChainIds.length; i++) {
            _lzSend(_destChainIds[i], payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
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
