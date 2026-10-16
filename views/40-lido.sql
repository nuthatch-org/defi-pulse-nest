-- ETH staked into Lido, stETH asked back, and ETH claimed out, per UTC day.
CREATE VIEW lido_daily_flows AS
SELECT day,
       coalesce(sum(staked), 0) / 1e18 AS staked_eth,
       coalesce(sum(requested), 0) / 1e18 AS withdrawal_requested_steth,
       coalesce(sum(claimed), 0) / 1e18 AS claimed_eth,
       (coalesce(sum(staked), 0) - coalesce(sum(claimed), 0)) / 1e18 AS net_eth
FROM (
  SELECT date_trunc('day', to_timestamp(block_timestamp)) AS day, amount_dec AS staked,
         CAST(NULL AS DECIMAL(38, 0)) AS requested, CAST(NULL AS DECIMAL(38, 0)) AS claimed
  FROM steth__submitted
  UNION ALL
  SELECT date_trunc('day', to_timestamp(block_timestamp)), CAST(NULL AS DECIMAL(38, 0)), "amountOfStETH_dec",
         CAST(NULL AS DECIMAL(38, 0))
  FROM lido_wq__withdrawal_requested
  UNION ALL
  SELECT date_trunc('day', to_timestamp(block_timestamp)), CAST(NULL AS DECIMAL(38, 0)),
         CAST(NULL AS DECIMAL(38, 0)), "amountOfETH_dec"
  FROM lido_wq__withdrawal_claimed
) AS flows
GROUP BY day;

-- Withdrawal requests not yet finalized, as of the newest block indexed: every request whose id is
-- above the highest id any WithdrawalsFinalized has reached.
CREATE VIEW lido_withdrawal_queue AS
SELECT
  count(*) AS pending_requests,
  sum(CAST(r."amountOfStETH_dec" AS DOUBLE)) / 1e18 AS pending_steth,
  min(to_timestamp(r.block_timestamp)) AS oldest_pending_since
FROM lido_wq__withdrawal_requested r
WHERE CAST(r."requestId_dec" AS DECIMAL(38, 0)) >
  (SELECT coalesce(max(CAST("to_dec" AS DECIMAL(38, 0))), 0) FROM lido_wq__withdrawals_finalized);
