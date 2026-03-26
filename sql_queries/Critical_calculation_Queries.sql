-- Create order cadence view
CREATE OR REPLACE VIEW vw_order_cadence AS
WITH order_events AS (
    SELECT
        store_id,
        product_id,
        date::date AS order_date,
        units_ordered,
        LAG(date::date) OVER (
            PARTITION BY store_id, product_id
            ORDER BY date::date
        ) AS prev_order_date
    FROM vw_kpi_base
    WHERE units_ordered > 0
)
SELECT
    store_id,
    product_id,
    COUNT(*) AS order_event_count,
    ROUND(AVG(units_ordered)::numeric, 2) AS avg_order_size_on_order_days,
    ROUND(STDDEV_SAMP(units_ordered)::numeric, 2) AS order_size_stddev,
    ROUND(AVG((order_date - prev_order_date)::numeric), 2) AS avg_days_between_orders,
    ROUND(STDDEV_SAMP((order_date - prev_order_date)::numeric), 2) AS stddev_days_between_orders
FROM order_events
GROUP BY
    store_id,
    product_id;



-- Create base behavior view
CREATE OR REPLACE VIEW vw_replenishment_behavior_base AS
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,

    COUNT(*) AS row_count,
    SUM(units_sold) AS total_units_sold,
    SUM(units_ordered) AS total_units_ordered,

    ROUND(AVG(units_sold)::numeric, 2) AS avg_daily_demand,
    ROUND(STDDEV_SAMP(units_sold)::numeric, 2) AS demand_stddev,

    ROUND(
        STDDEV_SAMP(units_sold)::numeric / NULLIF(AVG(units_sold), 0),
        4
    ) AS demand_cv,

    ROUND(AVG(demand_forecast_clean)::numeric, 2) AS avg_daily_forecast,
    ROUND(STDDEV_SAMP(demand_forecast_clean)::numeric, 2) AS forecast_stddev,

    ROUND(AVG(inventory_level)::numeric, 2) AS avg_inventory_level,
    ROUND(AVG(cover_days)::numeric, 2) AS avg_cover_days,

    ROUND(100 * AVG(low_cover_flag::numeric), 2) AS low_cover_pct,
    ROUND(100 * AVG(high_cover_flag::numeric), 2) AS high_cover_pct,
    ROUND(100 * AVG(zero_inventory_flag::numeric), 2) AS zero_inventory_pct,
    ROUND(100 * AVG(CASE WHEN units_ordered > 0 THEN 1.0 ELSE 0.0 END), 2) AS order_day_pct,

    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,

    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY
    store_id,
    product_id,
    category_clean,
    region_clean;



--Create final assessment view
CREATE OR REPLACE VIEW vw_reorder_safetystock_leadtime_assessment AS
SELECT
    b.store_id,
    b.product_id,
    b.category_clean,
    b.region_clean,

    b.row_count,
    b.total_units_sold,
    b.total_units_ordered,
    b.avg_daily_demand,
    b.demand_stddev,
    b.demand_cv,
    b.avg_daily_forecast,
    b.forecast_stddev,
    b.avg_inventory_level,
    b.avg_cover_days,
    b.low_cover_pct,
    b.high_cover_pct,
    b.zero_inventory_pct,
    b.order_day_pct,
    b.wape,
    b.forecast_bias,
    b.total_at_risk_units_proxy,
    b.total_excess_units_proxy,

    c.order_event_count,
    c.avg_order_size_on_order_days,
    c.order_size_stddev,
    c.avg_days_between_orders,
    c.stddev_days_between_orders,

    CASE
        WHEN b.avg_cover_days < 1
          OR b.low_cover_pct >= 20
          OR b.zero_inventory_pct >= 5
        THEN 'Trigger Too Late / Reactive'

        WHEN b.avg_cover_days > 7
          OR b.high_cover_pct >= 20
        THEN 'Trigger Too Early / Excessive'

        ELSE 'Trigger Broadly Reasonable'
    END AS reorder_behavior_assessment,

    CASE
        WHEN (b.demand_cv > 1.00 OR b.wape > 0.35 OR ABS(b.forecast_bias) > 0.10)
          AND (b.avg_cover_days < 1 OR b.low_cover_pct >= 20 OR b.zero_inventory_pct >= 5)
        THEN 'Buffer Insufficient'

        WHEN (b.demand_cv <= 0.50 AND b.wape <= 0.20)
          AND (b.avg_cover_days > 7 OR b.high_cover_pct >= 20)
        THEN 'Buffer Excessive'

        WHEN b.demand_cv > 1.00 OR b.wape > 0.35 OR ABS(b.forecast_bias) > 0.10
        THEN 'Buffer Needs Review'

        ELSE 'Buffer Broadly Adequate'
    END AS safety_stock_behavior_assessment,

    CASE
        WHEN b.order_day_pct >= 95
         AND COALESCE(c.avg_days_between_orders, 1) <= 1.5
        THEN 'Continuous Daily Ordering'

        WHEN COALESCE(c.stddev_days_between_orders, 0) > 5
        THEN 'Irregular Cadence'

        WHEN COALESCE(c.avg_days_between_orders, 0) >= 14
        THEN 'Sparse / Long-Gap Ordering'

        ELSE 'Moderate Cadence'
    END AS lead_time_behavior_proxy,

    CASE
        WHEN b.demand_cv > 1.00 THEN 'High Variability'
        WHEN b.demand_cv > 0.50 THEN 'Medium Variability'
        ELSE 'Low Variability'
    END AS demand_variability_band

