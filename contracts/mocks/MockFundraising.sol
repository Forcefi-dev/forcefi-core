// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICuratorContract {
    function receiveCuratorFees(address, uint256, bytes32) external;
}

contract MockFundraising {
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

    mapping(bytes32 => FundraisingInstance) private fundraisings;
    mapping(bytes32 => address) public fundraisingOwners;

    address public curatorContract;

    // Creates basic fundraising instance with default values for testing
    function setFundraisingOwner(bytes32 _fundraisingId, address _owner) external {
        FeeConfig memory defaultFeeConfig = FeeConfig({
            tier1Threshold: 1000000,
            tier2Threshold: 2500000,
            tier1FeePercentage: 5,
            tier2FeePercentage: 4,
            tier3FeePercentage: 3,
            reclaimWindow: 0,
            minCampaignThreshold: 70
        });

        fundraisings[_fundraisingId] = FundraisingInstance({
            owner: _owner,
            totalFundraised: 0,
            privateFundraising: false,
            startDate: block.timestamp,
            endDate: block.timestamp + 30 days,
            campaignHardCap: 1000000,
            rate: 1,
            rateDelimiter: 1,
            campaignMinTicketLimit: 100,
            campaignClosed: false,
            mintingErc20TokenAddress: address(0),
            referralAddress: address(0),
            fundraisingReferralFee: 0,
            projectName: "Test Project",
            campaignMaxTicketLimit: 1000000,
            fundraisingFeeConfig: defaultFeeConfig
        });

        fundraisingOwners[_fundraisingId] = _owner;
    }

    function getFundraisingInstance(bytes32 _idx) external view returns (FundraisingInstance memory) {
        return fundraisings[_idx];
    }

    function getFundraisingOwner(bytes32 _fundraisingId) external view returns (address) {
        return fundraisingOwners[_fundraisingId];
    }

    function setCuratorContract(address _curatorContract) external {
        curatorContract = _curatorContract;
    }

    function distributeCuratorFees(
        address _erc20TokenAddress,
        uint256 _amount,
        bytes32 _fundraisingId
    ) external {
        ICuratorContract(curatorContract).receiveCuratorFees(
            _erc20TokenAddress,
            _amount,
            _fundraisingId
        );
    }
}
