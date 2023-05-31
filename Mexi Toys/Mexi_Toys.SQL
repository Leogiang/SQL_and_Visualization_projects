-- Create 4 tables, import data and view the tables
CREATE TABLE products(
Product_ID SERIAL PRIMARY KEY,
Product_Name VARCHAR(30),
Product_Category VARCHAR(20),
Product_Cost NUMERIC(4,2),
Product_Price NUMERIC(4,2)
);

COPY products FROM '...\Mexi Toys Data\products.csv' DELIMITER ',' CSV HEADER;

SELECT * FROM products;

CREATE TABLE stores(
Store_ID SERIAL PRIMARY KEY,
Store_Name VARCHAR(30),
Store_City VARCHAR(20),
Store_Location VARCHAR(15),
Store_Open_Date DATE
);

COPY stores FROM '...\Mexi Toys Data\stores.csv' DELIMITER ',' CSV HEADER;

SELECT * FROM stores;

CREATE TABLE inventory(
Store_ID INTEGER REFERENCES stores(Store_ID),
Product_ID INTEGER REFERENCES products(Product_ID),
Stock_On_Hand INTEGER
);

COPY inventory FROM '...\Mexi Toys Data\inventory.csv' DELIMITER ',' CSV HEADER;

SELECT * FROM inventory;

CREATE TABLE sales(
Sale_ID INTEGER PRIMARY KEY,
"date" DATE,
Store_ID INTEGER REFERENCES stores(Store_ID),
Product_ID INTEGER REFERENCES products(Product_ID),
Units INTEGER
);

COPY sales FROM '...\Mexi Toys Data\sales.csv' DELIMITER ',' CSV HEADER;

SELECT * FROM sales

--DATA CLEANING: remove nulls--
SELECT COUNT(*) FROM sales; --it shows 829,393 rows

SELECT * FROM sales WHERE sales.date is null;
--it shows 131 rows of null data except for sale_id
--these are records of cancellation or mistakes, so we should remove them
DELETE FROM sales WHERE sales.date is null;
SELECT count(*) FROM sales; --it shows 829,262 rows after removing null records

--DATA ANALYSIS--

--Firstly, we need to add a Profit Margin column into Products table for later analysis
ALTER TABLE products ADD COLUMN profit_margin NUMERIC(4,2);

UPDATE products p1 SET profit_margin =
(SELECT (product_price - product_cost) FROM products p2
WHERE p1.product_id = p2.product_id);

--generate statitics summary for sales over the years
SELECT total_transactions, total_items_sold, total_revenue, total_costs, gross_profit, margin_ratio,
inventory_count, inventory_balance, first_date, last_date
FROM
(SELECT TO_CHAR(COUNT(*),'fm999G999') AS total_transactions,
TO_CHAR(SUM(units),'fm999G999G999') AS total_items_sold,
CAST(SUM(s.units * pr.product_price) AS money) AS total_revenue,
CAST(SUM(s.units * pr.product_cost) AS money) AS total_costs,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit,
TO_CHAR(SUM(s.units * pr.profit_margin)/SUM(s.units * pr.product_price)*100,'fm00D00%') AS margin_ratio,
MIN(date) AS first_date,
MAX(date) AS last_date,
'consolidate' AS consol
FROM sales s
JOIN products pr ON s.product_id = pr.product_id) source1
INNER JOIN
(SELECT TO_CHAR(SUM(stock_on_hand),'fm999G999') AS inventory_count,
CAST(SUM(stock_on_hand * pr.product_cost) AS money) AS inventory_balance,
'consolidate' AS consol
FROM inventory i
JOIN products pr ON i.product_id = pr.product_id) source2 ON source1.consol = source2.consol;
--please note the whole period of this dataset is FROM 01/01/2017 to 01/09/2018.

--Revenue analysis by time
--Revenue & profits by year
SELECT TO_CHAR(s.date,'yyyy'),
CAST(SUM(s.units * pr.product_price) AS money) total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit
FROM sales s
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1
--2017 witnessed higher revenue and gross profit
--but please note that 2018 data included Q1 to Q3 only

--Revenue & profits by month
SELECT TO_CHAR(s.date,'MM') Month_number, TO_CHAR(s.date,'Month') Month_name,
CAST(SUM(s.units * pr.product_price) AS money) total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit
FROM sales s
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1, 2
ORDER BY 1 ASC
--Revenue was highest in April, wile gross profit was highest in March.
--Both amounts were lowest in October.

--Revenue & profits by day of week
SELECT TO_CHAR(s.date,'ID') day_of_week,
CASE TO_CHAR(s.date,'ID')
WHEN '1' THEN 'Monday'
WHEN '2' THEN 'Tuesday'
WHEN '3' THEN 'Wednesday'
WHEN '4' THEN 'Thursday'
WHEN '5' THEN 'Friday'
WHEN '6' THEN 'Saturday'
WHEN '7' THEN 'Sunday' END AS day_name,
CAST(SUM(s.units * pr.product_price) AS money) total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit
FROM sales s
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1
ORDER BY 1 ASC
--the company enjoyed largest revenue and gross profit during weekend, especially Sunday

