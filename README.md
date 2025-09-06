# Bharat Herald Survival Analysis

### Author: Sai Abhilash  
### Domain: Media & Publishing  
### Function: Strategy & Data Analytics  

---

## 📌 Problem Statement
Bharat Herald, a 70-year-old legacy newspaper, is facing an existential crisis in the **post-COVID digital era**.  
Between **2019–2024**, print circulation dropped from 1.2M to under 560K.  
While competitors embraced **mobile-first, WhatsApp delivery, and subscription bundles**, Bharat Herald’s digital pilot failed.  

This project analyzes **operational and financial data (2019–2024)** to:  
- Quantify what went wrong  
- Identify recovery opportunities  
- Recommend a phased roadmap for digital transformation  

---

## 📊 Business Requests & SQL Solutions

---

### 1️⃣ Biggest Monthly Net Circulation Drops
```sql
WITH cs AS (
  SELECT
    dc.city AS city_name,
    fps.normalized_month AS month,
    fps.month_date,
    CAST(fps.net_circulation AS SIGNED) AS net_circulation
  FROM fact_print_sales fps
  JOIN dim_city dc ON fps.city_id = dc.city_id
  WHERE fps.month_date BETWEEN '2019-01-01' AND '2024-12-31'
),
city_ordered AS (
  SELECT
    city_name,
    month,
    month_date,
    net_circulation,
    LAG(net_circulation) OVER (PARTITION BY city_name ORDER BY month_date) AS prev_net_circulation
  FROM cs
),
city_drops AS (
  SELECT
    city_name,
    month,
    net_circulation,
    prev_net_circulation,
    (prev_net_circulation - net_circulation) AS drop_amount
  FROM city_ordered
  WHERE prev_net_circulation IS NOT NULL
    AND (prev_net_circulation - net_circulation) > 0
)
SELECT
  city_name,
  month AS month_yyyy_mm,
  prev_net_circulation,
  net_circulation,
  drop_amount
FROM city_drops
ORDER BY drop_amount DESC
LIMIT 3;
```
### 2️⃣ Yearly Revenue Concentration by Category
```sql
WITH yearly_revenue AS (
  SELECT
    YEAR(far.date) AS year,
    dac.category_name,
    SUM(far.ad_revenue_in_inr) AS category_revenue
  FROM fact_ad_revenue far
  JOIN dim_ad_category dac ON far.ad_category_id = dac.ad_category_id
  GROUP BY YEAR(far.date), dac.category_name
),
total_revenue AS (
  SELECT
    year,
    SUM(category_revenue) AS total_revenue_year
  FROM yearly_revenue
  GROUP BY year
)
SELECT
  yr.year,
  yr.category_name,
  yr.category_revenue,
  tr.total_revenue_year,
  ROUND(yr.category_revenue * 100.0 / tr.total_revenue_year, 2) AS pct_of_year_total
FROM yearly_revenue yr
JOIN total_revenue tr ON yr.year = tr.year
WHERE (yr.category_revenue * 1.0 / tr.total_revenue_year) > 0.5
ORDER BY yr.year, pct_of_year_total DESC;
