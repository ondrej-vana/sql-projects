-- Filling missing values for quantity in product orders

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
