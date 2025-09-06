-- 1)
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

-- 2
-- 2
WITH yearly_totals AS (
    SELECT 
        year,
        SUM(ad_revenue_in_inr) AS total_revenue_year
    FROM fact_ad_revenue
    GROUP BY year
),
category_revenue AS (
    SELECT 
        f.year,
        d.standard_ad_category AS category_name,
        SUM(f.ad_revenue_in_inr) AS category_revenue,
        y.total_revenue_year,
        ROUND(
            (SUM(f.ad_revenue_in_inr) * 100.0 / y.total_revenue_year), 2
        ) AS pct_of_year_total
    FROM fact_ad_revenue f
    JOIN dim_ad_category d 
        ON f.ad_category = d.ad_category_id
    JOIN yearly_totals y
        ON f.year = y.year
    GROUP BY f.year, d.standard_ad_category, y.total_revenue_year
),
ranked AS (
    SELECT 
        year,
        category_name,
        category_revenue,
        total_revenue_year,
        pct_of_year_total,
        RANK() OVER (PARTITION BY year ORDER BY category_revenue DESC) AS category_rank
    FROM category_revenue
)
SELECT 
    year,
    category_name,
    category_revenue,
    total_revenue_year,
    pct_of_year_total,
    CASE 
        WHEN pct_of_year_total > 50 THEN 'Yes'
        ELSE 'No'
    END AS exceeds_50_pct
FROM ranked
WHERE category_rank = 1
ORDER BY year;

-- 3)

-- 3)
WITH city_totals_2024 AS (
    SELECT 
        f.city_id,
        SUM(f.`Copies Sold` + f.copies_returned) AS copies_printed_2024,
        SUM(f.net_circulation) AS net_circulation_2024
    FROM fact_print_sales f
    WHERE YEAR(f.month_date) = 2024
    GROUP BY f.city_id
),
city_efficiency AS (
    SELECT 
        c.city,
        t.copies_printed_2024,
        t.net_circulation_2024,
        ROUND(
            (t.net_circulation_2024 * 1.0 / NULLIF(t.copies_printed_2024,0)), 4
        ) AS efficiency_ratio
    FROM city_totals_2024 t
    JOIN dim_city c
        ON t.city_id = c.city_id
),
ranked AS (
    SELECT 
        city,
        copies_printed_2024,
        net_circulation_2024,
        efficiency_ratio,
        RANK() OVER (ORDER BY efficiency_ratio DESC) AS efficiency_rank_2024
    FROM city_efficiency
)
SELECT 
    city,
    copies_printed_2024,
    net_circulation_2024,
    efficiency_ratio,
    efficiency_rank_2024
FROM ranked
WHERE efficiency_rank_2024 <= 5
ORDER BY efficiency_rank_2024;

-- 5
WITH print_sales AS (
    SELECT 
        c.city,
        YEAR(f.month_date) AS year,
        SUM(f.net_circulation) AS yearly_net_circulation
    FROM fact_print_sales f
    JOIN dim_city c ON f.city_id = c.city_id
    WHERE YEAR(f.month_date) BETWEEN 2019 AND 2024
    GROUP BY c.city_name, YEAR(f.month_date)
),
ad_revenue AS (
    SELECT 
        c.city,
        f.year,
        SUM(f.ad_revenue_in_inr) AS yearly_ad_revenue
    FROM fact_ad_revenue f
    JOIN dim_city c ON f.edition_id = c.city_id   -- assuming edition_id links to city_id; adjust if wrong
    WHERE f.year BETWEEN 2019 AND 2024
    GROUP BY c.city_name, f.year
),
combined AS (
    SELECT 
        p.city,
        p.year,
        p.yearly_net_circulation,
        a.yearly_ad_revenue
    FROM print_sales p
    JOIN ad_revenue a 
        ON p.city = a.city
       AND p.year = a.year
),
check_decline AS (
    SELECT 
        city,
        MIN(yearly_net_circulation) < MAX(yearly_net_circulation) AS has_decline_print,
        MIN(yearly_ad_revenue) < MAX(yearly_ad_revenue) AS has_decline_ad,
        COUNT(DISTINCT year) AS year_count
    FROM combined
    GROUP BY city
    HAVING year_count = 6 -- must have all years 2019–2024
)
SELECT 
    c.city,
    'Yes' AS is_declining_print,
    'Yes' AS is_declining_ad_revenue,
    'Yes' AS is_declining_both
