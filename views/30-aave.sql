-- Aave v3 reserves this nest can name, each symbol and decimals read from the token on 2026-10-16.
-- Priced in dollars: WETH by the hour's Chainlink close, and USDC, USDT, DAI, USDS, GHO, PYUSD and
-- RLUSD at one dollar. The rest need an exchange rate or a feed this nest does not have, so their
-- dollar value is NULL, not a guess.
CREATE VIEW aave_assets AS
SELECT * FROM (VALUES
  ('0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', 'WETH', 18, 'eth'),
  ('0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0', 'wstETH', 18, 'none'),
  ('0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee', 'weETH', 18, 'none'),
  ('0x2260fac5e5542a773aa44fbcfedf7c193bc2c599', 'WBTC', 8, 'none'),
  ('0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf', 'cbBTC', 8, 'none'),
  ('0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48', 'USDC', 6, 'usd'),
  ('0xdac17f958d2ee523a2206206994597c13d831ec7', 'USDT', 6, 'usd'),
  ('0x6b175474e89094c44da98b954eedeac495271d0f', 'DAI', 18, 'usd'),
  ('0xdc035d45d973e3ec169d2276ddab16f1e407384f', 'USDS', 18, 'usd'),
  ('0x40d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f', 'GHO', 18, 'usd'),
  ('0x4c9edd5852cd905f086c759e8383e09bff1e68b3', 'USDe', 18, 'none'),
  ('0x9d39a5de30e57443bff2a8307a4256c8797a3497', 'sUSDe', 18, 'none'),
  ('0x6c3ea9036406852006290770bedfcaba0e23a0e8', 'PYUSD', 6, 'usd'),
  ('0x8292bb45bf1ee4d140127049757c2e0ff06317ed', 'RLUSD', 18, 'usd'),
  ('0x514910771af9ca656af840dff83e8264ecf986ca', 'LINK', 18, 'none'),
  ('0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9', 'AAVE', 18, 'none'),
  ('0xba100000625a3754423978a60c9317c58a424e3d', 'BAL', 18, 'none'),
  ('0x1abaea1f7c830bd89acc67ec4af516284b1bc33c', 'EURC', 6, 'none'),
  ('0xc139190f447e929f090edeb554d95abb8b18ac1c', 'USDtb', 18, 'none'),
  ('0x18084fba666a33d37592fa2633fd49a74dd93a88', 'tBTC', 18, 'none'),
  ('0xae78736cd615f374d3085123a210448e74fc6393', 'rETH', 18, 'none'),
  ('0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', 'UNI', 18, 'none'),
  ('0xbe9895146f7af43049ca1c1ae358b0541ea49704', 'cbETH', 18, 'none'),
  ('0x68749665ff8d2d112fa859aa293f07a622782f38', 'XAUt', 6, 'none'),
  ('0x5a98fcbea516cf06857215779fd812ca3bef1b32', 'LDO', 18, 'none'),
  ('0x8236a87084f8b84306f72007f36f2618a5634494', 'LBTC', 8, 'none'),
  ('0x657e8c867d8b37dcc18fa4caead9c45eb088c642', 'eBTC', 8, 'none'),
  ('0xf939e0a03fb07f59a73314e73794be0e57ac1b4e', 'crvUSD', 18, 'none'),
  ('0xd533a949740bb3306d119cc777fa900ba034cd52', 'CRV', 18, 'none'),
  ('0xa35b1b31ce002fbf2058d22f30f95d405200a15b', 'ETHx', 18, 'none'),
  ('0x853d955acef822db058eb8505911ed77f175b99e', 'FRAX', 18, 'none'),
  ('0xa1290d69c65a6fe4df752f95823fae25cb99e5a7', 'rsETH', 18, 'none')
) AS t(asset, symbol, decimals, priced);

-- Every liquidation: who was liquidated, what was seized and repaid, in token units and, where the
-- asset is priced, in dollars at that hour's ETH/USD close. An asset missing from aave_assets is
-- shown by address, with its amount NULL: its decimals are not known here.
CREATE VIEW aave_liquidations AS
SELECT
  to_timestamp(l.block_timestamp) AS at,
  l.block_number,
  l.tx_hash,
  l."user" AS borrower,
  l.liquidator,
  coalesce(c.symbol, l."collateralAsset") AS collateral,
  CAST(l."liquidatedCollateralAmount_dec" AS DOUBLE) / power(10, c.decimals) AS collateral_amount,
  coalesce(d.symbol, l."debtAsset") AS debt,
  CAST(l."debtToCover_dec" AS DOUBLE) / power(10, d.decimals) AS debt_repaid,
  CASE d.priced
    WHEN 'usd' THEN CAST(l."debtToCover_dec" AS DOUBLE) / power(10, d.decimals)
    WHEN 'eth' THEN CAST(l."debtToCover_dec" AS DOUBLE) / power(10, d.decimals) * p.close
  END AS debt_repaid_usd,
  CASE c.priced
    WHEN 'usd' THEN CAST(l."liquidatedCollateralAmount_dec" AS DOUBLE) / power(10, c.decimals)
    WHEN 'eth' THEN CAST(l."liquidatedCollateralAmount_dec" AS DOUBLE) / power(10, c.decimals) * p.close
  END AS collateral_seized_usd
FROM aave__liquidation_call l
LEFT JOIN aave_assets c ON c.asset = l."collateralAsset"
LEFT JOIN aave_assets d ON d.asset = l."debtAsset"
LEFT JOIN eth_usd_hourly p ON p.hour = date_trunc('hour', to_timestamp(l.block_timestamp));

-- Liquidations per UTC day, with the dollar total of the debt repaid where it is priced. Read from the
-- event table rather than from aave_liquidations, so the sum is over amounts known to fit.
CREATE VIEW aave_liquidations_daily AS
SELECT
  date_trunc('day', to_timestamp(l.block_timestamp)) AS day,
  count(*) AS liquidations,
  count(DISTINCT l."user") AS borrowers,
  sum(CASE d.priced
    WHEN 'usd' THEN CAST(l."debtToCover_dec" AS DOUBLE) / power(10, d.decimals)
    WHEN 'eth' THEN CAST(l."debtToCover_dec" AS DOUBLE) / power(10, d.decimals) * p.close
  END) AS debt_repaid_usd,
  count(*) - count(CASE WHEN d.priced IN ('usd', 'eth') THEN 1 END) AS unpriced
FROM aave__liquidation_call l
LEFT JOIN aave_assets d ON d.asset = l."debtAsset"
LEFT JOIN eth_usd_hourly p ON p.hour = date_trunc('hour', to_timestamp(l.block_timestamp))
WHERE NOT l."debtToCover_overflow"
GROUP BY 1;
