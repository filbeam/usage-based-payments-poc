// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFilecoinWarmStorageService {
    function settleCDNPaymentRail(uint256 dataSetId, uint256 cdnAmount) external;
    function settleCacheMissPaymentRail(uint256 dataSetId, uint256 cacheMissAmount) external;
    function terminateCDNPaymentRails(uint256 dataSetId) external;
}

contract FilBeamOperator {
    event CDNPaymentSettled(uint256 indexed dataSetId, uint256 toEpoch, uint256 cdnAmount);
    event CacheMissPaymentSettled(uint256 indexed dataSetId, uint256 toEpoch, uint256 cacheMissAmount);

    uint256 private constant TIB_IN_BYTES = 1024 ** 4; // 1 TiB in bytes
    uint256 public constant RATE_PER_TIB = 10e6; // $10, scaled to 6 decimals

    // Constant rate for all rails
    uint256 public constant RATE_PER_BYTE = RATE_PER_TIB / TIB_IN_BYTES;

    mapping(uint256 => mapping(uint256 => uint256)) public cdnUsageByDataSetAndEpoch;
    mapping(uint256 => mapping(uint256 => uint256)) public cacheMissUsageByDataSetAndEpoch;
    // lastSettledEpoch[railId] = last epoch settled
    mapping(uint256 => uint256) public lastSettledEpoch;

    address public owner;
    address public fwssAddress;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor(address _fwssAddress) {
        owner = msg.sender;
        fwssAddress = _fwssAddress;
    }

    // Rollup usage for multiple rails, assigns current epoch
    function reportRollupUsage(
        uint256[] calldata dataSetIds,
        uint256[] calldata cdnUsages,
        uint256[] calldata cacheMissUsages
    ) external onlyOwner {
        uint256 epoch = block.number - 1;
        for (uint256 i = 0; i < dataSetIds.length; i++) {
            cdnUsageByDataSetAndEpoch[dataSetIds[i]][epoch] += cdnUsages[i];
            cacheMissUsageByDataSetAndEpoch[dataSetIds[i]][epoch] += cacheMissUsages[i];
        }
    }

    function settleCDNPaymentRail(uint256 dataSetId) public {
        bool foundData = false;
        uint256 cdnSum = 0;
        uint256 lastEpochWithData = 0;

        uint256 fromEpoch = lastSettledEpoch[dataSetId] + 1;
        uint256 toEpoch = block.number - 1;

        for (uint256 epoch = fromEpoch; epoch <= toEpoch; epoch++) {
            uint256 cdnUsage = cdnUsageByDataSetAndEpoch[dataSetId][epoch];
            if (cdnUsage > 0) {
                cdnSum += cdnUsage * RATE_PER_BYTE;
                lastEpochWithData = epoch;
                foundData = true;
            }
        }

        if (foundData) {
            lastSettledEpoch[dataSetId] = lastEpochWithData;
            IFilecoinWarmStorageService(fwssAddress).settleCDNPaymentRail(dataSetId, cdnSum);

            emit CDNPaymentSettled(dataSetId, lastEpochWithData, cdnSum);
        }
    }

    function settleCacheMissPaymentRail(uint256 dataSetId) public {
        bool foundData = false;
        uint256 cacheMissSum = 0;
        uint256 lastEpochWithData = 0;

        uint256 fromEpoch = lastSettledEpoch[dataSetId] + 1;
        uint256 toEpoch = block.number - 1;

        for (uint256 epoch = fromEpoch; epoch <= toEpoch; epoch++) {
            uint256 cacheMissUsage = cacheMissUsageByDataSetAndEpoch[dataSetId][epoch];
            if (cacheMissUsage > 0) {
                cacheMissSum += cacheMissUsage * RATE_PER_BYTE;
                lastEpochWithData = epoch;
                foundData = true;
            }
        }

        if (foundData) {
            lastSettledEpoch[dataSetId] = lastEpochWithData;
            IFilecoinWarmStorageService(fwssAddress).settleCacheMissPaymentRail(dataSetId, cacheMissSum);

            emit CacheMissPaymentSettled(dataSetId, lastEpochWithData, cacheMissSum);
        }
    }

    function terminateCDNPaymentRails(uint256 dataSetId) external onlyOwner {
        IFilecoinWarmStorageService(fwssAddress).terminateCDNPaymentRails(dataSetId);
    }
}
