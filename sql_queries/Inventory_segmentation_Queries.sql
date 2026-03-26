-- Create the SKU-Store summary view in PostgreSQL

CREATE OR REPLACE VIEW vw_sku_store_summary AS
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,

    COUNT(*) AS row_count,
    SUM(units_sold) AS total_units_sold,
    AVG(units_sold)::numeric AS avg_daily_units_sold,
    AVG(inventory_level)::numeric AS avg_inventory_level,
    AVG(cover_days)::numeric AS avg_cover_days,
    AVG(low_cover_flag::numeric) AS low_cover_rate,
    AVG(high_cover_flag::numeric) AS high_cover_rate,
    AVG(zero_inventory_flag::numeric) AS zero_inventory_rate,
    AVG(CASE WHEN units_ordered > 0 THEN 1.0 ELSE 0.0 END) AS order_day_rate,

    SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0) AS wape,
    SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0) AS forecast_bias,

    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY
    store_id,
    product_id,
    category_clean,
    region_clean;


--TEST
SELECT COUNT(*) AS sku_store_rows
FROM vw_sku_store_summary;


-- Preview the summary table

SELECT *
FROM vw_sku_store_summary
ORDER BY total_units_sold DESC
LIMIT 20;


-- Create the segmentation view

CREATE OR REPLACE VIEW vw_inventory_segments AS
WITH ranked AS (
    SELECT
        s.*,

        s.total_units_sold::numeric
        / NULLIF(SUM(s.total_units_sold) OVER (), 0) AS units_sales_share,

        SUM(s.total_units_sold) OVER (
            ORDER BY s.total_units_sold DESC, s.product_id, s.store_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )::numeric
        / NULLIF(SUM(s.total_units_sold) OVER (), 0) AS cumulative_units_share,

        NTILE(3) OVER (
            ORDER BY s.avg_daily_units_sold DESC NULLS LAST
        ) AS velocity_tile,

        NTILE(3) OVER (
            ORDER BY s.wape ASC NULLS LAST
        ) AS forecast_tile

    FROM vw_sku_store_summary s
)
SELECT
    *,

    CASE
        WHEN cumulative_units_share <= 0.80 THEN 'A'
        WHEN cumulative_units_share <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_segment,

    CASE
        WHEN velocity_tile = 1 THEN 'Fast'
        WHEN velocity_tile = 2 THEN 'Medium'
        ELSE 'Slow'
    END AS velocity_segment,

    CASE
        WHEN forecast_tile = 1 THEN 'Good'
        WHEN forecast_tile = 2 THEN 'Moderate'
        ELSE 'Poor'
    END AS forecast_segment,

    CASE
        WHEN avg_cover_days < 1 OR low_cover_rate >= 0.20 THEN 'Understocked'
        WHEN avg_cover_days > 7 OR high_cover_rate >= 0.20 THEN 'Overstocked'
        ELSE 'Balanced'
    END AS inventory_position_segment

FROM ranked;


-- preview the segmentation table
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    avg_daily_units_sold,
    avg_cover_days,
    wape,
    abc_segment,
    velocity_segment,
    forecast_segment,
    inventory_position_segment
FROM vw_inventory_segments
ORDER BY total_units_sold DESC;


-- Validate ABC segments

SELECT
    abc_segment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_inventory_segments
GROUP BY abc_segment
ORDER BY abc_segment;


-- Validate Velocity Segments
SELECT
    velocity_segment,
    COUNT(*) AS sku_store_count,
    ROUND(AVG(avg_daily_units_sold), 2) AS avg_daily_units_sold
FROM vw_inventory_segments
GROUP BY velocity_segment
ORDER BY
    CASE velocity_segment
        WHEN 'Fast' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;


--Validate forecast segments
SELECT
    forecast_segment,
    COUNT(*) AS sku_store_count,
    ROUND(AVG(wape), 4) AS avg_wape
FROM vw_inventory_segments
GROUP BY forecast_segment
ORDER BY
    CASE forecast_segment
        WHEN 'Good' THEN 1
        WHEN 'Moderate' THEN 2
        ELSE 3
    END;


--Validate inventory position segments
SELECT
    inventory_position_segment,
    COUNT(*) AS sku_store_count,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(100 * AVG(low_cover_rate), 2) AS avg_low_cover_pct,
    ROUND(100 * AVG(high_cover_rate), 2) AS avg_high_cover_pct
FROM vw_inventory_segments
GROUP BY inventory_position_segment
ORDER BY inventory_position_segment;


-- Check for null segment labels
SELECT *
FROM vw_inventory_segments
WHERE abc_segment IS NULL
   OR velocity_segment IS NULL
   OR forecast_segment IS NULL
   OR inventory_position_segment IS NULL;


-- Export the Segment Master table
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    ROUND(avg_daily_units_sold, 2) AS avg_daily_units_sold,
    ROUND(avg_inventory_level, 2) AS avg_inventory_level,
    ROUND(avg_cover_days, 2) AS avg_cover_days,
    ROUND(100 * low_cover_rate, 2) AS low_cover_pct,
    ROUND(100 * high_cover_rate, 2) AS high_cover_pct,
    ROUND(100 * zero_inventory_rate, 2) AS zero_inventory_pct,
    ROUND(100 * order_day_rate, 2) AS order_day_pct,
    ROUND(wape, 4) AS wape,
    ROUND(forecast_bias, 4) AS forecast_bias,
    total_at_risk_units_proxy,
    total_excess_units_proxy,
    abc_segment,
    velocity_segment,
    forecast_segment,
    inventory_position_segment
FROM vw_inventory_segments
ORDER BY total_units_sold DESC;


-- Export ABC Summary
SELECT
    abc_segment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_inventory_segments
GROUP BY abc_segment
ORDER BY abc_segment;


-- Export Velocity Summary
SELECT
    velocity_segment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_inventory_segments
GROUP BY velocity_segment
ORDER BY
    CASE velocity_segment
        WHEN 'Fast' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;


-- Export Forecast Summary
SELECT
    forecast_segment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_inventory_segments
GROUP BY forecast_segment
ORDER BY
    CASE forecast_segment
        WHEN 'Good' THEN 1
        WHEN 'Moderate' THEN 2
        ELSE 3
    END;


-- Export Inventory Position Summary
SELECT
    inventory_position_segment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_inventory_segments
GROUP BY inventory_position_segment
ORDER BY inventory_position_segment;

