# PostgreSQL Portfolio
Examples of PostgreSQL queries from my projects.
## Top 5 products by total sales per category
```sql
SELECT category,
       product_name,
       product_total_sales,
       product_total_profit,
       product_rank
FROM (
-- Calculating product rank over total sales per category.
	SELECT p.category,
         p.product_name,
         SUM(o.sales) AS product_total_sales,
         SUM(o.profit) AS product_total_profit,
         ROW_NUMBER() OVER(PARTITION BY p.category ORDER BY SUM(o.sales) DESC) AS product_rank
	FROM orders o
	JOIN products p USING(product_id)
	GROUP BY p.category, p.product_name
) ranked_products
-- Selecting the top 5 ranked products per category.
WHERE product_rank <= 5
ORDER BY category, product_rank;
```
## Imputing missing values for quantity in product orders, calculated per region and market
```sql
-- Selecting orders with unspecified quantity.
WITH missing_quantity AS (
	SELECT product_id, market, region, sales, discount
	FROM orders
	WHERE quantity IS NULL
),
-- Calculating the unit_price for product_id per market and region.
unit_prices AS (
	SELECT product_id,
         market,
         region,
         SUM(sales / NULLIF(1 - discount, 0)) / SUM(quantity) AS unit_price
	FROM orders
	WHERE quantity IS NOT NULL
	GROUP BY product_id, market, region
)
-- Calculating the missing values for quantity.
SELECT m.product,
       m.market,
       m.region,
       ROUND((m.sales / NULLIF(1 - discount, 0)) / u.unit_price) AS calculated_quantity
FROM missing_quantity m
LEFT JOIN unit_prices u
USING (product_id, market, region);
```
## Identifying the oldest business on each continent
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
         RANK() OVER (PARTITION BY c.continent ORDER BY b.year_founded) AS founded_rank
	FROM businesses b
	JOIN countries c USING (country_code)
) ranked
WHERE founded_rank = 1;
```
