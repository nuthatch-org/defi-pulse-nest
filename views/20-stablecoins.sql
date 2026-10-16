-- Every USDC mint and burn and USDT issue and redeem, in whole dollars. Transfers are not here:
-- this is supply created and destroyed, not money moving.
-- `units` is the signed amount in the coin's base units (both have 6 decimals), kept exact so that
-- sums over it are exact; `usd` is the same in dollars, for reading.
CREATE VIEW stablecoin_supply_events AS
SELECT coin, kind, block_number, block_timestamp, tx_hash, log_index, account, units,
       CAST(units AS DOUBLE) / 1e6 AS usd
FROM (
  SELECT 'USDC' AS coin, 'mint' AS kind, block_number, block_timestamp, tx_hash, log_index,
         "to" AS account, amount_dec AS units
  FROM usdc__mint
  UNION ALL
  SELECT 'USDC', 'burn', block_number, block_timestamp, tx_hash, log_index, burner, -amount_dec
  FROM usdc__burn
  UNION ALL
  SELECT 'USDT', 'issue', block_number, block_timestamp, tx_hash, log_index, NULL, amount_dec
  FROM usdt__issue
  UNION ALL
  SELECT 'USDT', 'redeem', block_number, block_timestamp, tx_hash, log_index, NULL, -amount_dec
  FROM usdt__redeem
) AS supply;

-- Net new supply per coin per UTC day: created minus destroyed.
CREATE VIEW stablecoin_daily_issuance AS
SELECT
  date_trunc('day', to_timestamp(block_timestamp)) AS day,
  coin,
  coalesce(sum(CASE WHEN units > 0 THEN units END), 0) / 1e6 AS created_usd,
  -coalesce(sum(CASE WHEN units < 0 THEN units END), 0) / 1e6 AS destroyed_usd,
  sum(units) / 1e6 AS net_usd,
  count(*) AS events
FROM stablecoin_supply_events
GROUP BY 1, 2;

-- The 25 largest mints, burns, issues and redeems in the seven days up to the newest one indexed.
CREATE VIEW largest_supply_moves_7d AS
SELECT coin, kind, to_timestamp(block_timestamp) AS at, usd, account, tx_hash
FROM stablecoin_supply_events
WHERE block_timestamp > (SELECT max(block_timestamp) FROM stablecoin_supply_events) - 7 * 86400
ORDER BY abs(usd) DESC
LIMIT 25;
