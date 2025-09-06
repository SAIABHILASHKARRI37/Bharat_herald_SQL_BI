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
