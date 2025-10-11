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
        payment_method
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
)

SELECT

    sum(sales.net_amount) as net_amount,
    sum(sales.gross_amount) as gross_amount,
    sum(sales.quantity) as sales_quantity,
    sales.payment_method,
    products.product_name,
    products.category,
    customer.gender
FROM
    sales
LEFT JOIN
    products on sales.product_sk = products.product_sk
LEFT JOIN
    customer on sales.customer_sk = customer.customer_sk
GROUP BY
    sales.payment_method,
    products.product_name,
    products.category,
    customer.gender