FROM check_decline c
WHERE has_decline_print = TRUE
  AND has_decline_ad = TRUE;


-- 4)
WITH q1 AS (
    SELECT 
        f.city_id,
        f.internet_penetration AS internet_rate_q1_2021
    FROM fact_city_readiness f
    WHERE f.year = 2021 AND f.quarter_num = 1
),
q4 AS (
    SELECT 
        f.city_id,
        f.internet_penetration AS internet_rate_q4_2021
    FROM fact_city_readiness f
    WHERE f.year = 2021 AND f.quarter_num= 4
),
delta AS (
    SELECT 
        c.city,
        q1.internet_rate_q1_2021,
        q4.internet_rate_q4_2021,
        ROUND((q4.internet_rate_q4_2021 - q1.internet_rate_q1_2021), 3) AS delta_internet_rate
    FROM q1
    JOIN q4 ON q1.city_id = q4.city_id
    JOIN dim_city c ON q1.city_id = c.city_id
)
SELECT *
FROM delta
ORDER BY delta_internet_rate DESC;

-- 6 City Readiness (2021)

WITH readiness AS (
    SELECT 
        cr.city_id,
        cr.year,
        (AVG(cr.smartphone_penetration) 
         + AVG(cr.internet_penetration) 
         + AVG(cr.literacy_rate)) / 3.0 AS readiness_score_2021,
        RANK() OVER (
            ORDER BY 
                (AVG(cr.smartphone_penetration) 
               + AVG(cr.internet_penetration) 
               + AVG(cr.literacy_rate)) / 3.0 DESC
        ) AS readiness_rank_desc
    FROM fact_city_readiness cr
    WHERE cr.year = 2021
    GROUP BY cr.city_id, cr.year
)
SELECT 
    dc.city AS city_name,
    ROUND(r.readiness_score_2021, 3) AS readiness_score_2021,
    r.readiness_rank_desc
FROM readiness r
JOIN dim_city dc ON r.city_id = dc.city_id
ORDER BY r.readiness_rank_desc
limit 5;

-- 6)Platform Engagement (2021)
WITH engagement AS (
    SELECT 
        dp.platform,
        SUM(dp.users_reached) AS engagement_metric_2021,
        RANK() OVER (ORDER BY SUM(dp.users_reached) ASC) AS engagement_rank_asc
    FROM fact_digital_pilot dp
    WHERE dp.launch_month BETWEEN '2021-01-01' AND '2021-12-31'
    GROUP BY dp.platform
)
SELECT 
    platform,
    engagement_metric_2021,
    engagement_rank_asc
FROM engagement
ORDER BY engagement_rank_asc;







-- 5 Print Decline Check (2019 → 2024)
WITH yearly_print AS (
    SELECT 
        dc.city AS city_name,
        YEAR(fs.month_date) AS year,
        SUM(fs.net_circulation) AS yearly_net_circulation
    FROM fact_print_sales fs
    JOIN dim_city dc ON fs.city_id = dc.city_id
    WHERE YEAR(fs.month_date) BETWEEN 2019 AND 2024
    GROUP BY dc.city, YEAR(fs.month_date)
),
trend AS (
    SELECT 
        city_name,
        year,
        yearly_net_circulation,
        CASE 
            WHEN yearly_net_circulation < LAG(yearly_net_circulation) OVER (PARTITION BY city_name ORDER BY year)
            THEN 1 ELSE 0 
        END AS decline_step
    FROM yearly_print
)
SELECT 
    city_name,
    CASE 
        WHEN COUNT(DISTINCT year) = 6 AND SUM(decline_step) = 5
        THEN 'Yes' ELSE 'No' 
    END AS is_declining_print
FROM trend
GROUP BY city_name;

