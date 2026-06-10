CREATE DATABASE apple_db;

-- Schema Creation
DROP TABLE IF EXISTS [dbo].[category];
CREATE TABLE category (
	category_id		VARCHAR(10)	PRIMARY KEY,
	category_name	VARCHAR(30)
);

DROP TABLE IF EXISTS [dbo].[products];
CREATE TABLE products (
	product_id		VARCHAR(10)	PRIMARY KEY,
	product_name	VARCHAR(50),
	category_id		VARCHAR(10),
	launch_date		DATE,
	price			FLOAT
	CONSTRAINT fk_products_categoryid FOREIGN KEY (category_id) REFERENCES category(category_id)
);

DROP TABLE IF EXISTS [dbo].[stores];
CREATE TABLE stores (
	store_id	VARCHAR(10) PRIMARY KEY,
	store_name	VARCHAR(30),
	city		VARCHAR(25),
	country		VARCHAR(25)
);

DROP TABLE IF EXISTS [dbo].[sales];
CREATE TABLE sales (
	sale_id		VARCHAR(15) PRIMARY KEY,
	sale_date	DATE,
	store_id	VARCHAR(10),
	product_id	VARCHAR(10),
	quantity	INT
	CONSTRAINT fk_sales_storeid FOREIGN KEY (store_id) REFERENCES stores (store_id),
	CONSTRAINT fk_sales_productid FOREIGN KEY (product_id) REFERENCES products (product_id)
);

DROP TABLE IF EXISTS [dbo].[warranty];
CREATE TABLE warranty (
	claim_id		VARCHAR(15) PRIMARY KEY,
	claim_date		DATE,
	sale_id			VARCHAR(15),
	repair_status	VARCHAR(15)
	CONSTRAINT fk_warranty_saleid FOREIGN KEY (sale_id) REFERENCES sales (sale_id)
);

-- Staging Tables
INSERT INTO [dbo].[category]
SELECT * FROM [dbo].[staging_category];

SELECT * FROM [dbo].[category];

INSERT INTO [dbo].[products]
SELECT * FROM [dbo].[staging_products];

SELECT * FROM [dbo].[products];

INSERT INTO [dbo].[stores]
SELECT * FROM [dbo].[staging_stores];

SELECT * FROM [dbo].[stores];

INSERT INTO [dbo].[sales]
SELECT * FROM [dbo].[staging_sales];

SELECT * FROM [dbo].[sales];

INSERT INTO [dbo].[warranty]
SELECT * FROM [dbo].[staging_warranty];

SELECT * FROM [dbo].[warranty];

-- Exploratory Data Analysis
SELECT DISTINCT repair_status
FROM [dbo].[warranty];

SELECT COUNT(*) FROM [dbo].[sales];

-- Improving Query Performance

-- 1. Sales Table : product_id (cost - 5.03) (0.323s) (Index Scan)
	SELECT * FROM [dbo].[sales]
	WHERE product_id = 'P-44';

	CREATE NONCLUSTERED INDEX idx_sales_productid
	ON [dbo].[sales] (product_id);

	UPDATE STATISTICS [dbo].[sales];

	-- (cost - 16.5) (Key Lookup) (Index Seek)
	SELECT * FROM [dbo].[sales] WITH(INDEX(idx_sales_productid))
	WHERE product_id = 'P-44';

	DROP INDEX idx_idx_sales_productid ON [dbo].[sales];

-- 2. Sales Table : store_id (cost - 5.03) (0.348s) (Index Scan)
	SELECT * FROM [dbo].[sales]
	WHERE store_id = 'ST-31';

	CREATE NONCLUSTERED INDEX idx_sales_storeid
	ON [dbo].[sales] (store_id);

	UPDATE STATISTICS [dbo].[sales];

	-- (cost - 17.5) (Key Lookup) (Index Seek)
	SELECT * FROM [dbo].[sales] WITH(INDEX(idx_sales_storeid))
	WHERE store_id = 'ST-31';

	DROP INDEX idx_sales_storeid ON [dbo].[sales];

