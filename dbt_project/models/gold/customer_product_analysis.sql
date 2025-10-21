-- models/customer_product_analysis.sql
-- Customer Purchase & Product Contribution Analysis using dbt_utils

WITH sales AS (
    SELECT
        {{ dbt_utils.star(from=ref('bronze_sales')) }},
        unit_price * quantity AS gross_amount
    FROM {{ ref('bronze_sales') }}
),

products AS (
    SELECT
        {{ dbt_utils.star(from=ref('bronze_product')) }}
    FROM {{ ref('bronze_product') }}
),

date_dim AS (
    SELECT
        {{ dbt_utils.star(from=ref('bronze_date')) }}
    FROM {{ ref('bronze_date') }}
),

customer_metrics AS (
    SELECT
        s.customer_sk,
        COUNT(DISTINCT s.sales_id) AS total_orders,
        SUM(s.quantity) AS total_units_purchased,
        SUM(s.net_amount) AS total_spent,
        AVG(s.net_amount) AS avg_order_value,
        MIN(d.date) AS first_purchase,
        MAX(d.date) AS last_purchase,
        DATEDIFF(MAX(d.date), MIN(d.date)) AS active_days
    FROM sales s
    LEFT JOIN date_dim d ON s.date_sk = d.date_sk
    GROUP BY s.customer_sk
),

product_metrics AS (
    SELECT
        p.product_sk,
        p.product_name,
        p.category,
        SUM(s.net_amount) AS total_revenue,
        SUM(s.quantity) AS total_units_sold,
        ROUND({{ dbt_utils.safe_divide('SUM(s.net_amount)', 'SUM(s.quantity)') }}, 2) AS revenue_per_unit,
        COUNT(DISTINCT s.customer_sk) AS unique_customers
    FROM sales s
    LEFT JOIN products p ON s.product_sk = p.product_sk
    GROUP BY p.product_sk, p.product_name, p.category
)

SELECT
    c.customer_sk,
    c.total_orders,
    c.total_units_purchased,
    c.total_spent,
    ROUND(c.avg_order_value, 2) AS avg_order_value,
    c.first_purchase,
    c.last_purchase,
    c.active_days,
    pm.product_sk,
    pm.product_name,
    pm.category,
    pm.total_revenue AS product_revenue,
    pm.total_units_sold AS product_units_sold,
    pm.unique_customers AS product_unique_customers,
    pm.revenue_per_unit
FROM customer_metrics c
LEFT JOIN sales s ON c.customer_sk = s.customer_sk
LEFT JOIN product_metrics pm ON s.product_sk = pm.product_sk
ORDER BY c.total_spent DESC, pm.total_revenue DESC;
