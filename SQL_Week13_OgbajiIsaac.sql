--OGBAJI ISAAC ASSIGMENT SUBMISSION
-- Create Database
CREATE DATABASE CompanyDB;
GO

-- Use Database
USE CompanyDB;
GO

-- Create Table 1: EmployeeDemographics
CREATE TABLE EmployeeDemographics 
(
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Age INT,
    Gender VARCHAR(50)
);

-- Create Table 2: EmployeeSalary
CREATE TABLE EmployeeSalary 
(
    EmployeeID INT,
    JobTitle VARCHAR(50),
    Salary INT,
    FOREIGN KEY (EmployeeID) REFERENCES EmployeeDemographics(EmployeeID)
);

-----------------------------------------------------
-- Insert Data into EmployeeDemographics
-----------------------------------------------------
INSERT INTO EmployeeDemographics VALUES
(1001, 'Jim', 'Halpert', 30, 'Male'),
(1002, 'Pam', 'Beasley', 30, 'Female'),
(1003, 'Dwight', 'Schrute', 29, 'Male'),
(1004, 'Angela', 'Martin', 31, 'Female'),
(1005, 'Toby', 'Flenderson', 32, 'Male'),
(1006, 'Michael', 'Scott', 35, 'Male'),
(1007, 'Meredith', 'Palmer', 32, 'Female'),
(1008, 'Stanley', 'Hudson', 38, 'Male'),
(1009, 'Kevin', 'Malone', 31, 'Male');

-----------------------------------------------------
-- Insert Data into EmployeeSalary
-----------------------------------------------------
INSERT INTO EmployeeSalary VALUES
(1001, 'Salesman', 45000),
(1002, 'Receptionist', 36000),
(1003, 'Salesman', 63000),
(1004, 'Accountant', 47000),
(1005, 'HR', 50000),
(1006, 'Regional Manager', 65000),
(1007, 'Supplier Relations', 41000),
(1008, 'Salesman', 48000),
(1009, 'Accountant', 42000);

-----------------------------------------------------
-- SELECT Queries
-----------------------------------------------------

-- 1. View all employees
SELECT * FROM EmployeeDemographics;

-- 2. View all salaries
SELECT * FROM EmployeeSalary;

-- 3. Select specific columns
SELECT FirstName, LastName, Age 
FROM EmployeeDemographics;

-----------------------------------------------------
-- WHERE Queries (Filtering)
-----------------------------------------------------

-- Employees older than 30
SELECT * 
FROM EmployeeDemographics
WHERE Age > 30;

-- Employees who are Female
SELECT * 
FROM EmployeeDemographics
WHERE Gender = 'Female';

-- Employees earning more than 50,000
SELECT * 
FROM EmployeeSalary
WHERE Salary > 50000;

-----------------------------------------------------
-- ORDER BY Queries (Sorting)
-----------------------------------------------------

-- Sort employees by Age (ascending)
SELECT * 
FROM EmployeeDemographics
ORDER BY Age ASC;

-- Sort employees by Salary (descending)
SELECT * 
FROM EmployeeSalary
ORDER BY Salary DESC;

-----------------------------------------------------
-- ALSO, you can combine WHERE and ORDER BY
-----------------------------------------------------

-- Combine both tables
SELECT 
    d.EmployeeID,
    d.FirstName,
    d.LastName,
    s.JobTitle,
    s.Salary
FROM EmployeeDemographics d
INNER JOIN EmployeeSalary s
ON d.EmployeeID = s.EmployeeID;