-- 3. Sales Table : sale_date (cost - 5.03) (0.238s) (Index Scan)
	
	SELECT * FROM [dbo].[sales]
	WHERE sale_date = '2020-06-10';

	CREATE NONCLUSTERED INDEX idx_sales_saledate 
	ON [dbo].[sales] (sale_date);

	-- (cost - 1.87) (Key Lookup) (Index Seek)
	-- Relatively Faster

	DROP INDEX idx_sales_saledate ON [dbo].[sales];

	-- Faster Querying (Good to use)

-- Business Problems

-- 1. Find the number of stores in each country.
SELECT
	country,
	COUNT(store_id) AS total_stores
FROM [dbo].[stores]
GROUP BY country;

-- 2. Calculate the total number of units sold by each store.
SELECT
	s.store_id,
	SUM(quantity) AS total_units
FROM [dbo].[sales] fs
RIGHT JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
GROUP BY s.store_id;

-- 3. Identify how many sales occurred in December 2023.
SELECT
	COUNT(sale_id) AS total_sales
FROM [dbo].[sales]
WHERE sale_date >= '2023-01-01' AND sale_date < '2024-01-01';

-- 4. Determine how many stores have never had a warranty claim filed.
SELECT
	COUNT(DISTINCT s.store_id) AS stores_without_warranty_claim
FROM [dbo].[warranty] w
JOIN [dbo].[sales] fs
ON w.sale_id = fs.sale_id
RIGHT JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
WHERE w.claim_id IS NULL;

SELECT
	COUNT(*)
FROM [dbo].[stores] s
WHERE NOT EXISTS (
SELECT
	1
FROM [dbo].[warranty] w
JOIN [dbo].[sales] fs
ON w.sale_id = fs.sale_id
WHERE fs.store_id = s.store_id
);

-- 5. Calculate the percentage of warranty claims marked as "In Progress".
SELECT
	CAST((SELECT COUNT(sale_id)
	 FROM [dbo].[warranty]
	 WHERE repair_status = 'In Progress')*100.0/COUNT(sale_id) AS NUMERIC(10,2)) AS warranty_in_progress_percent
FROM [dbo].[warranty];

-- 6. Identify which store had the highest total units sold in the 2023 year.
SELECT TOP 1
	s.store_id,
	s.store_name,
	SUM(quantity) AS units_sold
FROM [dbo].[sales] fs
JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
WHERE sale_date >= '2023-01-01' AND sale_date < '2024-01-01'
GROUP BY s.store_id,s.store_name;

-- 7. Count the number of unique products sold in the 2023 year.
SELECT 
	COUNT(DISTINCT product_id) AS unique_products_sold
FROM [dbo].[sales]
WHERE sale_date >= '2023-01-01' AND sale_date < '2024-01-01';

-- 8. Find the average price of products in each category.
SELECT
	c.category_id,
	c.category_name,
	ROUND(AVG(price),2) AS avg_product_price
FROM [dbo].[products] p
JOIN [dbo].[category] c
ON p.category_id = c.category_id
GROUP BY c.category_id,c.category_name;

-- 9. How many warranty claims were filed in 2020?
SELECT
	COUNT(claim_id) AS warranty_claims
FROM [dbo].[warranty]
WHERE claim_date >= '2020-01-01' AND claim_date < '2021-01-01';

-- 10. For each store, identify the best-selling day based on highest quantity sold.
SELECT
	store_id,
	day,
	total_units
FROM (
SELECT
	store_id,
	DATENAME(WEEKDAY,sale_date) AS day,
	SUM(quantity) AS total_units,
	DENSE_RANK() OVER(PARTITION BY store_id ORDER BY SUM(quantity) DESC) AS ranking
FROM [dbo].[sales]
GROUP BY store_id, DATENAME(WEEKDAY,sale_date)
)t
WHERE ranking = 1;

-- 11. Identify the least selling product in each country for each year based on total units sold.
SELECT
	country,
	yr,
	product_name,
	total_units
FROM (
SELECT
	s.country,
	YEAR(fs.sale_date) AS yr,
	fs.product_id,
	SUM(quantity) AS total_units,
	ROW_NUMBER() OVER(PARTITION BY s.country, YEAR(fs.sale_date) ORDER BY SUM(quantity)) AS ranking
FROM [dbo].[sales] fs
JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
GROUP BY s.country, YEAR(fs.sale_date), fs.product_id
)t
JOIN [dbo].[products] p
ON t.product_id = p.product_id
WHERE ranking = 1;

