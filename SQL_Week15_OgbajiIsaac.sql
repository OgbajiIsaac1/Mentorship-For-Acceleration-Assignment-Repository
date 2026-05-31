USE CompanyDB;
GO


--SUBQUERIES (SELECT, FROM, WHERE)
--Subquery in SELECT


SELECT
    EmployeeID, 
    Salary,
    (SELECT AVG(Salary) FROM EmployeeSalary) AS AllAvgSalary
FROM EmployeeSalary;


--Subquery in FROM


SELECT a.EmployeeID, a.AllAvgSalary
FROM (
    SELECT EmployeeID, Salary, AVG(Salary) OVER () AS AllAvgSalary
    FROM EmployeeSalary
) a
ORDER BY a.EmployeeID;


--Subquery in WHERE


SELECT EmployeeID, JobTitle, Salary
FROM EmployeeSalary
WHERE EmployeeID IN (
    SELECT EmployeeID
    FROM EmployeeDemographics
    WHERE Age > 30
);


--WINDOW FUNCTIONS (RANKING)
--Rank Employees by Salary


SELECT
    EmployeeID,
    JobTitle,
    Salary,
    RANK() OVER (ORDER BY Salary DESC) AS SalaryRank
FROM EmployeeSalary;


--Partition Ranking (by JobTitle)


SELECT
    EmployeeID,
    JobTitle,
    Salary,
    RANK() OVER (PARTITION BY JobTitle ORDER BY Salary DESC) AS RankByJob
FROM EmployeeSalary;


--CTE (Common Table Expression)


WITH CTE_Employee AS
(
    SELECT 
        d.EmployeeID,
        d.FirstName,
        s.JobTitle,
        s.Salary,
        AVG(s.Salary) OVER () AS AvgSalary
    FROM EmployeeDemographics d
    JOIN EmployeeSalary s
        ON d.EmployeeID = s.EmployeeID
)
SELECT FirstName, JobTitle, Salary, AvgSalary
FROM CTE_Employee;


--TEMP TABLE (Performance Optimization)


DROP TABLE IF EXISTS #TempEmployee;

CREATE TABLE #TempEmployee
(
    JobTitle VARCHAR(100),
    EmployeesPerJob INT,
    AvgAge INT,
    AvgSalary INT
);

INSERT INTO #TempEmployee
SELECT 
    s.JobTitle,
    COUNT(*) AS EmployeesPerJob,
    AVG(d.Age) AS AvgAge,
    AVG(s.Salary) AS AvgSalary
FROM EmployeeDemographics d
JOIN EmployeeSalary s
    ON d.EmployeeID = s.EmployeeID
GROUP BY s.JobTitle;

SELECT * FROM #TempEmployee;


--INDEX (Performance Improvement)


-- Create Index on EmployeeID
CREATE INDEX idx_emp_id
ON EmployeeDemographics(EmployeeID);

-- Create Index on Salary
CREATE INDEX idx_salary
ON EmployeeSalary(Salary);


--Combine Everything

WITH RankedEmployees AS
(
    SELECT 
        d.FirstName,
        s.JobTitle,
        s.Salary,
        RANK() OVER (ORDER BY s.Salary DESC) AS SalaryRank
    FROM EmployeeDemographics d
    JOIN EmployeeSalary s
        ON d.EmployeeID = s.EmployeeID
)
SELECT *
FROM RankedEmployees
WHERE SalaryRank <= 3;