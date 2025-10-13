SELECT 
    date_sk,
    CAST(date_sk AS STRING) as date_string,
    LENGTH(CAST(date_sk AS STRING)) as length,
    COUNT(*) as count
FROM {{ ref('bronze_sales') }}
GROUP BY date_sk, CAST(date_sk AS STRING), LENGTH(CAST(date_sk AS STRING))
ORDER BY length, date_sk
LIMIT 20