-- 12. Calculate how many warranty claims were filed within 180 days of a product sale.
SELECT
	COUNT(w.claim_id) AS total_claims
FROM [dbo].[sales] fs
JOIN [dbo].[warranty] w
ON w.sale_id = fs.sale_id
WHERE DATEDIFF(DAY, fs.sale_date, w.claim_date) BETWEEN 0 AND 180;

-- 13. Determine how many warranty claims were filed for products launched in the last two years.
SELECT
	p.product_name,
	COUNT(w.claim_id) AS total_claims
FROM [dbo].[sales] fs
JOIN [dbo].[warranty] w
ON w.sale_id = fs.sale_id
JOIN [dbo].[products] p
ON fs.product_id = p.product_id
WHERE p.launch_date >= DATEADD(YEAR, -2, GETDATE())
GROUP BY p.product_name;

-- 14. List the months in the last three years where sales exceeded 5,000 units in the USA.
SELECT
	YEAR(fs.sale_date) AS yr,
	MONTH(fs.sale_date) AS mth,
	SUM(quantity) AS total_units
FROM [dbo].[sales] fs
JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
WHERE s.country = 'United States' AND fs.sale_date >= DATEADD(YEAR,-3,GETDATE())
GROUP BY YEAR(fs.sale_date), MONTH(fs.sale_date)
HAVING SUM(quantity) > 5000
ORDER BY yr,mth;

-- 15. Identify the product category with the most warranty claims filed in the last two years.
SELECT TOP 1 WITH TIES
	c.category_name,
	COUNT(w.claim_id) AS total_claims
FROM [dbo].[sales] fs
JOIN [dbo].[warranty] w
ON fs.sale_id = w.sale_id
JOIN [dbo].[products] p
ON fs.product_id = p.product_id
JOIN [dbo].[category] c
ON p.category_id = c.category_id
WHERE w.claim_date >= DATEADD(YEAR,-2,GETDATE())
GROUP BY c.category_name
ORDER BY total_claims DESC;

-- 16. Determine the percentage chance of receiving warranty claims per purchase 
--     after each purchase for each country.
SELECT
	country,
	total_purchase,
	total_units,
	total_claims,
	CAST(total_claims * 100.0 / total_purchase AS NUMERIC(10,2)) AS warranty_claim_chance
FROM (
SELECT
	s.country,
	SUM(fs.quantity) AS total_units,
	COUNT(w.claim_id) AS total_claims,
	COUNT(fs.sale_id) AS total_purchase
FROM [dbo].[sales] fs
JOIN [dbo].[stores] s
ON fs.store_id = s.store_id
LEFT JOIN [dbo].[warranty] w
ON fs.sale_id = w.sale_id
GROUP BY s.country
)t;

-- 17. Analyze the year-by-year growth ratio for each store.
WITH store_yearly_sale AS (
	SELECT
		s.store_id,
		s.store_name,
		YEAR(fs.sale_date) AS yr,
		SUM(fs.quantity) AS total_units,
		SUM(fs.quantity * p.price) AS total_sale
	FROM [dbo].[stores] s
	LEFT JOIN [dbo].[sales] fs
	ON s.store_id = fs.store_id
	JOIN [dbo].[products] p
	ON fs.product_id = p.product_id
	GROUP BY s.store_id, s.store_name, YEAR(fs.sale_date)
),
store_growth_ratio AS (
	SELECT
		store_name,
		yr,
		total_sale AS current_year_sale,
		LAG(total_sale,1) OVER(PARTITION BY store_id ORDER BY yr ASC) AS prev_year_sale
	FROM store_yearly_sale
)
SELECT
	store_name,
	yr,
	current_year_sale,
	prev_year_sale,
	CAST((current_year_sale - prev_year_sale) * 100.0 / prev_year_sale AS NUMERIC (10,2)) AS growth_ratio
FROM store_growth_ratio
WHERE prev_year_sale IS NOT NULL;

