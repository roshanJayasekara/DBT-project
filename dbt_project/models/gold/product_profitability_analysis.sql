-- models/product_profitability_analysis.sql
-- Product Profitability & Category Contribution Analysis using dbt_utils

WITH sales AS (
    SELECT
        sales_id,
        product_sk,
        customer_sk,
        unit_price,
        quantity,
        net_amount,
        cost_price,
        date_sk,
        unit_price * quantity AS gross_revenue,
        cost_price * quantity AS total_cost
    FROM {{ ref('bronze_sales') }}
),

products AS (
    SELECT
        product_sk,
        product_name,
        category,
        subcategory
    FROM {{ ref('bronze_product') }}
),

date_dim AS (
    SELECT
        date_sk,
        date AS sale_date,
        year,
        month
    FROM {{ ref('bronze_date') }}
),

product_summary AS (
    SELECT
        p.product_sk,
        p.product_name,
        p.category,
        p.subcategory,
        COUNT(DISTINCT s.sales_id) AS total_orders,
        SUM(s.quantity) AS total_units,
        SUM(s.net_amount) AS total_revenue,
        SUM(s.total_cost) AS total_cost,
        SUM(s.net_amount - s.total_cost) AS total_profit,
        ROUND(
            {{ dbt_utils.safe_divide('SUM(s.net_amount - s.total_cost)', 'SUM(s.net_amount)') }} * 100,
            2
        ) AS profit_margin_pct,
        MIN(d.sale_date) AS first_sale,
        MAX(d.sale_date) AS last_sale
    FROM sales s
    LEFT JOIN products p ON s.product_sk = p.product_sk
    LEFT JOIN date_dim d ON s.date_sk = d.date_sk
    GROUP BY 1,2,3,4
),

category_totals AS (
    SELECT
        category,
        SUM(total_profit) AS category_profit,
        SUM(total_revenue) AS category_revenue
    FROM product_summary
    GROUP BY 1
)

SELECT
    ps.product_sk,
    ps.product_name,
    ps.category,
    ps.subcategory,
    ps.total_orders,
    ps.total_units,
    ROUND(ps.total_revenue, 2) AS total_revenue,
    ROUND(ps.total_cost, 2) AS total_cost,
    ROUND(ps.total_profit, 2) AS total_profit,
    ps.profit_margin_pct,
    ROUND(
        {{ dbt_utils.safe_divide('ps.total_profit', 'ct.category_profit') }} * 100,
        2
    ) AS category_profit_share,
    ROUND(
        {{ dbt_utils.safe_divide('ps.total_revenue', 'ct.category_revenue') }} * 100,
        2
    ) AS category_revenue_share,
    CASE
        WHEN ps.profit_margin_pct >= 40 THEN 'High Margin'
        WHEN ps.profit_margin_pct >= 20 THEN 'Moderate Margin'
        WHEN ps.profit_margin_pct > 0 THEN 'Low Margin'
        ELSE 'Negative Margin'
    END AS margin_category,
    ps.first_sale,
    ps.last_sale,
    DATEDIFF(ps.last_sale, ps.first_sale) AS active_days,
    CASE
        WHEN ps.total_profit >= 10000 THEN 'Top Performer'
        WHEN ps.total_profit >= 5000 THEN 'High Performer'
        WHEN ps.total_profit >= 1000 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS performance_tier,
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), ps.last_sale) <= 30 THEN 'Active'
        WHEN DATEDIFF(CURRENT_DATE(), ps.last_sale) <= 90 THEN 'Declining'
        ELSE 'Inactive'
    END AS product_status
FROM product_summary ps
LEFT JOIN category_totals ct ON ps.category = ct.category
ORDER BY ps.total_profit DESC
