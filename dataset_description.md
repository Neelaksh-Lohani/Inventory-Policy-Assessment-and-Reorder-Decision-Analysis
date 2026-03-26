# Dataset Description

This file documents the dataset used in the **Inventory Policy Assessment and Reorder Decision Analysis** project.

---

## 1. Dataset Purpose

The dataset was used to analyze retail inventory behavior across products and stores, with the goal of determining whether the business was primarily facing:

- **stock shortage / service risk**, or
- **excess inventory / working-capital pressure**

The analysis was designed to support inventory policy assessment, replenishment review, and business decision-making.

---

## 2. Unit of Analysis

The data is structured at a **daily SKU-store level**.

Each row represents the inventory and sales-related status of a specific:

- `Product_ID`
- `Store_ID`
- `Date`

This structure allows analysis of inventory behavior across time, products, stores, categories, and regions.

---

## 3. Dataset Size

- **Total rows:** 73,100
- **Granularity:** Daily transactional / operational level
- **Coverage:** 100 SKU-store combinations used in the project analysis

---

## 4. Original Working Columns

The original working schema used in the project is:

- `Date`
- `Store_ID`
- `Product_ID`
- `Category`
- `Region`
- `Inventory_Level`
- `Units_Sold`
- `Units_Ordered`
- `Demand_Forecast`
- `Price`
- `Discount`
- `Weather_Condition`
- `Holiday_Promotion`
- `Competitor_Pricing`
- `Seasonality`

---

## 5. Column Descriptions

### `Date`
Transaction / observation date for the record.

### `Store_ID`
Unique identifier for the store location.

### `Product_ID`
Unique identifier for the product.

### `Category`
Original product category label in the raw data.

### `Region`
Original regional label in the raw data.

### `Inventory_Level`
Available inventory level recorded for that product-store-date combination.

### `Units_Sold`
Units sold on that date.

### `Units_Ordered`
Units ordered or replenished on that date.

### `Demand_Forecast`
Forecasted demand for the product on that date.

### `Price`
Unit selling price of the product.

### `Discount`
Discount applied to the product.

### `Weather_Condition`
Weather label associated with the date or location context.

### `Holiday_Promotion`
Indicator showing whether a holiday or promotional condition was active.

### `Competitor_Pricing`
Competitor pricing reference used as an external context variable.

### `Seasonality`
Seasonal tag associated with the demand environment.

---

## 6. Data Quality Findings

The audit identified the following issues in the raw data:

- **No missing values**
- **No duplicate rows**
- **673 negative values in `Demand_Forecast`**
- inconsistent mapping between **`Product_ID` and `Category`**
- inconsistent mapping between **`Store_ID` and `Region`**

These issues were addressed during the cleaning and standardization stage.

---

## 7. Cleaning and Standardization Work

To make the data analysis-ready, the following actions were performed:

- validated row-level completeness
- checked duplicate records
- flagged invalid numeric values
- isolated negative forecast values
- standardized product category mapping
- standardized regional mapping
- created a cleaned working table for downstream analysis

---

## 8. Final Working Tables Used in the Project

### `tbl_raw`
Raw audited source table.

### `tbl_product_map`
Lookup table used to standardize the mapping from `Product_ID` to final category.

### `tbl_store_map`
Lookup table used to standardize the mapping from `Store_ID` to final region.

### `tbl_clean`
Final cleaned and analysis-ready table used for KPI building, diagnosis, and dashboarding.

---

## 9. Additional Cleaned / Derived Fields

The cleaned table included standardized and validation-related fields such as:

- `Category_Clean`
- `Region_Clean`
- `Demand_Forecast_Clean`
- `Row_Key`
- `Duplicate_Flag`
- `Inventory_Invalid_Flag`
- `UnitsSold_Invalid_Flag`
- `UnitsOrdered_Invalid_Flag`
- `DemandForecast_Invalid_Flag`
- `Price_Invalid_Flag`
- `Discount_Invalid_Flag`
- `HolidayPromo_Invalid_Flag`
- `CompetitorPrice_Invalid_Flag`
- `Negative_Forecast_Flag`
- `Category_Mismatch_Flag`
- `Region_Mismatch_Flag`

These fields were used to improve traceability and support cleaner downstream analysis.

---

## 10. How the Dataset Was Used in the Project

The dataset was used for:

- data audit and validation
- KPI design and business measurement
- segmentation of inventory patterns
- diagnosis of inventory policy behavior
- assessment of reorder / safety stock / lead-time signals
- business impact estimation
- Power BI dashboard development
- business recommendations and decision storytelling

---

## 11. Analytical Context

This dataset supports a **policy assessment** project, not a full mathematical optimization model.

The analysis focuses on identifying whether the observed inventory behavior suggests:

- avoidable excess stock
- operational burden from replenishment behavior
- review-priority SKU-store combinations
- concentration of impact across categories and regions

---

## 12. Important Interpretation Note

The strongest supported conclusion from this dataset is an **excess inventory and operational burden** story, rather than a broad service-risk story.

This means the project should be interpreted as an inventory policy review and business diagnosis exercise, not as proof of severe understock failure.

---

## 13. Limitations

Some limitations of the dataset and analysis context:

- negative forecast values required cleaning treatment
- category and region labels required remapping
- several diagnostic dimensions showed weak differentiation because ordering behavior was broadly continuous
- service-risk evidence was limited compared with excess-stock evidence

These limitations were considered in the final interpretation of results.
