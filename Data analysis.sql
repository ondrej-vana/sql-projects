-- Top 5 products by total sales per category

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
