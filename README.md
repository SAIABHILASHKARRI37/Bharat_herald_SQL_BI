# Media Business SQL Requests  

This project contains SQL solutions for different business requests using datasets like:  
- `fact_print_sales`  
- `fact_ad_revenue`  
- `fact_city_readiness`  
- `fact_digital_pilot`  
- `dim_city`  
- `dim_ad_category`  

All queries are written in **MySQL**.  

---

## Business Request 1: Monthly Circulation Drop Check  

**Requirement:**  
Generate a report showing the top 3 months (2019–2024) where any city recorded the sharpest month-over-month decline in `net_circulation`.  

**Fields:**  
- city_name  
- month (YYYY-MM)  
- net_circulation  

**SQL Solution:**  

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

## Business Request – 2: Yearly Revenue Concentration by Category 
Identify ad categories that contributed > 50% of total yearly ad revenue. 
Fields: 
• year 
• category_name 
• category_revenue  
• total_revenue_year  
• pct_of_year_total
