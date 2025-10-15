-- RFM Analysis (Recency, Frequency, Monetary)
WITH customer_rfm AS (
    SELECT
        customer_sk,
        DATEDIFF(CURRENT_DATE(), MAX(date_dim.date)) as recency_days,
        COUNT(DISTINCT sales.sales_id) as frequency,
        SUM(sales.net_amount) as monetary_value
    FROM {{ ref('bronze_sales') }} sales
    LEFT JOIN {{ ref('bronze_date') }} date_dim ON sales.date_sk = date_dim.date_sk
    GROUP BY customer_sk
)
SELECT
    customer_sk,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) as total_spent,
    CASE
        WHEN recency_days <= 30 AND frequency >= 5 THEN 'Champions'
        WHEN recency_days <= 60 AND frequency >= 3 THEN 'Loyal Customers'
        WHEN recency_days <= 30 AND frequency < 3 THEN 'Promising'
        WHEN recency_days > 90 AND frequency >= 5 THEN 'At Risk'
        WHEN recency_days > 180 THEN 'Lost'
        ELSE 'Regular'
    END as customer_segment
FROM customer_rfm
ORDER BY monetary_value DESC