-- 5
-- Step 1: Aggregate circulation per year per city
WITH yearly_circulation AS (
    SELECT 
        s.city_id,
        c.city,
        YEAR(s.month_date) AS year,
        SUM(s.net_circulation) AS yearly_net_circulation
    FROM fact_print_sales s
    JOIN dim_city c ON s.city_id = c.city_id
    WHERE YEAR(s.month_date) BETWEEN 2019 AND 2024
    GROUP BY s.city_id, c.city, YEAR(s.month_date)
)

-- Step 2: Build the trend string for easy visual check
SELECT 
    city_id,
    city,
    GROUP_CONCAT(CONCAT(year, ':', yearly_net_circulation) ORDER BY year SEPARATOR ' -> ') AS circulation_trend
FROM yearly_circulation
GROUP BY city_id, city;


-- 5
-- Step 1: Aggregate ad revenue per year per city
WITH yearly_revenue AS (
    SELECT 
        c.city_id,
        c.city,
        r.year,
        SUM(r.ad_revenue_in_inr) AS yearly_ad_revenue
    FROM fact_ad_revenue r
    JOIN fact_print_sales s 
        ON r.edition_id = s.edition_id   -- bridge
    JOIN dim_city c 
        ON s.city_id = c.city_id
    WHERE r.year BETWEEN 2019 AND 2024
    GROUP BY c.city_id, c.city, r.year
)

-- Step 2: Build the trend string for easy visual check
SELECT 
    city_id,
    city,
    GROUP_CONCAT(CONCAT(year, ':', yearly_ad_revenue) ORDER BY year SEPARATOR ' -> ') AS revenue_trend
FROM yearly_revenue
GROUP BY city_id, city;


-- 5
-- Compare Circulation & Revenue (2019 vs 2024)

WITH circulation AS (
    SELECT 
        s.city_id,
        c.city AS city_name,
        YEAR(s.month_date) AS year,
        SUM(s.net_circulation) AS yearly_net_circulation
    FROM fact_print_sales s
    JOIN dim_city c ON s.city_id = c.city_id
    WHERE YEAR(s.month_date) IN (2019, 2024)
    GROUP BY s.city_id, c.city, YEAR(s.month_date)
),
circulation_comp AS (
    SELECT 
        city_name,
        MAX(CASE WHEN year = 2019 THEN yearly_net_circulation END) AS circulation_2019,
        MAX(CASE WHEN year = 2024 THEN yearly_net_circulation END) AS circulation_2024
    FROM circulation
    GROUP BY city_name
),
revenue AS (
    SELECT 
        c.city_id,
        c.city AS city_name,
        r.year,
        SUM(r.ad_revenue_in_inr) AS yearly_ad_revenue
    FROM fact_ad_revenue r
    JOIN fact_print_sales s ON r.edition_id = s.edition_id
    JOIN dim_city c ON s.city_id = c.city_id
    WHERE r.year IN (2019, 2024)
    GROUP BY c.city_id, c.city, r.year
),
revenue_comp AS (
    SELECT 
        city_name,
        MAX(CASE WHEN year = 2019 THEN yearly_ad_revenue END) AS revenue_2019,
        MAX(CASE WHEN year = 2024 THEN yearly_ad_revenue END) AS revenue_2024
    FROM revenue
    GROUP BY city_name
)

-- Final Combined Output
SELECT 
    c.city_name,
    circulation_2019,
    circulation_2024,
    CASE 
        WHEN circulation_2024 > circulation_2019 THEN 'Increase'
        WHEN circulation_2024 < circulation_2019 THEN 'Decrease'
        ELSE 'No Change'
    END AS circulation_trend,
    r.revenue_2019,
    r.revenue_2024,
    CASE 
        WHEN r.revenue_2024 > r.revenue_2019 THEN 'Increase'
        WHEN r.revenue_2024 < r.revenue_2019 THEN 'Decrease'
        ELSE 'No Change'
    END AS revenue_trend,
    CASE 
        WHEN circulation_2024 < circulation_2019 AND r.revenue_2024 < r.revenue_2019 
            THEN 'Both Declined'
        WHEN circulation_2024 > circulation_2019 AND r.revenue_2024 > r.revenue_2019 
            THEN 'Both Improved'
        ELSE 'Mixed Trend'
    END AS overall_trend
FROM circulation_comp c
JOIN revenue_comp r ON c.city_name = r.city_name
ORDER BY c.city_name;


