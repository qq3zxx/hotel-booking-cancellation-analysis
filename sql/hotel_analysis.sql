-- =============================================================
-- Hotel Booking Cancellation Analysis - SQL Queries
-- Database: SQLite (hotel.db) | Table: bookings
-- =============================================================


-- Q1: Overall KPIs
SELECT
    COUNT(*)                                        AS total_bookings,
    SUM(is_canceled)                                AS canceled_bookings,
    ROUND(AVG(is_canceled) * 100, 2)                AS cancel_rate_pct,
    ROUND(SUM(revenue), 0)                          AS total_expected_revenue,
    ROUND(SUM(lost_revenue), 0)                     AS total_lost_revenue,
    ROUND(SUM(lost_revenue) * 100.0 / SUM(revenue), 2) AS lost_revenue_pct
FROM bookings;


-- Q2: Performance by hotel type
SELECT
    hotel,
    COUNT(*)                          AS bookings,
    SUM(is_canceled)                  AS canceled,
    ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct,
    ROUND(AVG(adr), 2)                AS avg_daily_rate,
    ROUND(SUM(lost_revenue), 0)       AS lost_revenue
FROM bookings
GROUP BY hotel
ORDER BY lost_revenue DESC;


-- Q3: Lost revenue by market segment + share of total loss
SELECT
    market_segment,
    COUNT(*)                          AS bookings,
    ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct,
    ROUND(SUM(lost_revenue), 0)       AS lost_revenue,
    ROUND(SUM(lost_revenue) * 100.0 / SUM(SUM(lost_revenue)) OVER (), 1) AS pct_of_total_loss
FROM bookings
GROUP BY market_segment
HAVING COUNT(*) >= 100
ORDER BY lost_revenue DESC;


-- Q4: Cancellation by lead time bucket (CASE WHEN)
SELECT
    CASE
        WHEN lead_time <= 7   THEN '1. 0-7 days'
        WHEN lead_time <= 30  THEN '2. 8-30 days'
        WHEN lead_time <= 90  THEN '3. 31-90 days'
        WHEN lead_time <= 180 THEN '4. 91-180 days'
        WHEN lead_time <= 365 THEN '5. 181-365 days'
        ELSE '6. 365+ days'
    END                               AS lead_time_bucket,
    COUNT(*)                          AS bookings,
    ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct,
    ROUND(SUM(lost_revenue), 0)       AS lost_revenue
FROM bookings
GROUP BY lead_time_bucket
ORDER BY lead_time_bucket;


-- Q5: Investigating non-refundable deposits (where do they come from?)
SELECT
    market_segment,
    COUNT(*)                          AS bookings,
    ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct,
    ROUND(AVG(lead_time), 0)          AS avg_lead_time
FROM bookings
WHERE deposit_type = 'Non Refund'
GROUP BY market_segment
ORDER BY bookings DESC;


-- Q6: Top 10 countries by cancellation rate (min 1,000 bookings)
SELECT
    country,
    COUNT(*)                          AS bookings,
    SUM(is_canceled)                  AS canceled,
    ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct
FROM bookings
GROUP BY country
HAVING COUNT(*) >= 1000
ORDER BY cancel_rate_pct DESC
LIMIT 10;


-- Q7: Monthly trend with month-over-month change and running total (CTE + LAG + running SUM)
WITH monthly AS (
    SELECT
        strftime('%Y-%m', arrival_date)   AS year_month,
        COUNT(*)                          AS bookings,
        ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct,
        ROUND(SUM(lost_revenue), 0)       AS lost_revenue
    FROM bookings
    GROUP BY year_month
)
SELECT
    year_month,
    bookings,
    cancel_rate_pct,
    lost_revenue,
    ROUND(cancel_rate_pct - LAG(cancel_rate_pct) OVER (ORDER BY year_month), 1) AS rate_change_vs_prev_month,
    SUM(lost_revenue) OVER (ORDER BY year_month)                                AS cumulative_lost_revenue
FROM monthly
ORDER BY year_month;


-- Q8: Rank market segments by cancellation risk within each hotel (RANK + PARTITION BY)
WITH seg AS (
    SELECT
        hotel,
        market_segment,
        COUNT(*)                          AS bookings,
        ROUND(AVG(is_canceled) * 100, 1)  AS cancel_rate_pct
    FROM bookings
    GROUP BY hotel, market_segment
    HAVING COUNT(*) >= 100
)
SELECT
    hotel,
    market_segment,
    bookings,
    cancel_rate_pct,
    RANK() OVER (PARTITION BY hotel ORDER BY cancel_rate_pct DESC) AS risk_rank
FROM seg
ORDER BY hotel, risk_rank;


-- Q9: Booking risk profile (business rule built from the EDA insights)
SELECT
    CASE
        WHEN lead_time > 90 AND total_of_special_requests = 0 AND is_repeated_guest = 0 THEN 'High Risk'
        WHEN lead_time > 30 OR total_of_special_requests = 0 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END                                                AS risk_profile,
    COUNT(*)                                           AS bookings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_bookings,
    ROUND(AVG(is_canceled) * 100, 1)                   AS cancel_rate_pct,
    ROUND(SUM(lost_revenue), 0)                        AS lost_revenue
FROM bookings
GROUP BY risk_profile
ORDER BY cancel_rate_pct DESC;


-- Q10: Canceled vs kept bookings - price, length of stay, lead time
SELECT
    CASE WHEN is_canceled = 1 THEN 'Canceled' ELSE 'Not Canceled' END AS status,
    COUNT(*)                     AS bookings,
    ROUND(AVG(adr), 2)           AS avg_daily_rate,
    ROUND(AVG(total_nights), 2)  AS avg_nights,
    ROUND(AVG(lead_time), 0)     AS avg_lead_time
FROM bookings
GROUP BY status;