-- Revenue analysis by stores
--store summary: 50 stores in 4 locations across 29 cities, as well as the first opened date
SELECT COUNT(store_id) AS store_count, COUNT(DISTINCT store_city) AS city_count,
COUNT(DISTINCT store_location) AS location_count, MIN(store_open_date) AS earliest_establishment
FROM stores

--Revenue & profits of each store
SELECT store_name, store_city, store_location, store_open_date,
CAST(SUM(s.units * pr.product_price) AS money) total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit
FROM stores st
JOIN sales s ON st.store_id = s.store_id
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1,2,3,4
ORDER BY total_revenue DESC
--years of operation seemed not to be related to the KPIs.

--analyze revenue & profits by location
SELECT store_location, COUNT(DISTINCT s.store_id),
CAST(SUM(s.units * pr.product_price) as money) total_revenue,
CAST(SUM(s.units * pr.product_price)/COUNT(DISTINCT s.store_id) as money) average_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit,
CAST(SUM(s.units * pr.profit_margin)/COUNT(DISTINCT s.store_id) as money) average_gross_profit
FROM stores st
JOIN sales s ON st.store_id = s.store_id
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1
ORDER BY total_revenue DESC
--airports seemed to be the most profitable on average.
--Most of the stores were in downtown which has largest share of revenue and profit.

--analyze revenue & profits by city
SELECT store_city, TO_CHAR(COUNT(*),'fm999G999'),
CAST(SUM(s.units * pr.product_price) AS money) total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS gross_profit
FROM stores st
JOIN sales s ON st.store_id = s.store_id
JOIN products pr ON s.product_id = pr.product_id
GROUP BY 1
ORDER BY total_revenue DESC;
--In each city listed, the company had 1 to 4 stores
--Cuidad de Mexico city has 4 stores with the highest total income
--followed by Guadalajara and Monterrey with same 4 stores at each city

--Product analysis

--product summary: 35 products grouped in 5 categories, and lowest & highest costs & prices
SELECT COUNT(product_id) AS product_count, COUNT(DISTINCT product_category) AS category_count,
MIN(product_cost) AS lowest_cost,
MAX(product_cost) AS highest_cost,
MIN(product_price) AS lowest_price,
MAX(product_price) AS highest_price
FROM products

--Revenue & profits FROM each product
SELECT product_name, product_category,
TO_CHAR(SUM(s.units),'fm999G999') AS items_sold,
CAST(SUM(s.units * pr.product_price) AS money) AS total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS total_profit
FROM products pr JOIN sales s ON pr.product_id = s.product_id
GROUP BY 1, 2
ORDER BY total_revenue DESC
LIMIT 5;
--Lego Bricks earned the highest revenue,
--followed by Colorbuds (the bestsellers) which however had highest profits

--Revenue & profits by product category
SELECT product_category,
TO_CHAR(SUM(s.units),'fm999G999') AS items_sold,
CAST(SUM(s.units * pr.product_price) AS money) AS total_revenue,
CAST(SUM(s.units * pr.profit_margin) AS money) AS total_profit
FROM products pr JOIN sales s ON pr.product_id = s.product_id
GROUP BY 1
ORDER BY total_revenue DESC;
--Toys was the top revenue & profit source, while Art & Crafts were sold the most

--Analysis of inventory as at 30/09/2018

--Set CTE for product name, category, inventory count and balance
WITH product_summary AS (SELECT product_name,product_category,
SUM(i.stock_on_hand) AS stock_on_hand,
CAST(SUM(i.stock_on_hand * pr.product_cost) AS MONEY) AS inventory_balance
FROM inventory i JOIN products pr ON i.product_id = pr.product_id
GROUP BY 1,2
ORDER BY product_category, inventory_balance DESC)

--summarize inventory category for remainging quantity and balance
--and find the highest remaining product in terms of balance and percentage
SELECT g1.product_category, g1.stock_count, g1.inventory_balance, g2.product_name AS top_remaining_inventory,
TO_CHAR(g2.inventory_balance/g1.inventory_balance*100,'fm00%') AS top_inventory_share
FROM (SELECT pr.product_category,
TO_CHAR(SUM(i.stock_on_hand),'fm999G999') AS stock_count,
CAST(SUM(i.stock_on_hand * pr.product_cost) AS MONEY) AS inventory_balance
FROM inventory i JOIN products pr ON i.product_id = pr.product_id
GROUP BY 1) g1
JOIN (SELECT product_category, product_name, inventory_balance
FROM product_summary p1
WHERE p1.inventory_balance = (SELECT MAX(p2.inventory_balance) FROM product_summary p2
WHERE p1.product_category = p2.product_category)) g2
ON g1.product_category = g2.product_category
ORDER BY inventory_balance DESC;
--Toy category has the largest remaining balance with the top remaining product Lego Bricks accounting for 39%
--however, Art & Crafts category has the largest remaining quantity with 41% of the highest available stock Magic Sand
--Electronics has the lowest remainder
