-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */


-- Step 1. Cross join vendor_inventory with customer
WITH potential_sales AS (
    SELECT 
        v.vendor_name,
        p.product_name,
        vi.original_price,
        c.customer_id
    FROM 
        vendor_inventory vi
    JOIN 
        vendor v ON vi.vendor_id = v.vendor_id
    JOIN 
        product p ON vi.product_id = p.product_id
    CROSS JOIN 
        customer c
),

-- Step 2. Calculate total sales per product per vendor
vendor_revenue AS (
    SELECT 
        vendor_name,
        product_name,
        SUM(original_price * 5) AS total_revenue_per_product
    FROM 
        potential_sales
    GROUP BY 
        vendor_name, product_name
)

-- Step 3. Select final results
SELECT 
    vendor_name,
    product_name,
    ROUND(total_revenue_per_product,2) AS total_vendor_revenue
FROM 
    vendor_revenue
ORDER BY 
    vendor_name, product_name;



-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

CREATE TABLE product_units AS
SELECT *, CURRENT_TIMESTAMP AS snapshot_timestamp
FROM product
WHERE product_qty_type = "unit";

/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units
VALUES(27, "Carrot Cake", "2 lbs", 3, "unit", CURRENT_TIMESTAMP);

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

DELETE FROM product_units
WHERE product_id = 27;


-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */



--Yev's comment: This one was really challenging - loved it!
--STEP 1 - We extract latest quantity per product

SELECT *
FROM (
SELECT product_id, quantity, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY market_date DESC) as date_rank
FROM vendor_inventory
) stock_summary
WHERE stock_summary.date_rank = 1


--STEP 2 - We assign 0 to NULL values in the current stock by product_id

SELECT
    product_id,
    COALESCE(
        (SELECT quantity
        FROM (
            SELECT
                product_id,
                quantity,
                ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY market_date DESC) as date_rank
            FROM vendor_inventory
        WHERE product_units.product_id = vendor_inventory.product_id) stock_summary
        WHERE stock_summary.date_rank = 1),
    0) AS latest_quantity
FROM product_units


--STEP 3 and the final solution - We assign the value of the remaining stock (if any) to each product_id in 'product_units' table.
--NULL values are replaced with zeros. 

WITH stock_summary AS (
    SELECT
        product_id,
        COALESCE(
            (SELECT quantity
            FROM (
                SELECT
                    product_id,
                    quantity,
                    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY market_date DESC) as date_rank
                FROM vendor_inventory
            WHERE product_units.product_id = vendor_inventory.product_id) stock_summary
            WHERE stock_summary.date_rank = 1),
        0) AS latest_quantity
    FROM product_units
    )

UPDATE product_units
SET current_quantity = (
SELECT latest_quantity
FROM stock_summary
WHERE product_units.product_id = stock_summary.product_id
)
