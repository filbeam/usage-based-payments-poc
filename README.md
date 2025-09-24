## Usage-Based Payments PoC

Usage-based payments using one-time payments based on the [implementation plan](./IMPL.md). Unlike the initial [usage-based payments proposal](https://spacemeridian.notion.site/FilCDN-M3-Usage-based-payments-247cdd5cccdb80018bdce4298eb66d18?source=copy_link) this version does not involve validators in the settlement process. Instead, the FilBeam contract calculates settlement amounts based on usage data reported by off-chain workers and directly calls the FWSS contract to execute fund transfers to payment rail beneficiaries.

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
