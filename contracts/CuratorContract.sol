// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFundraising {
    struct FeeConfig {
        uint256 tier1Threshold;
        uint256 tier2Threshold;
        uint256 tier1FeePercentage;
        uint256 tier2FeePercentage;
        uint256 tier3FeePercentage;
        uint256 reclaimWindow;
        uint256 minCampaignThreshold;
    }

    struct FundraisingInstance {
        address owner;
        uint totalFundraised;
        bool privateFundraising;
        uint startDate;
        uint endDate;
        uint campaignHardCap;
        uint rate;
        uint rateDelimiter;
        uint campaignMinTicketLimit;
        bool campaignClosed;
        address mintingErc20TokenAddress;
        address referralAddress;
        uint fundraisingReferralFee;
        string projectName;
        uint campaignMaxTicketLimit;
        FeeConfig fundraisingFeeConfig;
    }

    function getFundraisingInstance(bytes32 _idx) external view returns (FundraisingInstance memory);
}

/**
 * @title CuratorContract
 * @dev Contract for managing curators for fundraising campaigns
 */
contract CuratorContract is Ownable {
    // Address of the Fundraising contract
    address public fundraisingAddress;

    // Single mapping to store curator data per fundraising campaign
    mapping(bytes32 => CuratorData[]) public fundraisingCurators;

    // Events
    event CuratorAdded(bytes32 indexed fundraisingId, address indexed curator, uint256 percentage);
    event CuratorRemoved(bytes32 indexed fundraisingId, address indexed curator);
    event FundraisingAddressSet(address indexed newAddress);
    event CuratorPercentageAdjusted(bytes32 indexed fundraisingId, address indexed curator, uint256 oldPercentage, uint256 newPercentage);

    // Struct for curator data
    struct CuratorData {
        address curatorAddress;
        uint256 percentage;
    }

    // Maximum total percentage allowed for all curators (100%)
    uint256 public constant MAX_TOTAL_PERCENTAGE = 100;

    // Mapping to track unclaimed fees per curator and token
    mapping(address => mapping(address => uint256)) public unclaimedFees;

    // Events for fee tracking
    event FeesReceived(bytes32 indexed fundraisingId, address indexed erc20Token, uint256 amount);
    event FeesClaimed(address indexed curator, address indexed erc20Token, uint256 amount);
    event FeesDistributed(bytes32 indexed fundraisingId, address indexed curator, uint256 amount);

    /**
     * @dev Initialize the contract with the owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Sets the fundraising contract address
     * @param _fundraisingAddress Address of the fundraising contract
     */
    function setFundraisingAddress(address _fundraisingAddress) external onlyOwner {
        require(_fundraisingAddress != address(0), "Invalid fundraising address");
        fundraisingAddress = _fundraisingAddress;
        emit FundraisingAddressSet(_fundraisingAddress);
    }

    /**
     * @dev Modifier to check if caller is the owner of the fundraising instance
     * @param _fundraisingId The ID of the fundraising campaign
     */
    modifier onlyFundraisingOwner(bytes32 _fundraisingId) {
        require(fundraisingAddress != address(0), "Fundraising address not set");
        IFundraising.FundraisingInstance memory instance = IFundraising(fundraisingAddress).getFundraisingInstance(_fundraisingId);
        require(instance.owner == msg.sender, "Caller is not fundraising owner");
        _; 
    }

    /**
     * @dev Get the current total percentage allocated to curators
     */
    function getCurrentTotalPercentage(bytes32 _fundraisingId) public view returns (uint256) {
        uint256 totalPercentage = 0;
        CuratorData[] memory curators = fundraisingCurators[_fundraisingId];
        
        for (uint i = 0; i < curators.length; i++) {
            totalPercentage += curators[i].percentage;
        }
        
        return totalPercentage;
    }

    /**
     * @dev Get the percentage allocated to a specific curator
     */
    function getCuratorPercentage(bytes32 _fundraisingId, address _curator) external view returns (uint256) {
        CuratorData[] memory curators = fundraisingCurators[_fundraisingId];
        for (uint i = 0; i < curators.length; i++) {
            if (curators[i].curatorAddress == _curator) {
                return curators[i].percentage;
            }
        }
        revert("Curator does not exist");
    }

    /**
     * @dev Check if an address is a curator for a specific fundraising campaign
     */
    function isCurator(bytes32 _fundraisingId, address _curator) external view returns (bool) {
        CuratorData[] memory curators = fundraisingCurators[_fundraisingId];
        for (uint i = 0; i < curators.length; i++) {
            if (curators[i].curatorAddress == _curator) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Add multiple curators with their percentages
     */
    function addCurators(bytes32 _fundraisingId, CuratorData[] calldata _curatorsData) external onlyFundraisingOwner(_fundraisingId) {
        uint256 totalPercentage = getCurrentTotalPercentage(_fundraisingId);
        
        for (uint i = 0; i < _curatorsData.length; i++) {
            require(_curatorsData[i].curatorAddress != address(0), "Invalid curator address");
            require(!this.isCurator(_fundraisingId, _curatorsData[i].curatorAddress), "Curator already exists");
            require(_curatorsData[i].percentage > 0, "Percentage must be greater than 0");
            
            totalPercentage += _curatorsData[i].percentage;
            require(totalPercentage <= MAX_TOTAL_PERCENTAGE, "Total percentage exceeds 100%");
            
            fundraisingCurators[_fundraisingId].push(_curatorsData[i]);
            
            emit CuratorAdded(_fundraisingId, _curatorsData[i].curatorAddress, _curatorsData[i].percentage);
        }
    }    /**
     * @dev Remove curators from a specific fundraising campaign
     */
    function removeCurators(bytes32 _fundraisingId, address[] calldata _curatorsToRemove) external onlyFundraisingOwner(_fundraisingId) {
        CuratorData[] storage curators = fundraisingCurators[_fundraisingId];
        
        for (uint i = 0; i < _curatorsToRemove.length; i++) {
            require(_curatorsToRemove[i] != address(0), "Cannot remove zero address curator");
            bool found = false;
            for (uint j = 0; j < curators.length; j++) {
                if (curators[j].curatorAddress == _curatorsToRemove[i]) {
                    found = true;
                    // Move the last element to this position and pop
                    if (j != curators.length - 1) {
                        curators[j] = curators[curators.length - 1];
                    }
                    curators.pop();
                    emit CuratorRemoved(_fundraisingId, _curatorsToRemove[i]);
                    break;
                }
            }
            require(found, "Curator does not exist");
        }
    }    /**
     * @dev Adjust curator percentage
     */
    function adjustCuratorPercentage(
        bytes32 _fundraisingId, 
        address _curator, 
        uint256 _newPercentage
    ) external onlyFundraisingOwner(_fundraisingId) {
        require(_curator != address(0), "Curator address cannot be zero");
        require(_newPercentage > 0, "Percentage must be greater than 0");
        
        CuratorData[] storage curators = fundraisingCurators[_fundraisingId];
        bool found = false;
        uint256 oldPercentage;
        
        for (uint i = 0; i < curators.length; i++) {
            if (curators[i].curatorAddress == _curator) {
                oldPercentage = curators[i].percentage;
                uint256 newTotal = getCurrentTotalPercentage(_fundraisingId) - oldPercentage + _newPercentage;
                require(newTotal <= MAX_TOTAL_PERCENTAGE, "Total percentage would exceed 100%");
                
                curators[i].percentage = _newPercentage;
                found = true;
                emit CuratorPercentageAdjusted(_fundraisingId, _curator, oldPercentage, _newPercentage);
                break;
            }
        }
        require(found, "Curator does not exist");
    }

    /**
     * @dev Receives and distributes fees among curators
     * @param erc20TokenAddress The address of the ERC20 token
     * @param amount The amount of fees to distribute
     * @param fundraisingIdx The ID of the fundraising campaign
     */
    function receiveCuratorFees(
        address erc20TokenAddress, 
        uint256 amount, 
        bytes32 fundraisingIdx
    ) external {
        require(msg.sender == fundraisingAddress, "Only fundraising contract can distribute fees");
        require(amount > 0, "Amount must be greater than 0");

        CuratorData[] memory curators = fundraisingCurators[fundraisingIdx];
        require(curators.length > 0, "No curators to distribute fees to");

        emit FeesReceived(fundraisingIdx, erc20TokenAddress, amount);

        for (uint i = 0; i < curators.length; i++) {
            uint256 curatorShare = (amount * curators[i].percentage) / MAX_TOTAL_PERCENTAGE;
            if (curatorShare > 0) {
                unclaimedFees[curators[i].curatorAddress][erc20TokenAddress] += curatorShare;
                emit FeesDistributed(fundraisingIdx, curators[i].curatorAddress, curatorShare);
            }
        }
    }

    /**
     * @dev Receives and distributes native currency (ETH) fees to curators for a specific fundraising campaign
     * @param fundraisingIdx The ID of the fundraising campaign
     */
    function receiveNativeCurrencyFees(bytes32 fundraisingIdx) external payable {
        require(msg.sender == fundraisingAddress, "Only fundraising contract can distribute fees");
        require(msg.value > 0, "Amount must be greater than 0");

        CuratorData[] memory curators = fundraisingCurators[fundraisingIdx];
        require(curators.length > 0, "No curators to distribute fees to");

        // Use address(0) to represent native currency
        address nativeCurrency = address(0);
        emit FeesReceived(fundraisingIdx, nativeCurrency, msg.value);

        for (uint i = 0; i < curators.length; i++) {
            uint256 curatorShare = (msg.value * curators[i].percentage) / MAX_TOTAL_PERCENTAGE;
            if (curatorShare > 0) {
                unclaimedFees[curators[i].curatorAddress][nativeCurrency] += curatorShare;
                emit FeesDistributed(fundraisingIdx, curators[i].curatorAddress, curatorShare);
            }
        }
    }    /**
     * @dev Allows curators to claim their accumulated fees
     * @param erc20TokenAddress The address of the ERC20 token to claim (use address(0) for native currency)
     */
    function claimCuratorFees(address erc20TokenAddress) external {
        uint256 amount = unclaimedFees[msg.sender][erc20TokenAddress];
        require(amount > 0, "No fees to claim");

        unclaimedFees[msg.sender][erc20TokenAddress] = 0;
        
        if (erc20TokenAddress == address(0)) {
            // Handle native currency (ETH)
            payable(msg.sender).transfer(amount);
        } else {
            // Handle ERC20 tokens
            require(
                IERC20(erc20TokenAddress).transfer(msg.sender, amount),
                "Fee transfer failed"
            );
        }
        
        emit FeesClaimed(msg.sender, erc20TokenAddress, amount);
    }

    /**
     * @dev View function to check unclaimed fees for a curator
     * @param curator The address of the curator
     * @param erc20TokenAddress The address of the ERC20 token
     * @return uint256 The amount of unclaimed fees
     */
    function getUnclaimedFees(
        address curator, 
        address erc20TokenAddress
    ) external view returns (uint256) {
        return unclaimedFees[curator][erc20TokenAddress];
    }
}
