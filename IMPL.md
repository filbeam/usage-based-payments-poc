# FilBeam Usage-Based Payments Implementation Plan

## Summary

This implementation plan outlines the strategy for implementing usage-based payments for FilBeam based on feedback gathered during discussions in Dubai. The new approach introduces architectural changes from the original design, moving from validator-calculated settlements to direct one-time payment settlements.

### Key Changes from Original Design

- **Settlement Method**: We should use multiple one-time payments to settle payment rails instead of standard settlement flows
- **Calculation Logic**: FilBeam contract calculates settlement amounts from rollup worker usage data and calls FWSS for fund transfers
- **Fund Transfer**: FWSS contract handles fund transfers to payment rail beneficiaries without validator involvement

## Architecture Overview

The system consists of three main components:
1. **FilBeam (Operator) Contract** - Handles usage reporting and settlement calculations
2. **FWSS Contract** - Manages payment rails and fund transfers
3. **Off-chain Workers** - Reports usage data to the FilBeam contract and triggers settlements

---

## Smart Contract Implementation

### FilBeam (Operator) Contract

#### Usage Reporting
**Method**: `reportUsageRollup(uint256 dataSetId, uint256 epoch, int256 cdnBytesUsed, int256 cacheMissBytesUsed)`

- **Access**: Contract owner only
- **Purpose**: Accepts periodic usage reports from the rollup worker
- **Epoch Assignment**: Contract assigns current block number as rollup epoch
- **Data Retention**: Rollup worker can batch data for multiple epochs

#### Payment Rail Settlement
**Method**: `settleCDNPaymentRails(uint256 dataSetId)`

- **Access**: Publicly callable (can be triggered by anyone)
- **Calculation Period**: From last settlement epoch to previous epoch (current epoch - 1)
- **Settlement Logic**: 
  - Calculate total usage-based settlement amount from accumulated usage data
  - Call FWSS contract to execute fund transfers for both rails
  - FWSS contract recieves cache-hit (CDN) and cache-miss amounts as parameters and processes payments accordingly
- **State Updates**: Update last settlement epoch for the dataset

#### Payment Rail Termination
**Method**: `terminateCDNPaymentRails(uint256 dataSetId)`

- **Access**: Contract owner only
- **Process**: Forward termination call to FWSS contract

### FWSS Contract Modifications

#### Configuration Changes
- **Controller Address**: Update `filBeamControllerAddress` (rename from `filCdnControllerAddress`) to point to FilBeam (Operator) contract
- **Access Control**: Restrict settlement methods to FilBeam contract calls only
- **Beneficiary Addresss**: Rename from `filCdnControllerAddress` to `filBeamControllerAddress`

#### Settlement Interface
**Method**: `settleCDNPaymentRails(uint256 dataSetId, uint256 cdnAmount, uint256 cacheMissAmount)`

- **Access**: Only callable by FilBeam (Operator) contract
- **Parameters**: Exact settlement amounts calculated by FilBeam contract
- **Execution**: Transfer specified amounts to respective payment rail beneficiaries

#### Payment Rail Creation
Enhanced rail creation process with proper initialization:

```solidity
// Cache Miss Rail (20% allocation)
cacheMissRailId = payments.createRail(
    usdfcTokenAddress,        // token address
    createData.payer,         // payer address
    payeeFromRegistry,        // payee from registry
    address(0),               // no validator
    0,                        // no service commission
    address(this)             // controller
);

// Set lockup to 20% of monthly usage estimate
payments.modifyRailLockup(
    cacheMissRailId, 
    DEFAULT_LOCKUP_PERIOD, 
    CDN_PRICE_PER_TIB * 0.2
);

// CDN Rail (80% allocation)
cdnRailId = payments.createRail(
    usdfcTokenAddress,        // token address
    createData.payer,         // payer address
    filBeamBeneficiary,       // FilBeam beneficiary
    address(0),               // no validator
    0,                        // no service commission
    address(this)             // controller
);

// Set lockup to 80% of monthly usage estimate
payments.modifyRailLockup(
    cdnRailId, 
    DEFAULT_LOCKUP_PERIOD, 
    CDN_PRICE_PER_TIB * 0.8
);
```

#### Top-up Functionality
**Method**: `topUpCDNPaymentRails(uint256 dataSetId, uint256 cdnAmount, uint256 cacheMissAmount)`

- **Purpose**: Allow users to add funds to their CDN-related payment rails
- **Implementation**: Call `modifyRailLockup` for both rails with fixed lockup incremented by passed amounts (`cdnAmount` and `cacheMissAmount`)

---

## Off-Chain Worker Implementation

### Rollup Worker

#### Responsibilities
- **Data Aggregation**: Sum usage data by dataset and type (CDN, cache miss)
- **Periodic Reporting**: Periodically submit usage reports to FilBeam (Operator) contract
- **State Tracking**: Maintain record of last reported retrieval log per dataset

#### Implementation Details
- **Query Logic**: Select retrieval logs grouped by data set ID from last reported log to current maximum
- **Filtering**: Skip datasets with zero usage to lower gas fees for contract calls
- **Error Handling**: Retry failed submissions with exponential backoff

#### Database Schema Changes
```sql
-- Track reporting state per dataset
ALTER TABLE data_sets ADD COLUMN last_reported_retrieval_log_id BIGINT;
CREATE INDEX idx_data_sets_last_reported ON data_sets(last_reported_retrieval_log_id);
```

### Settlement Worker

#### Responsibilities
- **Regular Settlement**: Periodically call `settleCDNPaymentRails` for active data sets
- **Termination Settlement**: Periodically call `settleCDNPaymentRails` for active data sets where `with_cdn` is `false` and `cdn_service_terminated_at` is lower than lockup period duration (`DEFAULT_LOCKUP_PERIOD` is equal to 10 days)

#### Implementation Strategy
- **Active Dataset Query**: Get a list of active data sets and send settlement requests
- **Gas Optimization**: Batch multiple settlements when possible (out of scope for this implementation phase)

### Future enhancements
- **Track Settlement Epochs**: Maintain last settlement epoch per dataset to avoid redundant calculations
- **Error Handling**: Implement retry logic for failed settlement calls
- **Terminated Data Set Settlements**: Ensure settlements for terminated data sets are done before 

### Indexer Worker Updates

#### Lockup Monitoring
- **Event Watching**: Monitor lockup deposit events from FWSS contract
- **Egress Credit**: Convert deposit amounts to byte allowances for datasets

### Service Termination
- **Termination Process**: On service termination set data set status to `with_cdn` to `false` and `cdn_service_terminated_at` to current timestamp

#### Database Schema Changes
```sql
-- Track CDN service termination
ALTER TABLE data_sets ADD COLUMN cdn_service_terminated_at TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_data_sets_cdn_terminated ON data_sets(with_cdn, cdn_service_terminated_at);
```

### Retrieval Worker Enhancements

#### Pre-retrieval Checks
- **Egress Validation**: Verify sufficient egress quota before processing retrieval
- **Error Responses**: Return clear error messages when quota exceeded


Let me know what you think @juliangruber @bajtos 
