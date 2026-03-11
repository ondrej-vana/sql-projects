
# Ondřej Váňa's PostgreSQL Portfolio

Examples of queries from my projects demonstrating data cleaning, transformation, and analysis, with inline comments to explain them.

---

# Sales Dataset

- raw dataset: retail orders

table <code>orders</code>:

|column name|description|data type|
|---|---|---|
|<code>row_id</code>|unique record id|<code>INTEGER</code>|
|<code>order_id</code>|order identifier|<code>TEXT</code>|
|<code>order_date</code>|date order took place|<code>DATE</code>|
|<code>customer_id</code>|customer identifier|<code>TEXT</code>|
|<code>market</code>|market where order was made|<code>TEXT</code>|
|<code>region</code>|customer's region|<code>TEXT</code>|
|<code>product_id</code>|product identifier|<code>TEXT</code>|
|<code>sales</code>|total sales amount per item|<code>DOUBLE PRECISION</code>|
|<code>quantity</code>|quantity of product|<code>DOUBLE PRECISION</code>|
|<code>discount</code>|applied discount (0–1)|<code>DOUBLE PRECISION</code>|

table <code>products</code>:

|column name|description|data type|
|---|---|---|
|<code>product_id</code>|unique identifier for product|<code>TEXT</code>|
|<code>category</code>|category of products|<code>TEXT</code>|
|<code>product_name</code>|name of product|<code>TEXT</code>|

---

# A. Data Preparation

Data preparation process that covers data cleaning, deduplication, and data validation.

## 1. Initial Data Quality Report

- techniques:
	- aggregate functions and FILTER – counting only specified rows

```sql
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
```

## 2. Data Cleaning

- techniques:
	- string functions – to standardize text columns
	- CASE conditional expression – to select rows that require specific cleaning

```sql
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
```

## 3. Detect duplicate records

- techniques:
	- aggregation/ranking and window functions – assuming counts/ranks greater than 1 show the presence of potentially duplicate records

```sql
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
FROM orders;
```

## 4. Data Validation

- techniques:
	- CASE conditional expression – flagging various data problems

```sql
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
```

## Combining data cleaning steps into one query

Using multiple CTEs to break down the process into sequential steps.

```sql
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
```

---

## Imputing Missing Values

Alternatively, I can decide not to ignore records with missing quantity values and instead calculate it based on the available data.

#### Filling missing values for quantity in product orders

Missing quantities are estimated based on average unit prices per product, market, and region.

- techniques:
	- CTEs – for better readability and a cleaner query
	- NULLIF conditional expression – for defensive SQL writing (to avoid division by zero)
	- type casting – because the ROUND() function doesn’t allow for DOUBLE PRECISION data types as an argument

```sql
-- A CTE filtering orders with unspecified quantity.
WITH missing_quantity AS (
	SELECT product_id, market, region, sales, discount
	FROM orders
	WHERE quantity IS NULL
),
-- A CTE which calculates the unit_price for product_id per market and region.
unit_prices AS (
	SELECT product_id,
				 market,
				 region,
-- Using NULLIF to avoid division by zero.
				 (SUM(sales / NULLIF(1 - discount, 0)) / SUM(quantity))::numeric AS unit_price
	FROM orders
	WHERE quantity IS NOT NULL
	GROUP BY product_id, market, region
)
-- Imputing the missing values for quantity based on market, region, and discount.
SELECT m.product_id,
			 m.market,
			 m.region,
-- Type casting as NUMERIC because the ROUND() function
-- doesn't accept DOUBLE PRECISION as an argument.
			 ROUND((m.sales / NULLIF(1 - m.discount, 0))::numeric / NULLIF(u.unit_price, 0)) AS calculated_quantity
FROM missing_quantity AS m
LEFT JOIN unit_prices AS u
USING (product_id, market, region);
```

---

## B. Data Analysis

An example of a data analysis query using the same dataset.

#### Top 5 products by total sales per category

- techniques:
	- aggregation and GROUP BY – calculating the SUM of sales for each product
	- joining – to combine data from <code>orders</code> and <code>products</code> tables
	- window functions and rank – ranking each product within its category
	- CTEs – to avoid aggregation inside the window function
		- this makes the query more portable between engines
 		- i.e. instead of <code>OVER(PARTITION BY p.category ORDER BY SUM(o.sales) DESC)</code> in the main query

```sql
-- Using a CTE to avoid aggregating total_sales inside the window function.
WITH product_sales AS (
	SELECT p.category,
				 p.product_id,
				 SUM(o.sales) AS product_total_sales
	FROM orders AS o
	JOIN products AS p USING(product_id)
	GROUP BY p.category, p.product_id
)
SELECT category,
			 product_id,
			 product_total_sales,
-- With ROW_NUMBER(), I will select exactly 5 products for each category.
-- Whereas with RANK(), more than 5 products could be selected 
-- if they share the same rank.
			 ROW_NUMBER() OVER (
				 PARTITION BY category
				 ORDER BY product_total_sales DESC
			 ) AS product_rank
FROM product_sales
-- Filtering only products ranked in the top 5.
WHERE product_rank <= 5
ORDER BY category, product_rank;
```
