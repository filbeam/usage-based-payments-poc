## Usage-Based Payments PoC

This repository provides a **Proof of Concept (PoC)** for a usage-based payments validator designed for FilCDN-related payment rails.
For background and additional details on usage-based payments in FilCDN, please refer to the [FilCDN usage-based payments proposal](https://spacemeridian.notion.site/FilCDN-M3-Usage-based-payments-247cdd5cccdb80018bdce4298eb66d18?source=copy_link).

Because this is only a proof-of-concept, the implementation intentionally omits several features that would be required in a production-ready system, including:

* **No Verifier contract**: Usage data is posted directly to the [Validator](./src/UsageValidator.sol) contract.
* **No dataset/rail mapping**: The Validator contract does not track relationships between datasets and payment rails.
* **Simplified rollup data**: Usage data sent to the Validator is pre-normalized. In production, the contract would receive raw dataset usage and handle mapping to payment rails.
* **Non-upgradeable contracts**: Contracts cannot be upgraded once deployed.
* **No access control**: Authorization and role-based access mechanisms are not implemented.
* **Missing off-chain reporting**: The off-chain component responsible for collecting and submitting usage data has not been implemented.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/UsageValidator.s.sol:UsageValidatorScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
