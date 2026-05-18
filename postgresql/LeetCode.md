# LeetCode SQL 50 Solutions

My solutions for LeetCode's [SQL 50 interview questions](https://leetcode.com/studyplan/top-sql-50/). Explanatory comments incoming.

### 176. Second highest salary

```sql
SELECT (
	SELECT DISTINCT salary
	FROM employee
	ORDER BY salary DESC
	OFFSET 1
	LIMIT 1
) AS secondHighestSalary;

SELECT MAX(salary) AS secondHighestSalary
FROM employee
WHERE salary < (SELECT MAX(salary) FROM employee);
```

### 197. Rising temperature

```sql
SELECT id
FROM (
	SELECT id,
		recordDate,
		temperature,
		LAG(temperature) OVER (ORDER BY recordDate) AS prev_temp,
		LAG(temperature) OVER (ORDER BY recordDate) AS prev_date
	FROM weather
) t
WHERE temperature > prev_temp
	AND recordDate = prev_date + INTERVAL '1 day';
```

### 550. Game play analysis IV

```sql
WITH first_login AS (
	SELECT player_id,
		MIN(event_date) AS first_day
	FROM activity
	GROUP BY player_id
)
SELECT ROUND(
		COUNT(a.player_id)::NUMERIC
		/ COUNT(*),
	2) AS fraction
FROM first_login AS f
LEFT JOIN activity AS a
ON a.player_id = f.player_id
	AND a.event_date = f.first_day + INTERVAL '1 day';
```

### 619. Largest single value

```sql
SELECT MAX(num) AS max_value
FROM (
	SELECT num, COUNT(*) AS cnt
	FROM mynumbers
	GROUP BY num
) s
WHERE cnt = 1;
```

### 1164. Product price at a given date

```sql
-- left join lateral
SELECT p.product_id,
	COALESCE(n.new_price, 10) AS price
FROM (SELECT DISTINCT product_id FROM products) p
LEFT JOIN LATERAL (
	SELECT new_price
	FROM products AS r
	WHERE r.product_id = p.product_id
		AND change_date <= DATE '2019-08-16'
	ORDER BY r.change_date DESC
	LIMIT 1
) n
ON TRUE
ORDER BY p.product_id;

--distinct on
SELECT p.product_id,
	COALESCE(n.new_price, 10) AS price
FROM (SELECT DISTINCT product_id FROM products) p
LEFT JOIN (
	SELECT DISTINCT ON (product_id)
		product_id, new_price
	FROM products
	WHERE change_date <= DATE '2019-08-16'
	ORDER BY product_id, change_date DESC
) n
ON p.product_id = n.product_id
ORDER BY p.product_id;
```

### 1193. Montly transactions I

```sql
SELECT TO_CHAR(trans_date, 'yyyy-mm') AS month,
	country,
	COUNT(*) AS trans_count,
	SUM(CASE WHEN state = 'approved' THEN 1 ELSE 0 END) AS approved_count,
	SUM(amount) AS trans_total_amount,
	SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM transactions
GROUP BY month, country;
```

### 1251. Average selling price

```sql
SELECT p.product_id,
	ROUND(
		COALESCE(
			SUM(u.units * p.price)
			/ NULLIF(SUM(u.units), 0)::NUMERIC,
		0),
	2) AS average_price
FROM prices AS p
LEFT JOIN unitsSold AS u
ON p.product_id = u.product_id
	AND u.purchase_date BETWEEN p.start_date AND p.end_date
GROUP BY p.product_id;
```

### 1549. Most recent order for each product

```sql
SELECT p.product_id,
	COALESCE(x.new_price, 10) AS price
FROM (SELECT DISTINCT product_id FROM products) p
LEFT JOIN (
	SELECT DISTINCT ON (product_id)
		product_id, new_price
	FROM products
	WHERE change_date <= DATE '2019-08-16'
	ORDER BY product_id, change_date DESC
) x
ON x.product_id = p.product_id
ORDER BY p.product_id;
```

### 1581. Customer who visited but did not make any transactions

```sql
SELECT v.customer_id,
	COUNT(*) AS count_no_trans
FROM visits AS v
WHERE NOT EXISTS (
	SELECT 1
	FROM transactions AS t
	WHERE t.visit_id = v.visit_id
)
GROUP BY v.customer_id;
```

### 1661. Average time of process per machine

```sql
SELECT s.machine_id,
	ROUND(
		AVG(e.timestamp - s.timestamp)::NUMERIC,
	3) AS processing_time
FROM activity AS s
JOIN activity AS e
ON s.machine_id = e.machine_id AND s.process_id = e.process_id
	AND s.activity_type = 'start' AND e.activity_type = 'end'
GROUP BY s.machine_id;
```

### 1789. Primary department for each employee

```sql
-- Postgres-only solution (DISTINCT ON)
SELECT DISTINCT ON (employee_id)
	employee_id,
	department_id
FROM employees
ORDER BY employee_id, primary_flag = 'Y' DESC, department_id;
```

### 1934. Confirmation rate

```sql
WITH conf_cte AS (
	SELECT user_id,
		COUNT(*) FILTER (WHERE action = 'confirmed') AS confirmed,
		COUNT(*)  AS total
	FROM confirmations
	GROUP BY user_id
)
SELECT s.user_id,
	ROUND(
		COALESCE(c.confirmed/c.total::NUMERIC, 0),
	2) AS confirmation_rate
FROM signups AS s
LEFT JOIN conf_cte AS c
ON s.user_id = c.user_id;
```
