-- Create the business impact master view
CREATE OR REPLACE VIEW vw_business_impact AS
SELECT
    pd.store_id,
    pd.product_id,
    pd.category_clean,
    pd.region_clean,

    pd.total_units_sold,
    pd.total_units_ordered,
    pd.avg_inventory_level,
    pd.avg_cover_days,
    pd.low_cover_pct,
    pd.high_cover_pct,
    pd.zero_inventory_pct,
    pd.order_day_pct,
    pd.wape,
    pd.forecast_bias,
    pd.total_at_risk_units_proxy,
    pd.total_excess_units_proxy,

    pd.policy_status,
    pd.root_cause_hint,
    pd.priority_band,

    ra.reorder_behavior_assessment,
    ra.safety_stock_behavior_assessment,
    ra.lead_time_behavior_proxy,
    ra.demand_variability_band,

    CASE
        WHEN ra.reorder_behavior_assessment = 'Trigger Too Early / Excessive'
          OR pd.policy_status = 'Overstock Risk'
        THEN 'Excess / Working Capital'

        WHEN ra.reorder_behavior_assessment = 'Trigger Too Late / Reactive'
          OR pd.policy_status = 'Understock Risk'
        THEN 'Service Risk'

        WHEN ra.lead_time_behavior_proxy = 'Continuous Daily Ordering'
        THEN 'Operational Burden'

        ELSE 'Monitor'
    END AS impact_theme,

    CASE
        WHEN (
            ra.reorder_behavior_assessment = 'Trigger Too Early / Excessive'
            OR pd.policy_status = 'Overstock Risk'
        ) AND pd.priority_band = 'High'
        THEN 'High'

        WHEN ra.lead_time_behavior_proxy = 'Continuous Daily Ordering'
        THEN 'Medium'

        ELSE 'Low'
    END AS impact_priority,

    CASE
        WHEN ra.reorder_behavior_assessment = 'Trigger Too Early / Excessive'
          OR pd.policy_status = 'Overstock Risk'
        THEN pd.total_excess_units_proxy

        WHEN ra.reorder_behavior_assessment = 'Trigger Too Late / Reactive'
          OR pd.policy_status = 'Understock Risk'
        THEN pd.total_at_risk_units_proxy

        ELSE 0
    END AS primary_impact_units_proxy,

    CASE
        WHEN pd.total_units_sold > 0 THEN
            (
                CASE
                    WHEN ra.reorder_behavior_assessment = 'Trigger Too Early / Excessive'
                      OR pd.policy_status = 'Overstock Risk'
                    THEN pd.total_excess_units_proxy

                    WHEN ra.reorder_behavior_assessment = 'Trigger Too Late / Reactive'
                      OR pd.policy_status = 'Understock Risk'
                    THEN pd.total_at_risk_units_proxy

                    ELSE 0
                END
            )::numeric / pd.total_units_sold
        ELSE NULL
    END AS primary_impact_vs_sales_ratio

FROM vw_policy_diagnosis pd
LEFT JOIN vw_reorder_safetystock_leadtime_assessment ra
    ON pd.store_id = ra.store_id
   AND pd.product_id = ra.product_id;




-- row count validate
SELECT COUNT(*) AS impact_rows
FROM vw_business_impact;

-- Preview the data
SELECT *
FROM vw_business_impact
ORDER BY total_units_sold DESC
LIMIT 20;


-- Impact theme distribution
SELECT
    impact_theme,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(primary_impact_units_proxy) AS total_primary_impact_units_proxy
FROM vw_business_impact
GROUP BY impact_theme
ORDER BY impact_theme;


-- Impact priority distribution
SELECT
    impact_priority,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(primary_impact_units_proxy) AS total_primary_impact_units_proxy
FROM vw_business_impact
GROUP BY impact_priority
ORDER BY
    CASE impact_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;


-- Null check
SELECT *
FROM vw_business_impact
WHERE impact_theme IS NULL
   OR impact_priority IS NULL;





