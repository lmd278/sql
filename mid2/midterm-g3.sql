-- For each question, paste your code and  a screenshot of the output of each question
-- Question 1: (Index)
-- a.	Write SQL query to return a list of customer in US (country)
EXPLAIN
SELECT * FROM customers WHERE country = 'US';

-- b.	Write SQL sentence to create a hash index on “customers.country” and show the query plan for query (a) generated by DBMS
DROP INDEX IF EXISTS customers_country;
CREATE INDEX customers_country ON customers USING HASH (country);

-- c.	Write SQL sentence to create a btree index on “customers.country” and show the query plan for query (a) generated by DBMS
DROP INDEX IF EXISTS customers_country;
CREATE INDEX customers_country ON customers USING BTREE (country);

-- d.	Is there any difference between the query plans generated in b and c ? Explain
-- Neither index was used. US is common enough that it's not worth indexing.

-- e.	Drop all the index created in (b) and (c). Write SQL query to return a list of customer in France (country) and then redo b,c,d for the new query.
EXPLAIN
SELECT * FROM customers WHERE country = 'France';

-- f.	Is there any difference between d and e ? Explain
-- In e, both indexes were used. In d, neither index was used.
-- France is not common enough to be indexed.

-- Question 2: (Query)
-- a.	Write SQL all possible queries (join, nested queries, …. ) to return a list of different customers in “Canada” who have already orders somethings
EXPLAIN
SELECT DISTINCT customers.*
FROM customers
JOIN orders ON customers.customerid = orders.customerid
WHERE country = 'Canada';

EXPLAIN
SELECT customers.*
FROM customers
WHERE customerid IN (
    SELECT DISTINCT customerid
    FROM orders
)
AND country = 'Canada';

-- b.	Drop all index (except the ones related to the primary keys) in the relations in query (a). Show the query plans generated by DBMS for each above queries. Are they different? Explain
DROP INDEX IF EXISTS customers_country;
-- The 1st one needs to hash aggregate, the 2nd one doesn't. The second one makes use of the index on customerid.

-- c.	Create relevant index(es) (one by one) for the above queries and check if index is used. Explain
-- 1st one
DROP INDEX IF EXISTS customers_country;
CREATE INDEX customers_country ON customers (country);
-- The index is used beacuse the index is on the country column, which is used in the WHERE clause.

-- 2nd one
DROP INDEX IF EXISTS orders_customerid;
CREATE INDEX orders_customerid ON orders (customerid);
-- The index is used beacuse the index is on the customerid column, which is used in the WHERE clause.
DROP INDEX IF EXISTS customers_country;
CREATE INDEX customers_country ON customers (country);
-- The index is used beacuse the index is on the customerid column, which is used in the WHERE clause.

-- Question 3 (Trigger)
-- a.	Add the attributes “total_sold” in the relation Products. “total_sold” is the total of number of products in all orders
ALTER TABLE products ADD COLUMN total_sold INT;

-- b.	Write trigger to ensure that the attribute “total_sold” must be updated automatically according to any change (insert/update/delete) of orders related to the product
-- Quantity is in orderlines, not orders
CREATE OR REPLACE FUNCTION update_total_sold()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE products
        SET total_sold = total_sold + NEW.quantity
        WHERE prod_id = NEW.prod_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE products
        SET total_sold = total_sold + NEW.quantity - OLD.quantity
        WHERE prod_id = NEW.prod_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE products
        SET total_sold = total_sold - OLD.quantity
        WHERE prod_id = OLD.prod_id;
    END IF;
END;
$$;

CREATE TRIGGER update_total_sold
    AFTER INSERT OR UPDATE OR DELETE ON orderlines
    FOR EACH ROW
    EXECUTE PROCEDURE update_total_sold();

-- Question 4: (function)
-- Write a function to return the range of a products indicated by product id (as input argument). The range of a product is
-- -	“trending” if the total number (total_sold) of sold is greater than 30
-- -	“potential” if the total number of sold is between 20 and 30
-- -	“new” for other cases
-- Before returning the range of the product, we must check if total_sold is correct (see question 3(a)). If it is not correct, the total sold must be updated.
DROP FUNCTION IF EXISTS get_range;
CREATE OR REPLACE FUNCTION get_range(prod_id_input INT)
    RETURNS VARCHAR
    LANGUAGE plpgsql
AS $$
DECLARE
    current_total_sold INT;
    correct_total_sold INT;
BEGIN
    -- Check if total_sold is correct, meaning that it is equal to the sum of the quantity of all orders for this product
    -- Current total sold might be wrong
    SELECT total_sold INTO current_total_sold
    FROM products
    WHERE prod_id = prod_id_input;

    -- Correct total sold is the sum of the quantity of all orders for this product
    SELECT SUM(quantity) INTO correct_total_sold
    FROM orderlines
    WHERE prod_id = prod_id_input;

    IF (current_total_sold <> correct_total_sold) THEN
        UPDATE products
        SET total_sold = correct_total_sold
        WHERE prod_id = prod_id_input;
    END IF;

    -- Return the range
    IF (correct_total_sold > 30) THEN
        RETURN 'trending';
    ELSIF (correct_total_sold BETWEEN 20 AND 30) THEN
        RETURN 'potential';
    ELSE
        RETURN 'new';
    END IF;
END
$$;

-- Test function
SELECT get_range(1);
