-- Check for nulls in critical columns

SELECT
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN store_id IS NULL THEN 1 ELSE 0 END) AS null_store_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN category_clean IS NULL THEN 1 ELSE 0 END) AS null_category_clean,
    SUM(CASE WHEN region_clean IS NULL THEN 1 ELSE 0 END) AS null_region_clean,
    SUM(CASE WHEN inventory_level IS NULL THEN 1 ELSE 0 END) AS null_inventory_level,
    SUM(CASE WHEN units_sold IS NULL THEN 1 ELSE 0 END) AS null_units_sold,
    SUM(CASE WHEN units_ordered IS NULL THEN 1 ELSE 0 END) AS null_units_ordered,
    SUM(CASE WHEN demand_forecast_clean IS NULL THEN 1 ELSE 0 END) AS null_demand_forecast_clean
FROM inventory_clean;


-- Check for bad numeric values

SELECT *
FROM inventory_clean
WHERE inventory_level < 0
   OR units_sold < 0
   OR units_ordered < 0
   OR demand_forecast_clean < 0;


-- Create KPI base view

CREATE OR REPLACE VIEW vw_kpi_base AS
SELECT
    date,
    store_id,
    product_id,
    category_clean,
    region_clean,
    inventory_level,
    units_sold,
    units_ordered,
    demand_forecast_clean,

    demand_forecast_clean - units_sold AS forecast_error,
    ABS(demand_forecast_clean - units_sold) AS abs_forecast_error,

    CASE
        WHEN demand_forecast_clean > 0
        THEN inventory_level::numeric / demand_forecast_clean
        ELSE NULL
    END AS cover_days,

    CASE
        WHEN demand_forecast_clean > 0
         AND inventory_level::numeric / demand_forecast_clean < 1
        THEN 1 ELSE 0
    END AS low_cover_flag,

    CASE
        WHEN demand_forecast_clean > 0
         AND inventory_level::numeric / demand_forecast_clean > 7
        THEN 1 ELSE 0
    END AS high_cover_flag,

    CASE
        WHEN inventory_level = 0 THEN 1 ELSE 0
    END AS zero_inventory_flag,

    GREATEST(demand_forecast_clean - inventory_level, 0) AS at_risk_units_proxy,

    GREATEST(inventory_level - 7 * demand_forecast_clean, 0) AS excess_units_proxy
FROM inventory_clean;

-- TEST THE VIEW

SELECT *
FROM vw_kpi_base
LIMIT 20;


-- Create KPI summary queries

-- Overall KPI summary

SELECT
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base;


-- Monthly KPI summary

SELECT
    date_trunc('month', date)::date AS month,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY 1
ORDER BY 1;


-- Category KPI summary

SELECT
    category_clean,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY 1
ORDER BY total_units_sold DESC;


-- Region KPI summary
SELECT
    region_clean,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY 1
ORDER BY total_units_sold DESC;


-- Store KPI summary

SELECT
    store_id,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY 1
ORDER BY total_units_sold DESC;


-- Product KPI summary

SELECT
    product_id,
    category_clean,
    SUM(units_sold) AS total_units_sold,
    ROUND(AVG(inventory_level), 2) AS avg_inventory_level,
    SUM(units_ordered) AS total_units_ordered,
    ROUND(SUM(units_ordered)::numeric / NULLIF(SUM(units_sold), 0), 2) AS replenishment_to_sales_ratio,
    ROUND(AVG(cover_days), 2) AS avg_cover_days,
    ROUND(100.0 * AVG(low_cover_flag), 2) AS low_cover_pct,
    ROUND(100.0 * AVG(high_cover_flag), 2) AS high_cover_pct,
    ROUND(100.0 * AVG(zero_inventory_flag), 2) AS zero_inventory_pct,
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias,
    SUM(at_risk_units_proxy) AS total_at_risk_units_proxy,
    SUM(excess_units_proxy) AS total_excess_units_proxy
FROM vw_kpi_base
GROUP BY 1, 2
ORDER BY total_units_sold DESC;



-- Validate KPI outputs

--Validate total units sold
SELECT SUM(units_sold) AS total_units_sold
FROM inventory_clean;

--Validate total units ordered
SELECT SUM(units_ordered) AS total_units_ordered
FROM inventory_clean;

--Validate low/high/zero flags
SELECT
    SUM(low_cover_flag) AS low_cover_rows,
    SUM(high_cover_flag) AS high_cover_rows,
    SUM(zero_inventory_flag) AS zero_inventory_rows
FROM vw_kpi_base;

--Validate cover days logic
SELECT *
FROM vw_kpi_base
WHERE cover_days IS NOT NULL
ORDER BY cover_days
LIMIT 20;

SELECT *
FROM vw_kpi_base
WHERE cover_days IS NOT NULL
ORDER BY cover_days DESC
LIMIT 20;


--Validate forecast error logic
SELECT
    MIN(forecast_error) AS min_forecast_error,
    MAX(forecast_error) AS max_forecast_error,
    AVG(forecast_error) AS avg_forecast_error,
    MIN(abs_forecast_error) AS min_abs_forecast_error,
    MAX(abs_forecast_error) AS max_abs_forecast_error
FROM vw_kpi_base;


-- Validate WAPE and Forecast Bias
SELECT
    ROUND(SUM(abs_forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS wape,
    ROUND(SUM(forecast_error)::numeric / NULLIF(SUM(units_sold), 0), 4) AS forecast_bias
FROM vw_kpi_base;












