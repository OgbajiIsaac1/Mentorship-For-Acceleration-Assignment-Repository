/*
============================================================
 SQL Week 16 Assignment
 Name: Isaac Ogbaji
 Database: KCC_DB
 Topic: Data Manipulation, Normalization and Query Optimization
============================================================

Assignment Objectives:
1. Normalize the flat file data into separate relational tables.
2. Reduce redundancy by separating Customers, Products, Orders, and OrderDetails.
3. Improve query performance using indexes.
4. Demonstrate best practices using proper joins, filtering, grouping, and ordering.
5. Include partitioning concept for large order data.

Source Table:
dbo.FlatFileTable

The original flat file contains repeated customer, order, and cookie/product information.
This script restructures the data into a cleaner relational database design.
*/

USE KCC_DB;
GO

/*
============================================================
 SECTION 1: DROP EXISTING NORMALIZED TABLES
============================================================

This section removes existing normalized tables if they already exist.
The order is important because OrderDetails depends on Orders and Products,
while Orders depends on Customers.
*/

DROP TABLE IF EXISTS dbo.OrderDetails;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Customers;
GO

/*
============================================================
 SECTION 2: CREATE NORMALIZED TABLES
============================================================

The flat file is split into four tables:

1. Customers     - stores customer details once.
2. Products      - stores cookie/product details once.
3. Orders        - stores order-level information.
4. OrderDetails  - stores products inside each order.

This removes unnecessary repetition and improves database efficiency.
*/

CREATE TABLE dbo.Customers (
    CustomerID INT NOT NULL,
    CustomerName VARCHAR(100) NOT NULL,
    Phone VARCHAR(30),
    Address VARCHAR(200),
    City VARCHAR(100),
    State VARCHAR(50),
    Zip VARCHAR(20),
    Country VARCHAR(100),
    Notes VARCHAR(MAX),

    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)
);
GO

CREATE TABLE dbo.Products (
    CookieID INT NOT NULL,
    CookieName VARCHAR(100) NOT NULL,
    RevenuePerCookie DECIMAL(10,2) NOT NULL,
    CostPerCookie DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_Products PRIMARY KEY (CookieID)
);
GO

CREATE TABLE dbo.Orders (
    OrderID INT NOT NULL,
    OrderDate DATE NOT NULL,
    OrderTotal DECIMAL(10,2) NOT NULL,
    CustomerID INT NOT NULL,

    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Customers 
        FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID)
);
GO

CREATE TABLE dbo.OrderDetails (
    OrderID INT NOT NULL,
    CookieID INT NOT NULL,
    Quantity INT NOT NULL,

    CONSTRAINT PK_OrderDetails PRIMARY KEY (OrderID, CookieID),
    CONSTRAINT FK_OrderDetails_Orders 
        FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_OrderDetails_Products 
        FOREIGN KEY (CookieID) REFERENCES dbo.Products(CookieID)
);
GO

/*
============================================================
 SECTION 3: INSERT DATA INTO NORMALIZED TABLES
============================================================

Customers are inserted using DISTINCT because the same customer appears
many times in the flat file.
*/

INSERT INTO dbo.Customers (
    CustomerID,
    CustomerName,
    Phone,
    Address,
    City,
    State,
    Zip,
    Country,
    Notes
)
SELECT DISTINCT
    CustomerID,
    CustomerName,
    Phone,
    Address,
    City,
    State,
    Zip,
    Country,
    Notes
FROM dbo.FlatFileTable;
GO

SELECT *
FROM dbo.Customers;

/*
Products are inserted using DISTINCT because each cookie appears many times
across different orders.
*/

INSERT INTO dbo.Products (
    CookieID,
    CookieName,
    RevenuePerCookie,
    CostPerCookie
)
SELECT DISTINCT
    CookieID,
    CookieName,
    RevenuePerCookie,
    CostPerCookie
FROM dbo.FlatFileTable;
GO

SELECT *
FROM dbo.Products;

/*
Orders are inserted using DISTINCT because one order can contain multiple cookies,
so the same OrderID appears multiple times in the flat file.
*/

