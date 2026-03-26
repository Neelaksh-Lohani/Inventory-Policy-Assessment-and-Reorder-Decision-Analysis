# Inventory Policy Assessment and Reorder Decision Analysis

A retail inventory analytics project focused on identifying whether current inventory behavior is creating **service risk** or **excess stock / working-capital pressure**, and recommending where inventory policy should be reviewed first.

---

## 1. Project Overview

Inventory decisions affect both **customer service** and **business cost**.

- If inventory is too low, the business may lose sales.
- If inventory is too high, cash gets locked into stock and operational burden increases.

This project analyzes retail inventory data across **100 SKU-store combinations** to assess whether the current inventory policy is balanced or whether certain product-location combinations are carrying avoidable excess stock.

The final conclusion from the analysis was that the stronger issue is **excess inventory and replenishment inefficiency**, not broad stockout risk.

---

## 2. Business Objective

The main objective of this project was to answer the following question:

**Is the business mainly facing a stock shortage problem or an excess inventory problem, and where should inventory policy be reviewed first?**

To answer this, the analysis focused on:

- inventory behavior across products and stores
- demand and forecast patterns
- operational burden from current replenishment behavior
- high-priority SKU-store combinations needing policy review

---

## 3. Dataset Summary

The dataset contains daily retail inventory and sales observations with the following working schema:

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

### Final cleaned model tables

- `tbl_raw` → raw audited source data
- `tbl_product_map` → Product_ID to cleaned category mapping
- `tbl_store_map` → Store_ID to cleaned region mapping
- `tbl_clean` → cleaned analysis-ready dataset

---

## 4. Data Audit and Cleaning

The data audit identified the following issues:

- **73,100 rows** in total
- no missing values
- no duplicate rows
- **673 negative demand forecast rows**
- inconsistent raw mapping between **Product_ID and Category**
- inconsistent raw mapping between **Store_ID and Region**

### Cleaning actions performed

- validated missing values and duplicates
- flagged invalid numeric values
- isolated negative forecast records
- standardized category mapping using `tbl_product_map`
- standardized region mapping using `tbl_store_map`
- created an analysis-ready cleaned table (`tbl_clean`)

### Key cleaned fields added

- `Category_Clean`
- `Region_Clean`
- `Demand_Forecast_Clean`
- quality flags such as:
  - `Duplicate_Flag`
  - `Inventory_Invalid_Flag`
  - `UnitsSold_Invalid_Flag`
  - `UnitsOrdered_Invalid_Flag`
  - `DemandForecast_Invalid_Flag`
  - `Negative_Forecast_Flag`
  - `Category_Mismatch_Flag`
  - `Region_Mismatch_Flag`

---

## 5. Project Workflow

This project followed the workflow below:

1. Define business problem and decision objective  
2. Audit and clean the data  
3. Define KPI framework  
4. Segment inventory into meaningful groups  
5. Diagnose current inventory policy performance  
6. Assess reorder point / safety stock / lead-time behavior  
7. Quantify expected business impact  
8. Build decision-support dashboard in Power BI  
9. Develop business insights and recommendations  
10. Package the project into a portfolio-ready case study  

> Note: Scenario and sensitivity analysis was intentionally skipped in this version of the project to keep the scope focused on policy assessment and business diagnosis.

---

## 6. Tools Used

- **Excel** → data audit, cleaning support, logic building
- **SQL** → structured analysis and query-based validation
- **Power BI** → KPI tracking, dashboarding, storytelling
- **DAX** → measures and KPI calculations
- **GitHub** → project documentation and portfolio hosting

---

## 7. KPI Framework

The analysis was built around a KPI structure designed to evaluate both inventory position and business impact.

### Core KPIs used

- Total Units Sold
- SKU-Store Combinations
- Primary Impact Units
- Operational Burden Items
- High Priority Items
- Excess Sales Share
- Monthly Units Sold Trend
- Monthly Forecast Accuracy (WAPE)

### Analytical intent of the KPI framework

The KPI design was used to separate:

- broad sales scale
- operational burden from current replenishment behavior
- high-priority combinations requiring review
- signs of excess stock versus true service-risk exposure

---

## 8. Analytical Approach

The project was designed as a **policy assessment** rather than a mathematical optimization model.

That distinction matters.

This project does **not** claim to solve an optimal reorder policy with formal cost constraints. Instead, it evaluates whether the existing inventory and replenishment behavior appears operationally sound or whether it shows signs of avoidable excess stock and review-worthy triggers.

### Main analytical layers

- inventory performance diagnosis
- replenishment behavior assessment
- review-priority classification
- business impact interpretation
- dashboard-based decision support

---

## 9. Key Findings

### 1. Excess inventory is the main issue
The data does not strongly support a broad stockout or service-risk story. The stronger pattern is excess stock and working-capital pressure.

