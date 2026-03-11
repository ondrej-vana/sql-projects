
# Ondřej Váňa's PostgreSQL Portfolio

A few examples of queries from my projects, with inline comments to explain them.

---

### Identifying the oldest business on each continent

- technique:
	- window functions and ranking as opposed to aggregation (MIN)
		- allows for easier reformulation of the query if needed

```sql
SELECT continent,
			 country,
			 business,
			 year_founded
FROM (
	SELECT c.continent,
				 c.country,
				 b.business,
				 b.year_founded,
-- Using RANK() as opposed to MIN(),
-- a more elegant solution which allows for a later change of the WHERE condition.
-- (e.g. to list the top 3 businesses instead of just the oldest one)
				 RANK() OVER (
					 PARTITION BY c.continent 
					 ORDER BY b.year_founded
				 ) AS founded_rank
	FROM businesses AS b
	JOIN countries AS c USING (country_code)
) AS ranked
WHERE founded_rank = 1
ORDER BY year_founded ASC;
```

---

## Sales Data Project

- dataset: retail orders

table <code>orders</code>:

|column name|description|data type|
|---|---|---|
|<code>row_id</code>|unique record id|<code>INTEGER</code>|
|<code>order_id</code>| order identifier|<code>TEXT</code>|
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
|<code>order_id</code>|category of products|<code>TEXT</code>|
|<code>market</code>|name of product|<code>TEXT</code>|

### 1. Top 5 products by total sales per category

- techniques:
	- aggregation – calculating the SUM of sales for each product
	- joining – to combine data from <code>orders</code> and <code>products</code> tables
	- window functions and rank – ranking each product within its category
	- CTEs – to avoid aggregation inside the window function
 		- i.e. instead of <code>OVER(PARTITION BY p.category ORDER BY SUM(o.sales) DESC)</code> in the main query

```sql
-- Using a CTE to avoid aggregating total_sales inside the window function.
WITH product_sales AS (
	SELECT p.category,
				 p.product_name,
				 SUM(o.sales) AS product_total_sales
	FROM orders AS o
	JOIN products AS p USING(product_id)
	GROUP BY p.category, p.product_name
)
SELECT category,
			 product_name,
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

### 2. Imputing missing values for quantity in product orders

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
			 ROUND((m.sales / NULLIF(1 - discount, 0))::numeric / u.unit_price) AS calculated_quantity
FROM missing_quantity AS m
LEFT JOIN unit_prices AS u
USING (product_id, market, region);
```