INSERT INTO dbo.Orders (
    OrderID,
    OrderDate,
    OrderTotal,
    CustomerID
)
SELECT DISTINCT
    OrderID,
    OrderDate,
    OrderTotal,
    CustomerID
FROM dbo.FlatFileTable;
GO

SELECT *
FROM dbo.Orders;

/*
OrderDetails stores each cookie/product inside each order.
This table connects Orders and Products.
*/

INSERT INTO dbo.OrderDetails (
    OrderID,
    CookieID,
    Quantity
)
SELECT
    OrderID,
    CookieID,
    Quantity
FROM dbo.FlatFileTable;
GO

SELECT *
FROM dbo.OrderDetails;

/*
============================================================
 SECTION 4: VERIFY DATA LOAD
============================================================

This confirms that data exists in all normalized tables.
*/

SELECT 'Customers' AS TableName, COUNT(*) AS TotalRows FROM dbo.Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM dbo.Orders
UNION ALL
SELECT 'OrderDetails', COUNT(*) FROM dbo.OrderDetails;
GO

/*
============================================================
 SECTION 5: CREATE INDEXES FOR QUERY OPTIMIZATION
============================================================

Indexes help SQL Server find records faster.

Since our queries will often join and filter using CustomerID,
OrderID, CookieID, and OrderDate, indexes are created on those columns.

Best Practice:
- Index foreign key columns used in JOIN operations.
- Index date columns used for filtering.
- Avoid unnecessary indexes because too many indexes can slow down inserts and updates.
*/

CREATE INDEX IX_Orders_CustomerID
ON dbo.Orders(CustomerID);
GO

CREATE INDEX IX_Orders_OrderDate
ON dbo.Orders(OrderDate);
GO

CREATE INDEX IX_OrderDetails_OrderID
ON dbo.OrderDetails(OrderID);
GO

CREATE INDEX IX_OrderDetails_CookieID
ON dbo.OrderDetails(CookieID);
GO

CREATE INDEX IX_Customers_State
ON dbo.Customers(State);
GO

/*
============================================================
 SECTION 6: OPTIMIZED QUERIES
============================================================

This section demonstrates optimized SQL queries.

Optimization Techniques Used:
1. Avoid SELECT * and return only needed columns.
2. Use indexed columns in WHERE and JOIN conditions.
3. Use aliases to make queries readable.
4. Use proper filtering and ordering.
*/

/*
Query 1:
Retrieve customers located in Washington.

Optimization:
- Only needed columns are selected.
- State column has an index: IX_Customers_State.
*/

SELECT
    CustomerID,
    CustomerName,
    Phone,
    City,
    State,
    Country
FROM dbo.Customers
WHERE State = 'WA';
GO

/*
Query 2:
Retrieve orders for a specific customer.

Optimization:
- CustomerID is indexed in dbo.Orders.
- Only relevant columns are selected.
*/

SELECT
    OrderID,
    OrderDate,
    OrderTotal,
    CustomerID
FROM dbo.Orders
WHERE CustomerID = 5
ORDER BY OrderDate;
GO

/*
============================================================
 SECTION 7: PROPER JOINS
============================================================

Joins are used to combine normalized tables.

The original flat file stored everything in one table.
After normalization, we use JOINs to reconnect related information.
*/

/*
Query 3:
Show each order with the customer name.

Best Practice:
- Use INNER JOIN when matching records must exist in both tables.
- Use aliases C and O for readability.
*/

SELECT
    O.OrderID,
    O.OrderDate,
    C.CustomerName,
    C.Phone,
    O.OrderTotal
FROM dbo.Orders AS O
INNER JOIN dbo.Customers AS C
    ON O.CustomerID = C.CustomerID
ORDER BY O.OrderDate;
GO

/*
Query 4:
Show full order breakdown including customer, order, product, and quantity.

This joins all four normalized tables:
Customers, Orders, OrderDetails, and Products.
*/

SELECT
    O.OrderID,
    O.OrderDate,
    C.CustomerName,
    P.CookieName,
    OD.Quantity,
    P.RevenuePerCookie,
    P.CostPerCookie,
    O.OrderTotal