### 2. Replenishment behavior appears overly frequent
A large share of combinations showed signs of operational burden, suggesting replenishment may be happening too frequently or too broadly.

### 3. Only a subset of combinations requires urgent attention
This is not a full-portfolio failure. The analysis identified a smaller group of high-priority combinations for immediate review.

### 4. Impact is concentrated, not evenly distributed
The problem is concentrated in specific regions and categories rather than spread evenly across the business.

### 5. The strongest business case is cost and cash efficiency
The analysis supports a stronger narrative around reducing excess stock, freeing working capital, and improving replenishment discipline than around rescuing service levels.

---

## 10. Quantified Findings

### Headline metrics

- **10M** total units sold
- **100** SKU-store combinations
- **281.11K** primary impact units
- **77** operational burden items
- **21** high-priority items
- **22.84%** excess sales share

### Region-level concentration
- **East** → 198.22K primary impact units (**70.52%**)
- **South** → 47.13K (**16.76%**)
- **West** → 35.76K (**12.72%**)

### Category-level concentration
- **Groceries** → 107K primary impact units
- **Clothing** → 50K
- **Furniture** → 47K

### Trigger behavior findings
- **Trigger Too Early / Excessive** → 23
- **Trigger Broadly Reasonable** → 77

---

## 11. Dashboard and Storytelling Output

The final dashboard was built as an **Executive Overview** page in Power BI.

### Dashboard focus areas

- headline KPI summary
- monthly units sold trend
- monthly forecast accuracy (WAPE)
- priority mix by region
- impact concentration by region
- impact concentration by category
- sales distribution by category

### Dashboard Preview

> Replace the path below with your actual image path inside the GitHub repo.

https://github.com/Neelaksh-Lohani/Inventory-Policy-Assessment-and-Reorder-Decision-Analysis/blob/main/Dashboard.png?raw=true

### Why only one dashboard was used

A second diagnostic dashboard was considered but intentionally skipped because the dataset did not produce enough additional differentiated insight to justify another full page of visuals.

Instead, the project uses:

- one executive dashboard
- a focused recommendations section
- a short presentation deck for business storytelling

This made the final output more concise and more useful for non-technical readers.

---

## 12. Business Insights and Recommendations

### Insight 1
**The business is carrying excess inventory in selected combinations rather than facing broad stock shortage risk.**

**Recommendation:** Review reorder settings for identified high-priority items instead of increasing inventory buffers across the full portfolio.

### Insight 2
**Operational burden is widespread, suggesting overly frequent replenishment behavior.**

**Recommendation:** Reassess ordering cadence and minimum-order logic for combinations showing repeated operational burden.

### Insight 3
**A smaller set of combinations drives the real problem.**

**Recommendation:** Use a tiered review approach:
- immediate action for high-priority items
- monitor medium cases
- maintain stable combinations

### Insight 4
**The East region carries the largest concentration of impact.**

**Recommendation:** Start detailed inventory policy review in the East before expanding to lower-impact regions.

### Insight 5
**Groceries, Clothing, and Furniture should be reviewed first.**

**Recommendation:** Prioritize the highest-impact categories to improve working-capital efficiency faster.

---

## 13. Final Conclusion

This project concludes that the current inventory environment is more affected by **excess stock exposure and replenishment inefficiency** than by broad service-risk failure.

The most practical business response is **selective policy recalibration**, starting with the highest-impact SKU-store combinations, especially in the East region and the top impact categories.

The expected business benefit would be:

- lower excess inventory
- improved cash efficiency
- reduced operational burden
- more disciplined replenishment decisions

---

## 14. Skills Demonstrated

This project demonstrates:

- data auditing and data cleaning
- business KPI design
- inventory and replenishment analysis
- SQL-based validation and querying
- Power BI dashboard development
- DAX measure creation
- business insight generation
- recommendation framing for decision-makers
- portfolio storytelling

---

## 15. Limitations

This project has some important limitations:

- it is a policy assessment project, not a full optimization model
- service-risk evidence in the dataset is limited
- some diagnostic dimensions showed weak differentiation because ordering behavior was broadly continuous
- the final month in the monthly trend may require cleanup for portfolio-perfect presentation quality if the source period is incomplete

These limitations were considered while framing the final conclusions.

---

## 16. Next Improvements

Possible future improvements:

- build a proper reorder simulation model
- test sensitivity to lead time and demand volatility
- add service-level target assumptions
- estimate working-capital release in monetary value
- extend SQL analysis and automate KPI generation

---

## 17. About This Project

This project was created as part of a portfolio focused on **Business Operations and Supply Chain Analytics**, with an emphasis on turning raw transactional data into business decisions that are understandable to both technical and non-technical stakeholders.
