-- Create the policy diagnosis view
CREATE OR REPLACE VIEW vw_policy_diagnosis AS
WITH order_metrics AS (
    SELECT
        store_id,
        product_id,
        SUM(units_ordered) AS total_units_ordered,
        AVG(CASE WHEN units_ordered > 0 THEN units_ordered::numeric END) AS avg_order_size_on_order_days,
        SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0) AS replenishment_to_sales_ratio
    FROM vw_kpi_base
    GROUP BY
        store_id,
        product_id
)
SELECT
    s.store_id,
    s.product_id,
    s.category_clean,
    s.region_clean,

    s.total_units_sold,
    o.total_units_ordered,
    ROUND(o.avg_order_size_on_order_days, 2) AS avg_order_size_on_order_days,
    ROUND(o.replenishment_to_sales_ratio, 2) AS replenishment_to_sales_ratio,

    ROUND(s.avg_daily_units_sold, 2) AS avg_daily_units_sold,
    ROUND(s.avg_inventory_level, 2) AS avg_inventory_level,
    ROUND(s.avg_cover_days, 2) AS avg_cover_days,
    ROUND(100 * s.low_cover_rate, 2) AS low_cover_pct,
    ROUND(100 * s.high_cover_rate, 2) AS high_cover_pct,
    ROUND(100 * s.zero_inventory_rate, 2) AS zero_inventory_pct,
    ROUND(100 * s.order_day_rate, 2) AS order_day_pct,
    ROUND(s.wape, 4) AS wape,
    ROUND(s.forecast_bias, 4) AS forecast_bias,

    s.total_at_risk_units_proxy,
    s.total_excess_units_proxy,

    s.abc_segment,
    s.velocity_segment,
    s.forecast_segment,
    s.inventory_position_segment,

    CASE
        WHEN (s.avg_cover_days < 1 OR s.low_cover_rate >= 0.20 OR s.zero_inventory_rate >= 0.05)
             AND (s.avg_cover_days > 7 OR s.high_cover_rate >= 0.20)
        THEN 'Mixed Instability'

        WHEN s.avg_cover_days < 1
          OR s.low_cover_rate >= 0.20
          OR s.zero_inventory_rate >= 0.05
        THEN 'Understock Risk'

        WHEN s.avg_cover_days > 7
          OR s.high_cover_rate >= 0.20
        THEN 'Overstock Risk'

        ELSE 'Stable'
    END AS policy_status,

    CASE
        WHEN (s.wape > 0.35 OR ABS(s.forecast_bias) > 0.10)
         AND (
             o.replenishment_to_sales_ratio > 1.15
             OR o.replenishment_to_sales_ratio < 0.85
             OR s.order_day_rate > 0.80
             OR s.order_day_rate < 0.10
         )
        THEN 'Forecast + Replenishment'

        WHEN s.wape > 0.35
          OR ABS(s.forecast_bias) > 0.10
        THEN 'Forecast-driven'

        WHEN o.replenishment_to_sales_ratio > 1.15
          OR o.replenishment_to_sales_ratio < 0.85
          OR s.order_day_rate > 0.80
          OR s.order_day_rate < 0.10
        THEN 'Replenishment-driven'

        ELSE 'Monitor'
    END AS root_cause_hint,

    CASE
        WHEN (
            s.avg_cover_days < 1
            OR s.low_cover_rate >= 0.20
            OR s.zero_inventory_rate >= 0.05
            OR s.avg_cover_days > 7
            OR s.high_cover_rate >= 0.20
        )
        AND (
            s.wape > 0.35
            OR ABS(s.forecast_bias) > 0.10
            OR o.replenishment_to_sales_ratio > 1.15
            OR o.replenishment_to_sales_ratio < 0.85
        )
        THEN 'High'

        WHEN s.avg_cover_days < 1
          OR s.low_cover_rate >= 0.20
          OR s.zero_inventory_rate >= 0.05
          OR s.avg_cover_days > 7
          OR s.high_cover_rate >= 0.20
        THEN 'Medium'

        ELSE 'Low'
    END AS priority_band

FROM vw_inventory_segments s
LEFT JOIN order_metrics o
    ON s.store_id = o.store_id
   AND s.product_id = o.product_id;



-- Validate the diagnosis View
SELECT COUNT(*) AS policy_rows
FROM vw_policy_diagnosis;

--Preview the diagnosis table
SELECT *
FROM vw_policy_diagnosis
ORDER BY total_units_sold DESC
LIMIT 20;


-- Check policy status distribution
SELECT
    policy_status,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_policy_diagnosis
GROUP BY policy_status
ORDER BY policy_status;


-- Check root cause distribution
SELECT
    root_cause_hint,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_policy_diagnosis
GROUP BY root_cause_hint
ORDER BY root_cause_hint;


-- Check priority distribution
SELECT
    priority_band,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_policy_diagnosis
GROUP BY priority_band
ORDER BY
    CASE priority_band
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;


-- Check for null labels
SELECT *
FROM vw_policy_diagnosis
WHERE policy_status IS NULL
   OR root_cause_hint IS NULL
   OR priority_band IS NULL;




--Export diagnosis result tables

--Diagnosis master table
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    total_units_ordered,
    avg_order_size_on_order_days,
    replenishment_to_sales_ratio,
    avg_daily_units_sold,
    avg_inventory_level,
    avg_cover_days,
    low_cover_pct,
    high_cover_pct,
    zero_inventory_pct,
    order_day_pct,
    wape,
    forecast_bias,
    total_at_risk_units_proxy,
    total_excess_units_proxy,
    abc_segment,
    velocity_segment,
    forecast_segment,
    inventory_position_segment,
    policy_status,
    root_cause_hint,
    priority_band
FROM vw_policy_diagnosis
ORDER BY
    CASE priority_band
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    total_units_sold DESC;


-- Policy status summary
SELECT
    policy_status,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_policy_diagnosis
GROUP BY policy_status
ORDER BY policy_status;


-- Root cause summary
SELECT
    root_cause_hint,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(wape), 4) AS avg_wape,
    ROUND(AVG(replenishment_to_sales_ratio), 2) AS avg_replenishment_to_sales_ratio,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_policy_diagnosis
GROUP BY root_cause_hint
ORDER BY root_cause_hint;


-- Category × policy status summary
SELECT
    category_clean,
    policy_status,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_policy_diagnosis
GROUP BY
    category_clean,
    policy_status
ORDER BY
    category_clean,
    policy_status;


-- Region × policy status summary
SELECT
    region_clean,
    policy_status,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_policy_diagnosis
GROUP BY
    region_clean,
    policy_status
ORDER BY
    region_clean,
    policy_status;


-- High-Priority Items List
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    total_units_ordered,
    replenishment_to_sales_ratio,
    avg_cover_days,
    low_cover_pct,
    high_cover_pct,
    zero_inventory_pct,
    wape,
    forecast_bias,
    total_at_risk_units_proxy,
    total_excess_units_proxy,
    abc_segment,
    velocity_segment,
    forecast_segment,
    inventory_position_segment,
    policy_status,
    root_cause_hint,
    priority_band
FROM vw_policy_diagnosis
WHERE priority_band = 'High'
ORDER BY total_units_sold DESC;


 