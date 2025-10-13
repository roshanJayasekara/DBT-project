-- Customer Lifetime Value & Behavior Analysis
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

customer as
(
    SELECT
        customer_sk,
        first_name,
        gender
    FROM
        {{ ref('bronze_customer') }}
),


date_dim as
(
    SELECT
        date_sk,
        date as sale_date
    FROM
        {{ ref('bronze_date') }}
),

customer_metrics as
(
    SELECT
        sales.customer_sk,
        customer.first_name,
        customer.gender,
        COUNT(DISTINCT sales.sales_id) as total_transactions,
        SUM(sales.net_amount) as lifetime_value,
        AVG(sales.net_amount) as avg_transaction_value,
        SUM(sales.quantity) as total_items_purchased,
        MIN(date_dim.sale_date) as first_purchase_date,
        MAX(date_dim.sale_date) as last_purchase_date,
        DATEDIFF(MAX(date_dim.sale_date), MIN(date_dim.sale_date)) as customer_tenure_days,
        COUNT(DISTINCT sales.payment_method) as payment_methods_used,
        COUNT(DISTINCT products.category) as categories_purchased
    FROM
        sales
    LEFT JOIN
        products on sales.product_sk = products.product_sk
    LEFT JOIN
        customer on sales.customer_sk = customer.customer_sk
    LEFT JOIN
        date_dim on sales.date_sk = date_dim.date_sk
    GROUP BY
        sales.customer_sk,
        customer.first_name,
        customer.gender
)

SELECT
    customer_sk,
    first_name,
    gender,
    total_transactions,
    ROUND(lifetime_value, 2) as lifetime_value,
    ROUND(avg_transaction_value, 2) as avg_transaction_value,
    total_items_purchased,
    first_purchase_date,
    last_purchase_date,
    customer_tenure_days,
    CASE 
        WHEN total_transactions >= 10 THEN 'VIP'
        WHEN total_transactions >= 5 THEN 'Loyal'
        WHEN total_transactions >= 2 THEN 'Regular'
        ELSE 'New'
    END as customer_segment,
    payment_methods_used,
    categories_purchased,
    ROUND(lifetime_value / NULLIF(total_transactions, 0), 2) as value_per_transaction
FROM
    customer_metrics
ORDER BY
    lifetime_value DESC