-- 18. Calculate the correlation between product price and warranty claims 
-- for products sold in the last five years, segmented by price range.
WITH price_segmentation AS (
SELECT
	p.product_id,
	CASE
		WHEN p.price < 500 THEN 'Cheap'
		WHEN p.price <= 1000 THEN 'Mid'
		ELSE 'Expensive'
	END AS price_segment,
	fs.sale_id,
	w.claim_id
  FROM [dbo].[sales] fs
  JOIN [dbo].[products] p
  ON fs.product_id = p.product_id
  LEFT JOIN [dbo].[warranty] w
  ON fs.sale_id = w.sale_id
  WHERE fs.sale_date >= DATEADD(YEAR,-5,GETDATE())
)
SELECT
	price_segment,
	COUNT(DISTINCT sale_id) AS total_sales,
	COUNT(claim_id) AS total_claims,
	CAST(COUNT(claim_id) * 100.0 / COUNT(DISTINCT sale_id) AS NUMERIC(10,2)) AS claim_rate_pct
FROM price_segmentation
GROUP BY price_segment;

-- 19. Identify the store with the highest percentage of "Completed" claims 
-- relative to total claims filed.
SELECT TOP 1
	s.store_id,
	COUNT(w.claim_id) AS total_claims,
	SUM(CASE
			WHEN w.repair_status = 'Completed' THEN 1
			ELSE 0
		END) AS completed_claims,
	CAST( SUM(CASE
			WHEN w.repair_status = 'Completed' THEN 1
			ELSE 0
		END) * 100.0 / 	COUNT(w.claim_id) AS NUMERIC(10,2)) AS completed_claims_pct
FROM [dbo].[stores] s
JOIN [dbo].[sales] fs
ON s.store_id = fs.store_id
JOIN [dbo].[warranty] w
ON fs.sale_id = w.sale_id
GROUP BY s.store_id
ORDER BY completed_claims_pct DESC;

-- 20. Write a query to calculate the monthly running total of sales for each store over 
-- the past four years and compare trends during this period.
WITH monthly_sales AS (
	SELECT
		s.store_id,
		DATEFROMPARTS(YEAR(fs.sale_date), MONTH(fs.sale_date), 1) AS sales_month,
		SUM(fs.quantity * p.price) AS total_sale
	FROM [dbo].[stores] s
	JOIN [dbo].[sales] fs
	ON s.store_id = fs.store_id
	JOIN [dbo].[products] p
	ON fs.product_id = p.product_id
	WHERE fs.sale_date >= DATEADD(YEAR,-4,GETDATE())
	GROUP BY s.store_id, DATEFROMPARTS(YEAR(fs.sale_date), MONTH(fs.sale_date), 1)
),
sale_monthly_trend AS
(
	SELECT
		store_id,
		sales_month,
		total_sale AS current_month_sale,
		LAG(total_sale) OVER(PARTITION BY store_id ORDER BY sales_month) AS previous_month_sale,
		SUM(total_sale) OVER(PARTITION BY store_id ORDER BY sales_month) AS running_total
	FROM monthly_sales
)
SELECT
	*,
	CAST((current_month_sale - previous_month_sale) * 100.0 / NULLIF(previous_month_sale,0) AS NUMERIC(10,2)) AS sale_growth_pcnt
FROM sale_monthly_trend;

-- Bonus. Analyze product sales trends over time, segmented into key periods: 
-- from launch to 6 months, 6-12 months, 12-18 months, and beyond 18 months.
WITH product_sales AS (
	SELECT
		p.product_name,
		p.launch_date,
		fs.sale_date,
		fs.quantity,
		DATEDIFF(MONTH,p.launch_date,fs.sale_date) AS months_since_launch
	FROM [dbo].[products] p
	JOIN [dbo].[sales] fs
	ON p.product_id = fs.product_id
	WHERE fs.sale_date > p.launch_date
),
sale_segment AS (
	SELECT
		*,
		CASE
			WHEN months_since_launch < 6 THEN '0-6'
			WHEN months_since_launch < 12 THEN '6-12'
			WHEN months_since_launch < 18 THEN '12-18'
			ELSE '18+'
		END AS month_segment
	FROM product_sales
)
SELECT
	product_name,
	month_segment,
	SUM(quantity) AS total_qty_sales
FROM sale_segment
GROUP BY product_name, month_segment
ORDER BY product_name, total_qty_sales DESC;