FROM dbo.Orders AS O
INNER JOIN dbo.Customers AS C
    ON O.CustomerID = C.CustomerID
INNER JOIN dbo.OrderDetails AS OD
    ON O.OrderID = OD.OrderID
INNER JOIN dbo.Products AS P
    ON OD.CookieID = P.CookieID
ORDER BY O.OrderID, P.CookieName;
GO

/*
============================================================
 SECTION 8: AGGREGATE QUERIES
============================================================

Aggregate functions are used to summarize business data.

Examples:
- COUNT()
- SUM()
- GROUP BY
- ORDER BY
*/

/*
Query 5:
Calculate total revenue per customer.

Optimization:
- Uses normalized Orders and Customers tables.
- Uses GROUP BY to summarize sales.
*/

SELECT
    C.CustomerName,
    COUNT(O.OrderID) AS TotalOrders,
    SUM(O.OrderTotal) AS TotalRevenue
FROM dbo.Customers AS C
INNER JOIN dbo.Orders AS O
    ON C.CustomerID = O.CustomerID
GROUP BY C.CustomerName
ORDER BY TotalRevenue DESC;
GO

/*
Query 6:
Calculate total quantity sold for each cookie/product.
*/

SELECT
    P.CookieName,
    SUM(OD.Quantity) AS TotalQuantitySold
FROM dbo.Products AS P
INNER JOIN dbo.OrderDetails AS OD
    ON P.CookieID = OD.CookieID
GROUP BY P.CookieName
ORDER BY TotalQuantitySold DESC;
GO

/*
Query 7:
Estimate profit per product.

Formula:
Revenue = Quantity * RevenuePerCookie
Cost    = Quantity * CostPerCookie
Profit  = Revenue - Cost
*/

SELECT
    P.CookieName,
    SUM(OD.Quantity) AS TotalQuantitySold,
    SUM(OD.Quantity * P.RevenuePerCookie) AS TotalRevenue,
    SUM(OD.Quantity * P.CostPerCookie) AS TotalCost,
    SUM(OD.Quantity * (P.RevenuePerCookie - P.CostPerCookie)) AS EstimatedProfit
FROM dbo.Products AS P
INNER JOIN dbo.OrderDetails AS OD
    ON P.CookieID = OD.CookieID
GROUP BY P.CookieName
ORDER BY EstimatedProfit DESC;
GO

/*
============================================================
 SECTION 9: DATE FILTERING
============================================================

This query retrieves orders from a specific date range.

Using a date range is better than applying functions directly
to the OrderDate column because it allows indexes on OrderDate
to be used more efficiently.
*/

SELECT
    OrderID,
    OrderDate,
    OrderTotal,
    CustomerID
FROM dbo.Orders
WHERE OrderDate >= '2022-02-01'
  AND OrderDate < '2022-03-01'
ORDER BY OrderDate;
GO

/*
============================================================
 SECTION 10: PARTITIONING BEST PRACTICE
============================================================

Partitioning is useful when a table becomes very large.

For example, if dbo.Orders contains millions of records across many years,
the table can be partitioned by OrderDate.

Benefits of partitioning:
1. Faster queries when filtering by date.
2. Easier data management for old records.
3. Improved performance for large reporting tables.

In this project, the dataset is small, so actual partitioning is not required.
However, the best practice would be to partition the Orders table by OrderDate
for a large production database.

Example Concept:

CREATE PARTITION FUNCTION PF_Orders_ByYear (DATE)
AS RANGE RIGHT FOR VALUES 
('2022-01-01', '2023-01-01', '2024-01-01');

CREATE PARTITION SCHEME PS_Orders_ByYear
AS PARTITION PF_Orders_ByYear
ALL TO ([PRIMARY]);

Then the Orders table could be created on the partition scheme using OrderDate.
*/