FROM vw_replenishment_behavior_base b
LEFT JOIN vw_order_cadence c
    ON b.store_id = c.store_id
   AND b.product_id = c.product_id;



-- Validate the assessment view

-- ROW COUNT
SELECT COUNT(*) AS assessment_rows
FROM vw_reorder_safetystock_leadtime_assessment;

-- PREVIEW THE TABLE
SELECT *
FROM vw_reorder_safetystock_leadtime_assessment
ORDER BY total_units_sold DESC
LIMIT 20;

-- Reorder behavior distribution
SELECT
    reorder_behavior_assessment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY reorder_behavior_assessment
ORDER BY reorder_behavior_assessment;

-- Safety stock behavior distribution
SELECT
    safety_stock_behavior_assessment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY safety_stock_behavior_assessment
ORDER BY safety_stock_behavior_assessment;

-- Lead-time behavior proxy distribution
SELECT
    lead_time_behavior_proxy,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY lead_time_behavior_proxy
ORDER BY lead_time_behavior_proxy;

-- Demand variability distribution
SELECT
    demand_variability_band,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(demand_cv), 4) AS avg_demand_cv
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY demand_variability_band
ORDER BY demand_variability_band;


-- NULL CHECK
SELECT *
FROM vw_reorder_safetystock_leadtime_assessment
WHERE reorder_behavior_assessment IS NULL
   OR safety_stock_behavior_assessment IS NULL
   OR lead_time_behavior_proxy IS NULL
   OR demand_variability_band IS NULL;




-- MASTER TABLE
SELECT *
FROM vw_reorder_safetystock_leadtime_assessment
ORDER BY total_units_sold DESC;


-- Reorder behavior summary
SELECT
    reorder_behavior_assessment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(low_cover_pct), 2) AS avg_low_cover_pct,
    ROUND(AVG(high_cover_pct), 2) AS avg_high_cover_pct,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY reorder_behavior_assessment
ORDER BY reorder_behavior_assessment;


-- Safety stock behavior summary
SELECT
    safety_stock_behavior_assessment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(demand_cv), 4) AS avg_demand_cv,
    ROUND(AVG(wape), 4) AS avg_wape,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY safety_stock_behavior_assessment
ORDER BY safety_stock_behavior_assessment;


-- Lead-time behavior proxy summary
SELECT
    lead_time_behavior_proxy,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    ROUND(AVG(order_day_pct), 2) AS avg_order_day_pct,
    ROUND(AVG(avg_days_between_orders), 2) AS avg_days_between_orders,
    ROUND(AVG(stddev_days_between_orders), 2) AS avg_stddev_days_between_orders
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY lead_time_behavior_proxy
ORDER BY lead_time_behavior_proxy;


-- Category assessment summary
SELECT
    category_clean,
    reorder_behavior_assessment,
    safety_stock_behavior_assessment,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(total_excess_units_proxy) AS total_excess_units_proxy
FROM vw_reorder_safetystock_leadtime_assessment
GROUP BY
    category_clean,
    reorder_behavior_assessment,
    safety_stock_behavior_assessment
ORDER BY
    category_clean,
    reorder_behavior_assessment,
    safety_stock_behavior_assessment;


-- Review-priority items
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    total_units_ordered,
    avg_daily_demand,
    demand_cv,
    avg_cover_days,
    low_cover_pct,
    high_cover_pct,
    zero_inventory_pct,
    order_day_pct,
    wape,
    forecast_bias,
    avg_days_between_orders,
    stddev_days_between_orders,
    reorder_behavior_assessment,
    safety_stock_behavior_assessment,
    lead_time_behavior_proxy,
    demand_variability_band
FROM vw_reorder_safetystock_leadtime_assessment
WHERE reorder_behavior_assessment <> 'Trigger Broadly Reasonable'
   OR safety_stock_behavior_assessment <> 'Buffer Broadly Adequate'
ORDER BY total_units_sold DESC;



