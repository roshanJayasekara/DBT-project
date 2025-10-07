WITH dedup_query as
(

SELECT
    * ,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY updateddate desc) as deduplicateion_id
FROM
    {{ source('source', 'items') }}

)
SELECT
    id,
    name,
    category,
    updateddate
FROM
    dedup_query
WHERE deduplicateion_id = 1