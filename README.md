# DeFi Pulse

A small Ethereum mainnet nest of the events people check every day, kept light enough to load whole
in a browser tab. It is the demo nest for RFC-0065, the nest in a tab.

It indexes, from the first block of 2026 (24,136,053):

| Contract | Events |
|---|---|
| USDC `0xA0b8…eB48` | `Mint`, `Burn` |
| USDT `0xdAC1…1ec7` | `Issue`, `Redeem` |
| Aave v3 Pool `0x8787…A4E2` | `LiquidationCall` |
| Lido stETH `0xae7a…fE84` | `Submitted` |
| Lido WithdrawalQueue `0x889e…9B1` | `WithdrawalRequested`, `WithdrawalsFinalized`, `WithdrawalClaimed` |
| Chainlink ETH/USD aggregator `0x7d4E…6Fb5` | `AnswerUpdated` |

Stablecoin transfers are left out on purpose. Supply created and destroyed is a few thousand events a
day; transfers would be millions, and the nest would stop fitting in a tab.

## Views

- `eth_usd_hourly`: hourly open, high, low and close from Chainlink.
- `stablecoin_supply_events`, `stablecoin_daily_issuance`, `largest_supply_moves_7d`: every USDC
  mint and burn and USDT issue and redeem, net new supply per coin per day, and the largest moves in
  the week up to the newest event.
- `aave_assets`, `aave_liquidations`, `aave_liquidations_daily`: each liquidation with its assets
  named, amounts in token units and dollars, and daily totals.
- `lido_daily_flows`, `lido_withdrawal_queue`: ETH staked, stETH asked back and ETH claimed per day,
  and the requests not yet finalized.

## What it does not price

Dollar values come from the Chainlink ETH/USD close for WETH, and from one dollar for USDC, USDT,
DAI, USDS and GHO. wstETH, weETH, WBTC, cbBTC, USDe and sUSDe need an exchange rate or a feed this
nest does not have, so a liquidation in them shows its token amounts and a NULL dollar value rather
than a guess. `aave_liquidations_daily` counts how many of a day's liquidations were unpriced.

Chainlink's feed changes aggregator when it moves to a new phase. The one listed has been live since
before 2026; a new phase means adding the next aggregator to `nuthatch.toml`.

## Run it

```sh
nuthatch dev --rpc https://your-mainnet-endpoint
nuthatch sql 'SELECT * FROM stablecoin_daily_issuance ORDER BY day DESC LIMIT 7'
```
