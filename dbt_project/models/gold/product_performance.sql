-- Product Performance & Profitability Analysis
WITH sales as
(
    SELECT
        sales_id,
        product_sk,
        customer_sk,
        net_amount,
        unit_price,
        {{multiply('unit_price', 'quantity')}} as gross_amount,
        quantity,
        payment_method,
        date_sk
    FROM
        {{ ref('bronze_sales') }}
),

products as
(
    SELECT
        product_sk,
        product_name,
        category
    FROM
        {{ ref('bronze_product') }}
),

date_dim as
(
    SELECT
        date_sk,
        date as sale_date,
        year,
        month,
        quarter
    FROM
        {{ ref('bronze_date') }}
),

product_metrics as
(
    SELECT
        products.product_sk,
        products.product_name,
        products.category,
        COUNT(DISTINCT sales.sales_id) as total_orders,
        COUNT(DISTINCT sales.customer_sk) as unique_customers,
        SUM(sales.quantity) as total_units_sold,
        SUM(sales.net_amount) as total_revenue,
        SUM(sales.gross_amount) as total_gross_revenue,
        SUM(sales.gross_amount - sales.net_amount) as total_discount_given,
        AVG(sales.net_amount) as avg_order_value,
        AVG(sales.unit_price) as avg_unit_price,
        MIN(date_dim.sale_date) as first_sale_date,
        MAX(date_dim.sale_date) as last_sale_date,
        DATEDIFF(MAX(date_dim.sale_date), MIN(date_dim.sale_date)) as days_in_catalog
    FROM
        sales
    LEFT JOIN
        products on sales.product_sk = products.product_sk
    LEFT JOIN
        date_dim on sales.date_sk = date_dim.date_sk
    GROUP BY
        products.product_sk,
        products.product_name,
        products.category
),

category_totals as
(
    SELECT
        category,
        SUM(total_revenue) as category_revenue
    FROM
        product_metrics
    GROUP BY
        category
)

SELECT
    pm.product_sk,
    pm.product_name,
    pm.category,
    pm.total_orders,
    pm.unique_customers,
    pm.total_units_sold,
    ROUND(pm.total_revenue, 2) as total_revenue,
    ROUND(pm.total_gross_revenue, 2) as total_gross_revenue,
    ROUND(pm.total_discount_given, 2) as total_discount_given,
    ROUND((pm.total_discount_given / NULLIF(pm.total_gross_revenue, 0)) * 100, 2) as discount_percentage,
    ROUND(pm.avg_order_value, 2) as avg_order_value,
    ROUND(pm.avg_unit_price, 2) as avg_unit_price,
    ROUND(pm.total_revenue / NULLIF(pm.total_units_sold, 0), 2) as revenue_per_unit,
    ROUND(pm.total_revenue / NULLIF(pm.unique_customers, 0), 2) as revenue_per_customer,
    ROUND((pm.total_revenue / NULLIF(ct.category_revenue, 0)) * 100, 2) as category_revenue_share,
    pm.first_sale_date,
    pm.last_sale_date,
    pm.days_in_catalog,
    CASE
        WHEN pm.days_in_catalog > 0 
        THEN ROUND(pm.total_revenue / pm.days_in_catalog, 2)
        ELSE 0
    END as avg_daily_revenue,
    CASE 
        WHEN pm.total_revenue >= 10000 THEN 'Top Performer'
        WHEN pm.total_revenue >= 5000 THEN 'High Performer'
        WHEN pm.total_revenue >= 1000 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END as performance_tier,
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), pm.last_sale_date) <= 30 THEN 'Active'
        WHEN DATEDIFF(CURRENT_DATE(), pm.last_sale_date) <= 90 THEN 'Declining'
        ELSE 'Inactive'
    END as product_status
FROM
    product_metrics pm
LEFT JOIN
    category_totals ct ON pm.category = ct.category
ORDER BY
    pm.total_revenue DESC