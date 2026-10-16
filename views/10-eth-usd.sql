-- ETH/USD from Chainlink's aggregator, 8 decimals. One row per hour that had an update.
CREATE VIEW eth_usd_hourly AS
SELECT
  date_trunc('hour', to_timestamp(block_timestamp)) AS hour,
  first_value(CAST(current_dec AS DOUBLE) ORDER BY block_number, log_index) / 1e8 AS open,
  max(CAST(current_dec AS DOUBLE)) / 1e8 AS high,
  min(CAST(current_dec AS DOUBLE)) / 1e8 AS low,
  last_value(CAST(current_dec AS DOUBLE) ORDER BY block_number, log_index) / 1e8 AS close,
  count(*) AS updates
FROM eth_usd__answer_updated
GROUP BY 1;
