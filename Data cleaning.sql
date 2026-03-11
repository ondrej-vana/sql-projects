-- 1. Initial Data Quality Report

-- Counting the total number of rows.
SELECT COUNT(*) AS total_rows,
-- Counting records with missing quantity.
	   COUNT(*) FILTER (WHERE quantity IS NULL) AS missing_quantity,
-- Counting records with invalid sales values.
	   COUNT(*) FILTER (WHERE sales < 0) AS negative_sales,
-- Counting unique number of products and customers.
	   COUNT(DISTINCT product_id) AS unique_products,
	   COUNT(DISTINCT customer_id) AS unique_customers
FROM orders;

-- 2. Data Cleaning

SELECT order_id,
-- Standardize the format of text columns.
	   UPPER(market) AS market,
	   INITCAP(region) AS region,
-- Standardize discount values.
	   CASE
	   	  WHEN discount < 0 THEN 0
		  WHEN discount > 1 THEN 1
		  ELSE discount
	   END AS discount
FROM orders;

-- 3. Detecting duplicates

SELECT order_id,
	   order_date,
	   customer_id,
	   product_id,
-- Counting the number of duplicate records.
	   COUNT(*) OVER (
			PARTITION BY order_date, customer_id, product_id
	   ) AS duplicate_count,
-- Using ROW_NUMBER() to ensure all rank values are distinct,
-- as opposed to RANK() where multiple rows can share the same rank value.
	   ROW_NUMBER() OVER (
			PARTITION BY order_date, customer_id, product_id
			ORDER BY order_id ASC
	   ) AS duplicate_rank
FROM orders
-- Filtering for duplicated order records.
WHERE duplicate_count > 1;

-- 4. Data validation

SELECT order_id,
	   order_date,
	   customer_id,
	   product_id,
	   quantity,
	   sales,
-- Flagging data validation status using the CASE expression.
	   CASE
			WHEN quantity IS NULL THEN 'missing quantity'
			WHEN quantity <= 0 THEN 'invalid quantity'
			WHEN sales < 0 THEN 'negative sales'
			ELSE 'valid'
	   END AS data_quality_flag
FROM orders;

-- 5. Combining the steps into one query

-- Step 1: Cleaning the data.
WITH cleaned_data AS (
	SELECT order_id,
			order_date,
			customer_id,
	   		UPPER(market) AS market,
	   		INITCAP(region) AS region,
			product_id,
			sales,
			quantity,
	   		CASE
	   	 		 WHEN discount < 0 THEN 0
		  		WHEN discount > 1 THEN 1
		  		ELSE discount
	   		END AS discount
	FROM orders
),
duplicates_removed AS (
	SELECT *
-- Step 2: Identifying duplicate records.
	FROM (
		SELECT *,
				ROW_NUMBER() OVER (
					PARTITION BY order_date, customer_id, product_id
					ORDER BY order_id
				) AS duplicate_rank
		FROM cleaned_data
	) AS duplicates
-- Step 3: Filtering out the duplicates.
-- Note that a subquery had to be used in order to allow for filtering
-- the results of a window function in the WHERE clause.
-- This could be solved without a subquery using the QUALIFY clause in some engines
-- (unavailable in PostgreSQL).
	WHERE duplicate_rank = 1
),
-- Step 4: Flagging data quality.
validated_data AS (
	SELECT *,
			CASE
				WHEN quantity IS NULL THEN 'missing quantity'
				WHEN quantity <= 0 THEN 'invalid quantity'
				WHEN sales < 0 THEN 'negative sales'
				ELSE 'valid'
			END AS data_quality_flag
	FROM duplicates_removed
)
-- Step 5: Selecting only clean records.
SELECT *
FROM validated_data
WHERE data_quality_flag = 'valid';
