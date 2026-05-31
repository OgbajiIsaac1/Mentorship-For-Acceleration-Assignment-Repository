USE CompanyDB;
GO
INSERT INTO EmployeeDemographics VALUES
(1011, 'Ryan', 'Howard', 26, 'Male'),
(1012, 'Holly', 'Flax', NULL, NULL),
(1013, 'Darryl', 'Philbin', NULL, 'Male');

DROP TABLE IF EXISTS WareHouseEmployeeDemographics;

CREATE TABLE WareHouseEmployeeDemographics 
(
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Age INT,
    Gender VARCHAR(50)
);

INSERT INTO WareHouseEmployeeDemographics VALUES
(1013, 'Darryl', 'Philbin', NULL, 'Male'),
(1050, 'Roy', 'Anderson', 31, 'Male'),
(1051, 'Hidetoshi', 'Hasagawa', 40, 'Male'),
(1052, 'Val', 'Johnson', 31, 'Female');

--INNER JOIN

SELECT
    d.EmployeeID,
    d.FirstName,
    d.LastName,
    s.JobTitle,
    s.Salary
FROM EmployeeDemographics d
INNER JOIN EmployeeSalary s
ON d.EmployeeID = s.EmployeeID;

--LEFT JOIN

SELECT *
FROM EmployeeDemographics d
LEFT JOIN EmployeeSalary s
ON d.EmployeeID = s.EmployeeID;

--RIGHT JOIN

SELECT *
FROM EmployeeDemographics d
RIGHT JOIN EmployeeSalary s
ON d.EmployeeID = s.EmployeeID;

--UNION (Combine Tables)

SELECT FirstName, LastName, Age
FROM EmployeeDemographics

UNION

SELECT FirstName, LastName, Age
FROM WareHouseEmployeeDemographics;

--CASE STATEMENT

SELECT
    FirstName,
    LastName,
    Age,
    CASE
        WHEN Age > 30 THEN 'Old'
        WHEN Age BETWEEN 27 AND 30 THEN 'Adult'
        ELSE 'Young'
    END AS AgeCategory
FROM EmployeeDemographics;

--AGGREGATION (Summary Functions)

--Average Salary

SELECT AVG(Salary) AS AverageSalary
FROM EmployeeSalary;

--Count Employees

SELECT COUNT(EmployeeID) AS TotalEmployees
FROM EmployeeDemographics;

--Group By Job Title

SELECT JobTitle, AVG(Salary) AS AvgSalary
FROM EmployeeSalary
GROUP BY JobTitle;

--UPDATE DATA

UPDATE EmployeeDemographics
SET Age = 31
WHERE FirstName = 'Ryan' AND LastName = 'Howard';

--DELETE DATA

DELETE FROM EmployeeDemographics
WHERE EmployeeID IS NULL;

--FOREIGN KEY (Important Requirement)

ALTER TABLE EmployeeSalary
ADD CONSTRAINT FK_Employee
FOREIGN KEY (EmployeeID) 
REFERENCES EmployeeDemographics(EmployeeID);