-- Business impact master
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    total_units_ordered,
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
    policy_status,
    root_cause_hint,
    priority_band,
    reorder_behavior_assessment,
    safety_stock_behavior_assessment,
    lead_time_behavior_proxy,
    demand_variability_band,
    impact_theme,
    impact_priority,
    primary_impact_units_proxy,
    primary_impact_vs_sales_ratio
FROM vw_business_impact
ORDER BY
    CASE impact_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    primary_impact_units_proxy DESC,
    total_units_sold DESC;



-- Overall impact summary
SELECT
    COUNT(*) AS total_sku_store_count,
    SUM(total_units_sold) AS total_units_sold,

    SUM(CASE WHEN impact_theme = 'Excess / Working Capital' THEN 1 ELSE 0 END) AS excess_item_count,
    SUM(CASE WHEN impact_theme = 'Excess / Working Capital' THEN total_units_sold ELSE 0 END) AS units_sold_in_excess_items,
    SUM(CASE WHEN impact_theme = 'Excess / Working Capital' THEN primary_impact_units_proxy ELSE 0 END) AS excess_units_proxy_total,

    SUM(CASE WHEN impact_theme = 'Service Risk' THEN 1 ELSE 0 END) AS service_risk_item_count,
    SUM(CASE WHEN impact_theme = 'Service Risk' THEN total_units_sold ELSE 0 END) AS units_sold_in_service_risk_items,
    SUM(CASE WHEN impact_theme = 'Service Risk' THEN primary_impact_units_proxy ELSE 0 END) AS at_risk_units_proxy_total,

    SUM(CASE WHEN impact_theme = 'Operational Burden' THEN 1 ELSE 0 END) AS operational_burden_item_count,

    SUM(CASE WHEN impact_priority = 'High' THEN 1 ELSE 0 END) AS high_priority_item_count,
    SUM(CASE WHEN impact_priority = 'High' THEN primary_impact_units_proxy ELSE 0 END) AS high_priority_impact_units_proxy,

    ROUND(
        100.0 * SUM(CASE WHEN impact_theme = 'Excess / Working Capital' THEN total_units_sold ELSE 0 END)
        / NULLIF(SUM(total_units_sold), 0),
        2
    ) AS sales_share_in_excess_items_pct
FROM vw_business_impact;



-- Impact theme summary
SELECT
    impact_theme,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(primary_impact_units_proxy) AS total_primary_impact_units_proxy,
    ROUND(AVG(avg_cover_days), 2) AS avg_cover_days,
    ROUND(AVG(wape), 4) AS avg_wape,
    ROUND(AVG(order_day_pct), 2) AS avg_order_day_pct
FROM vw_business_impact
GROUP BY impact_theme
ORDER BY impact_theme;



-- Category impact summary
SELECT
    category_clean,
    impact_theme,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(primary_impact_units_proxy) AS total_primary_impact_units_proxy
FROM vw_business_impact
GROUP BY
    category_clean,
    impact_theme
ORDER BY
    category_clean,
    impact_theme;



-- Region impact summary
SELECT
    region_clean,
    impact_theme,
    COUNT(*) AS sku_store_count,
    SUM(total_units_sold) AS total_units_sold,
    SUM(primary_impact_units_proxy) AS total_primary_impact_units_proxy
FROM vw_business_impact
GROUP BY
    region_clean,
    impact_theme
ORDER BY
    region_clean,
    impact_theme;



-- Top impact items
SELECT
    store_id,
    product_id,
    category_clean,
    region_clean,
    total_units_sold,
    primary_impact_units_proxy,
    ROUND(primary_impact_vs_sales_ratio, 4) AS primary_impact_vs_sales_ratio,
    avg_cover_days,
    order_day_pct,
    wape,
    policy_status,
    reorder_behavior_assessment,
    lead_time_behavior_proxy,
    impact_theme,
    impact_priority
FROM vw_business_impact
WHERE impact_theme <> 'Monitor'
ORDER BY
    CASE impact_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    primary_impact_units_proxy DESC,
    total_units_sold DESC;