/*
============================================================
 SECTION 11: ASSIGNMENT SUMMARY
============================================================

This SQL script completed the following:

1. Imported the original flat file into dbo.FlatFileTable.
2. Normalized the flat file into four relational tables:
   - dbo.Customers
   - dbo.Products
   - dbo.Orders
   - dbo.OrderDetails

3. Applied primary keys and foreign keys to enforce relationships.
4. Added indexes to improve query performance.
5. Used optimized queries that avoid SELECT *.
6. Used proper INNER JOINs to connect related tables.
7. Used aggregate functions for business reporting.
8. Included partitioning best practice for large datasets.

*/

/*
============================================================
 SECTION 11: VISUALIZATION AND REPORTING VIEWS
============================================================

Although SQL Server Management Studio is mainly used for querying data,
we can prepare summary queries that can be used for visualization in tools
such as Excel, Power BI, or SQL Server Reporting Services.

The following views summarize the normalized data for charts and dashboards.
*/

/*
Chart Suggestion:
Bar Chart - Total Revenue by Customer
*/

CREATE OR ALTER VIEW dbo.vw_TotalRevenueByCustomer AS
SELECT
    C.CustomerName,
    COUNT(O.OrderID) AS TotalOrders,
    SUM(O.OrderTotal) AS TotalRevenue
FROM dbo.Customers AS C
INNER JOIN dbo.Orders AS O
    ON C.CustomerID = O.CustomerID
GROUP BY C.CustomerName;
GO

SELECT *
FROM dbo.vw_TotalRevenueByCustomer
ORDER BY TotalRevenue DESC;
GO

/*
Chart Suggestion:
Bar Chart - Total Quantity Sold by Product
*/

CREATE OR ALTER VIEW dbo.vw_TotalQuantitySoldByProduct AS
SELECT
    P.CookieName,
    SUM(OD.Quantity) AS TotalQuantitySold
FROM dbo.Products AS P
INNER JOIN dbo.OrderDetails AS OD
    ON P.CookieID = OD.CookieID
GROUP BY P.CookieName;
GO

SELECT *
FROM dbo.vw_TotalQuantitySoldByProduct
ORDER BY TotalQuantitySold DESC;
GO

/*
Chart Suggestion:
Line Chart - Monthly Revenue Trend
*/

CREATE OR ALTER VIEW dbo.vw_MonthlyRevenueTrend AS
SELECT
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    SUM(OrderTotal) AS MonthlyRevenue
FROM dbo.Orders
GROUP BY
    YEAR(OrderDate),
    MONTH(OrderDate);
GO

SELECT *
FROM dbo.vw_MonthlyRevenueTrend
ORDER BY OrderYear, OrderMonth;
GO

/*
Chart Suggestion:
Column Chart - Estimated Profit by Product
*/

CREATE OR ALTER VIEW dbo.vw_EstimatedProfitByProduct AS
SELECT
    P.CookieName,
    SUM(OD.Quantity) AS TotalQuantitySold,
    SUM(OD.Quantity * P.RevenuePerCookie) AS TotalRevenue,
    SUM(OD.Quantity * P.CostPerCookie) AS TotalCost,
    SUM(OD.Quantity * (P.RevenuePerCookie - P.CostPerCookie)) AS EstimatedProfit
FROM dbo.Products AS P
INNER JOIN dbo.OrderDetails AS OD
    ON P.CookieID = OD.CookieID
GROUP BY P.CookieName;
GO

SELECT *
FROM dbo.vw_EstimatedProfitByProduct
ORDER BY EstimatedProfit DESC;
GO

/*
============================================================
 FINAL ASSIGNMENT CONCLUSION
============================================================

The original flat file contained repeated customer, order, and product data.
To improve the design, the data was normalized into four relational tables:

1. Customers
2. Products
3. Orders
4. OrderDetails

Primary keys and foreign keys were used to maintain relationships between tables.
Indexes were added to improve query performance on commonly used columns.
Optimized queries were written using proper joins, filtering, grouping, and ordering.

Partitioning was also discussed as a best practice for large order tables,
especially when filtering by OrderDate.

Additional reporting views were created to support visualization:
1. Revenue by Customer
2. Quantity Sold by Product
3. Monthly Revenue Trend
4. Estimated Profit by Product

These views can be exported to Excel or Power BI for dashboard reporting.

This completes the SQL Week 16 assignment.

*/