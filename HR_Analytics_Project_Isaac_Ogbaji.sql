/* ============================================================
   1. DATABASE SETUP
   ============================================================

   In this step, I create the project database only if it does not
   already exist. This helps prevent errors when the script is run
   more than once.
   ============================================================ */

IF DB_ID('HR_Analytics_DB') IS NULL
BEGIN
    CREATE DATABASE HR_Analytics_DB;
END;

USE HR_Analytics_DB;

/* ============================================================
   2. RAW DATA TABLE CREATION
   ============================================================

   I create the raw HR data table only if it does not already exist.
   This table stores the original imported CSV data.
   ============================================================ */

IF OBJECT_ID('hr_data', 'U') IS NULL
BEGIN
    CREATE TABLE hr_data (
        id VARCHAR(20),
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        birthdate VARCHAR(50),
        gender VARCHAR(20),
        race VARCHAR(50),
        department VARCHAR(100),
        jobtitle VARCHAR(100),
        location VARCHAR(50),
        hire_date VARCHAR(50),
        termdate VARCHAR(100),
        location_city VARCHAR(50),
        location_state VARCHAR(50)
    );
END;





SELECT TOP 10 * FROM hr_data;


SELECT COUNT(*) FROM hr_data;

USE HR_Analytics_DB;


/* ============================================================
   4. DATA CLEANING AND PREPARATION
   ============================================================

   In this section, I clean and prepare the raw HR dataset for analysis.

   The raw dataset is stored in the hr_data table. To avoid changing the
   original imported data, I create a separate cleaned table called
   hr_data_clean.

   This step prepares the dataset by:
   - converting date columns into proper SQL Server date formats
   - cleaning termination dates that contain UTC text
   - creating employee status classifications
   - calculating employee age
   - calculating employee tenure
   - checking the cleaned data for quality issues

   The cleaned table created in this step will be used for all analysis
   in the rest of the project.
   ============================================================ */


/* ------------------------------------------------------------
   4.1 CREATE A CLEAN WORKING TABLE
   ------------------------------------------------------------

   I create a new table called hr_data_clean from the raw hr_data table.

   The birthdate and hire_date columns are stored as text in YYYY-MM-DD
   format, so I convert them into proper DATE columns using TRY_CONVERT.

   The termdate column sometimes contains the text 'UTC', so I remove
   that text before converting it into a DATETIME column.
   ------------------------------------------------------------ */

DROP TABLE IF EXISTS hr_data_clean;

SELECT
    id,
    first_name,
    last_name,
    gender,
    race,
    department,
    jobtitle,
    location,
    location_city,
    location_state,

    TRY_CONVERT(DATE, LTRIM(RTRIM(birthdate)), 23) AS birthdate,

    TRY_CONVERT(DATE, LTRIM(RTRIM(hire_date)), 23) AS hire_date,

    TRY_CONVERT(
        DATETIME,
        NULLIF(REPLACE(LTRIM(RTRIM(termdate)), ' UTC', ''), '')
    ) AS termdate

INTO hr_data_clean
FROM hr_data;

GO


/* ------------------------------------------------------------
   4.2 VERIFY THE CLEANED TABLE
   ------------------------------------------------------------

   After creating the cleaned table, I check the first 20 records to
   confirm that the date fields were converted correctly.

   This helps me make sure that birthdate, hire_date, and termdate are
   ready for analysis.
   ------------------------------------------------------------ */

SELECT TOP 20
    id,
    first_name,
    last_name,
    birthdate,
    hire_date,
    termdate
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   4.3 CHECK TOTAL RECORDS
   ------------------------------------------------------------

   I check the total number of records in the cleaned table.

   This confirms that the cleaned table contains the expected employee
   records from the raw dataset.
   ------------------------------------------------------------ */

SELECT COUNT(*) AS total_records
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   4.4 ADD ANALYSIS COLUMNS
   ------------------------------------------------------------

   I now add three new columns that will support the HR analysis.

   The new columns are:

   - employee_status: classifies employees as Active or Terminated
   - age: stores each employee's calculated age
   - tenure_years: stores how long each employee has worked in the company

   These columns make the dataset easier to analyze in later sections.
   ------------------------------------------------------------ */

ALTER TABLE hr_data_clean
ADD 
    employee_status VARCHAR(20),
    age INT,
    tenure_years INT;

GO


/* ------------------------------------------------------------
   4.5 UPDATE EMPLOYEE STATUS
   ------------------------------------------------------------

   I classify employees based on their termination date.

   My logic is:

   - If termdate is NULL, the employee is Active.
   - If termdate is in the future, the employee is still Active.
   - If termdate is in the past or today, the employee is Terminated.

   This prevents future termination dates from being incorrectly counted
   as current attrition.
   ------------------------------------------------------------ */

UPDATE hr_data_clean
SET employee_status =
    CASE
        WHEN termdate IS NULL THEN 'Active'
        WHEN termdate > GETDATE() THEN 'Active'
        ELSE 'Terminated'
    END;

GO


/* ------------------------------------------------------------
   4.6 CALCULATE EMPLOYEE AGE
   ------------------------------------------------------------

   I calculate each employee's age using the birthdate column.

   I adjust the calculation so the age is accurate even when the
   employee's birthday has not yet occurred in the current year.
   ------------------------------------------------------------ */

UPDATE hr_data_clean
SET age =
    DATEDIFF(YEAR, birthdate, GETDATE())
    - CASE
        WHEN DATEADD(YEAR, DATEDIFF(YEAR, birthdate, GETDATE()), birthdate) > GETDATE()
        THEN 1
        ELSE 0
      END
WHERE birthdate IS NOT NULL;

GO


/* ------------------------------------------------------------
   4.7 CALCULATE EMPLOYEE TENURE
   ------------------------------------------------------------

   I calculate tenure_years to measure how long each employee has worked
   in the organization.

   My tenure logic is:

   - For active employees, tenure is calculated from hire_date to today.
   - For terminated employees, tenure is calculated from hire_date to
     termdate.

   This gives a more accurate view of employee experience and retention.
   ------------------------------------------------------------ */

UPDATE hr_data_clean
SET tenure_years =
    CASE
        WHEN hire_date IS NULL THEN NULL

        WHEN termdate IS NULL OR termdate > GETDATE() THEN
            DATEDIFF(YEAR, hire_date, GETDATE())
            - CASE
                WHEN DATEADD(YEAR, DATEDIFF(YEAR, hire_date, GETDATE()), hire_date) > GETDATE()
                THEN 1
                ELSE 0
              END

        ELSE
            DATEDIFF(YEAR, hire_date, termdate)
            - CASE
                WHEN DATEADD(YEAR, DATEDIFF(YEAR, hire_date, termdate), hire_date) > termdate
                THEN 1
                ELSE 0
              END
    END;

GO


/* ------------------------------------------------------------
   4.8 VALIDATE CLEANED DATA
   ------------------------------------------------------------

   After adding and updating the analysis columns, I review the cleaned
   table to confirm that everything was created correctly.

   I check:
   - employee dates
   - employee age
   - tenure
   - employee status
   - department and job role information
   ------------------------------------------------------------ */

SELECT TOP 20
    id,
    first_name,
    last_name,
    birthdate,
    age,
    hire_date,
    termdate,
    tenure_years,
    employee_status,
    department,
    jobtitle,
    location,
    location_city,
    location_state
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   4.9 CHECK EMPLOYEE STATUS DISTRIBUTION
   ------------------------------------------------------------

   I check how many employees are classified as Active and Terminated.

   This is an important validation step because employee_status will be
   used later for attrition and retention analysis.
   ------------------------------------------------------------ */

SELECT
    employee_status,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY employee_status
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   4.10 CHECK FOR MISSING VALUES
   ------------------------------------------------------------

   I check for missing values in important columns after cleaning.

   Missing termdate values are expected because active employees do not
   have termination dates.

   However, missing birthdate, hire_date, age, or tenure_years values
   may affect analysis and should be reviewed.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN birthdate IS NULL THEN 1 ELSE 0 END) AS missing_birthdate,
    SUM(CASE WHEN hire_date IS NULL THEN 1 ELSE 0 END) AS missing_hire_date,
    SUM(CASE WHEN termdate IS NULL THEN 1 ELSE 0 END) AS missing_termdate,
    SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) AS missing_age,
    SUM(CASE WHEN tenure_years IS NULL THEN 1 ELSE 0 END) AS missing_tenure
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   4.11 FINAL DATA QUALITY CHECK
   ------------------------------------------------------------

   Before moving into analysis, I check for possible data quality issues.

   This query looks for:
   - missing hire dates
   - missing birthdates
   - missing ages
   - negative tenure values

   This helps ensure that the dataset is reliable enough for HR analysis.
   ------------------------------------------------------------ */

SELECT *
FROM hr_data_clean
WHERE hire_date IS NULL
   OR birthdate IS NULL
   OR age IS NULL
   OR tenure_years < 0;

GO


/* ------------------------------------------------------------
   4.12 STEP 4 SUMMARY
   ------------------------------------------------------------

   At the end of this step, I now have a cleaned and analysis-ready table
   called hr_data_clean.

   This table contains:
   - properly converted date columns
   - employee status classification
   - calculated employee age
   - calculated employee tenure
   - preserved original data in the raw hr_data table

   This cleaned table will be used for all remaining HR analysis,
   including workforce overview, demographics, department analysis,
   tenure analysis, and attrition analysis.
   ------------------------------------------------------------ */


   /* ============================================================
   5. WORKFORCE OVERVIEW AND BASIC HR METRICS
   ============================================================

   In this section, I begin the main HR analysis by creating a high-level
   overview of the organization's workforce.

   The goal of this section is to understand the overall size and status
   of the workforce.

   I analyze:
   - total number of employees
   - active employees
   - terminated employees
   - attrition rate
   - retention rate
   - workforce distribution by location type
   - workforce distribution by state and city

   These metrics provide a strong foundation for understanding employee
   movement, workforce stability, and organizational structure.
   ============================================================ */


/* ------------------------------------------------------------
   5.1 TOTAL NUMBER OF EMPLOYEES
   ------------------------------------------------------------

   I start by calculating the total number of employee records in the
   cleaned dataset.

   This gives me the overall workforce size represented in the HR data.
   ------------------------------------------------------------ */

SELECT 
    COUNT(*) AS total_employees
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   5.2 ACTIVE VS TERMINATED EMPLOYEES
   ------------------------------------------------------------

   Next, I group employees by employee_status.

   This helps me understand how many employees are currently active and
   how many have already left the organization.
   ------------------------------------------------------------ */

SELECT
    employee_status,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY employee_status
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   5.3 WORKFORCE STATUS PERCENTAGE
   ------------------------------------------------------------

   In this query, I calculate the percentage share of each employee
   status group.

   This gives a clearer view of the proportion of active and terminated
   employees in the dataset.
   ------------------------------------------------------------ */

SELECT
    employee_status,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY employee_status
ORDER BY percentage_share DESC;

GO


/* ------------------------------------------------------------
   5.4 ATTRITION RATE
   ------------------------------------------------------------

   Attrition rate measures the percentage of employees who have left
   the organization.

   In this project, I define attrition as employees whose employee_status
   is Terminated.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   5.5 RETENTION RATE
   ------------------------------------------------------------

   Retention rate measures the percentage of employees who are still
   active in the organization.

   This is useful for understanding workforce stability and employee
   continuity.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS retention_rate_percentage
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   5.6 EXECUTIVE WORKFORCE SUMMARY USING CTE
   ------------------------------------------------------------

   I use a Common Table Expression to create a clean executive summary
   of the workforce.

   This query summarizes:
   - total employees
   - active employees
   - terminated employees
   - retention rate
   - attrition rate

   This gives a compact HR dashboard-style summary.
   ------------------------------------------------------------ */

WITH workforce_summary AS (
    SELECT
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees
    FROM hr_data_clean
)

SELECT
    total_employees,
    active_employees,
    terminated_employees,
    CAST(active_employees * 100.0 / total_employees AS DECIMAL(10,2)) AS retention_rate_percentage,
    CAST(terminated_employees * 100.0 / total_employees AS DECIMAL(10,2)) AS attrition_rate_percentage
FROM workforce_summary;

GO


/* ------------------------------------------------------------
   5.7 WORKFORCE DISTRIBUTION BY LOCATION TYPE
   ------------------------------------------------------------

   I analyze how employees are distributed by work location.

   This shows whether most employees work from Headquarters or remotely.
   This is useful for understanding the organization's workforce model.
   ------------------------------------------------------------ */

SELECT
    location,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY location
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   5.8 WORKFORCE DISTRIBUTION BY STATE
   ------------------------------------------------------------

   I analyze employee distribution by state.

   This helps identify where the organization's workforce is
   geographically concentrated.
   ------------------------------------------------------------ */

SELECT
    location_state,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY location_state
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   5.9 WORKFORCE DISTRIBUTION BY CITY
   ------------------------------------------------------------

   I analyze employee distribution by city and state.

   This gives a more detailed geographic view of the workforce.
   ------------------------------------------------------------ */

SELECT
    location_city,
    location_state,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY location_city, location_state
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   5.10 STEP 5 SUMMARY
   ------------------------------------------------------------

   In this section, I created a high-level overview of the workforce.

   I analyzed:
   - total employee count
   - active employees
   - terminated employees
   - attrition rate
   - retention rate
   - workforce distribution by location type
   - workforce distribution by state and city

   These metrics provide a strong foundation for deeper HR analysis in
   the next sections.
   ------------------------------------------------------------ */



   /* ============================================================
   6. DEMOGRAPHIC ANALYSIS
   ============================================================

   In this section, I analyze the demographic structure of the workforce.

   Demographic analysis is important in HR Analytics because it helps
   organizations understand employee representation across gender, race,
   age, and departments.

   This section helps answer questions such as:

   - What is the gender distribution of employees?
   - What is the racial composition of the workforce?
   - Which age groups are most represented?
   - How are gender and race distributed across departments?
   - Which demographic groups have higher attrition?
   - Which departments show broader workforce diversity?

   These insights can support workforce planning, diversity monitoring,
   inclusion strategies, and better HR decision-making.
   ============================================================ */


/* ------------------------------------------------------------
   6.1 GENDER DISTRIBUTION
   ------------------------------------------------------------

   I start by analyzing the gender distribution of employees.

   This helps me understand how employees are represented by gender
   across the organization.
   ------------------------------------------------------------ */

SELECT
    gender,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY gender
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   6.2 RACE DISTRIBUTION
   ------------------------------------------------------------

   Next, I analyze the racial composition of the workforce.

   This gives insight into workforce diversity and shows the
   representation of different race groups within the organization.
   ------------------------------------------------------------ */

SELECT
    race,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY race
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   6.3 AGE DISTRIBUTION
   ------------------------------------------------------------

   I analyze the distribution of employees by exact age.

   This helps me understand the age structure of the workforce and
   identify whether the organization has a younger, mid-career, or older
   employee population.
   ------------------------------------------------------------ */

SELECT
    age,
    COUNT(*) AS total_employees
FROM hr_data_clean
WHERE age IS NOT NULL
GROUP BY age
ORDER BY age;

GO


/* ------------------------------------------------------------
   6.4 AGE GROUP SEGMENTATION
   ------------------------------------------------------------

   Instead of analyzing every individual age separately, I group employees
   into age brackets.

   Age groups make the analysis easier to interpret and more useful for
   HR reporting.

   The age groups are:
   - Under 25
   - 25 to 34
   - 35 to 44
   - 45 to 54
   - 55 and Above
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END AS age_group,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   6.5 GENDER DISTRIBUTION BY DEPARTMENT
   ------------------------------------------------------------

   I analyze how gender is distributed across departments.

   This helps identify whether certain departments have stronger
   representation from specific gender groups.
   ------------------------------------------------------------ */

SELECT
    department,
    gender,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY department, gender
ORDER BY department, total_employees DESC;

GO


/* ------------------------------------------------------------
   6.6 RACE DISTRIBUTION BY DEPARTMENT
   ------------------------------------------------------------

   Here, I analyze racial representation within each department.

   This allows me to see whether some departments have broader employee
   representation across race groups.
   ------------------------------------------------------------ */

SELECT
    department,
    race,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY department, race
ORDER BY department, total_employees DESC;

GO


/* ------------------------------------------------------------
   6.7 DEPARTMENT DEMOGRAPHIC SUMMARY USING CTE
   ------------------------------------------------------------

   In this query, I use a Common Table Expression to summarize
   demographic information by department.

   For each department, I calculate:
   - total employees
   - number of gender groups represented
   - number of race groups represented
   - average employee age

   This gives a more complete view of department-level workforce
   composition.
   ------------------------------------------------------------ */

WITH department_demographics AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        COUNT(DISTINCT gender) AS gender_groups_represented,
        COUNT(DISTINCT race) AS race_groups_represented,
        CAST(AVG(CAST(age AS FLOAT)) AS DECIMAL(10,2)) AS average_age
    FROM hr_data_clean
    WHERE age IS NOT NULL
    GROUP BY department
)

SELECT
    department,
    total_employees,
    gender_groups_represented,
    race_groups_represented,
    average_age
FROM department_demographics
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   6.8 RANK DEPARTMENTS BY DEMOGRAPHIC DIVERSITY
   ------------------------------------------------------------

   In this query, I rank departments based on the number of race groups
   and gender groups represented.

   I use the RANK window function to identify departments with broader
   demographic representation.

   This strengthens the project because it combines HR insight with
   advanced SQL.
   ------------------------------------------------------------ */

WITH diversity_summary AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        COUNT(DISTINCT race) AS race_groups_represented,
        COUNT(DISTINCT gender) AS gender_groups_represented
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    race_groups_represented,
    gender_groups_represented,
    RANK() OVER (
        ORDER BY race_groups_represented DESC, gender_groups_represented DESC
    ) AS diversity_rank
FROM diversity_summary
ORDER BY diversity_rank, total_employees DESC;

GO


/* ------------------------------------------------------------
   6.9 AGE GROUP BY EMPLOYEE STATUS
   ------------------------------------------------------------

   I compare age groups against employee status.

   This helps me understand whether attrition is stronger among certain
   age groups.

   For example, if a younger age group has a higher number of terminated
   employees, HR may need to investigate early-career retention.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END AS age_group,
    employee_status,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END,
    employee_status
ORDER BY age_group, employee_status;

GO


/* ------------------------------------------------------------
   6.10 ATTRITION RATE BY GENDER
   ------------------------------------------------------------

   I analyze attrition rate by gender.

   This helps identify whether employee exits are evenly distributed
   across gender groups or concentrated in specific groups.
   ------------------------------------------------------------ */

SELECT
    gender,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY gender
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   6.11 ATTRITION RATE BY RACE
   ------------------------------------------------------------

   I analyze attrition rate by race.

   This helps identify whether employee exits are evenly distributed
   across race groups or concentrated in particular groups.

   This kind of insight can support deeper HR investigation and retention
   planning.
   ------------------------------------------------------------ */

SELECT
    race,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY race
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   6.12 STEP 6 SUMMARY
   ------------------------------------------------------------

   In this section, I explored the demographic characteristics of the
   workforce.

   I analyzed:
   - gender distribution
   - race distribution
   - employee age distribution
   - age group segmentation
   - gender distribution by department
   - race distribution by department
   - department demographic summary using a CTE
   - department diversity ranking using a window function
   - age group by employee status
   - attrition rate by gender
   - attrition rate by race

   These insights are important because HR analytics is not only about
   counting employees. It is also about understanding workforce
   representation, employee composition, and where retention patterns may
   differ across demographic groups.

   The next section will focus on department and job role analysis.
   ------------------------------------------------------------ */



   /* ============================================================
   7. DEPARTMENT AND JOB ROLE ANALYSIS
   ============================================================

   In this section, I analyze the workforce by department and job role.

   Department and job role analysis is important because it helps HR and
   business leaders understand how employees are distributed across the
   organization.

   This section helps answer questions such as:

   - Which departments have the most employees?
   - Which job titles are most common?
   - Which departments have the highest number of active employees?
   - Which departments have the highest number of terminated employees?
   - Which job roles experience the most employee exits?
   - How does workforce distribution vary across departments and roles?

   These insights support workforce planning, departmental staffing
   decisions, and role-based retention strategies.
   ============================================================ */


/* ------------------------------------------------------------
   7.1 EMPLOYEE COUNT BY DEPARTMENT
   ------------------------------------------------------------

   I start by counting the number of employees in each department.

   This helps identify the largest and smallest departments in the
   organization.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY department
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   7.2 EMPLOYEE COUNT BY JOB TITLE
   ------------------------------------------------------------

   Next, I analyze the distribution of employees by job title.

   This helps identify the most common roles in the organization.
   ------------------------------------------------------------ */

SELECT
    jobtitle,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY jobtitle
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   7.3 ACTIVE EMPLOYEES BY DEPARTMENT
   ------------------------------------------------------------

   I analyze active employees by department.

   This shows the current workforce strength of each department.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS active_employees
FROM hr_data_clean
WHERE employee_status = 'Active'
GROUP BY department
ORDER BY active_employees DESC;

GO


/* ------------------------------------------------------------
   7.4 TERMINATED EMPLOYEES BY DEPARTMENT
   ------------------------------------------------------------

   I analyze terminated employees by department.

   This helps identify departments with higher employee exits.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS terminated_employees
FROM hr_data_clean
WHERE employee_status = 'Terminated'
GROUP BY department
ORDER BY terminated_employees DESC;

GO


/* ------------------------------------------------------------
   7.5 DEPARTMENT ATTRITION RATE
   ------------------------------------------------------------

   In this query, I calculate attrition rate by department.

   This is more useful than simply counting terminated employees because
   departments may have different workforce sizes.

   Attrition rate shows the percentage of employees in each department
   who have left the organization.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY department
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   7.6 JOB TITLE ATTRITION RATE
   ------------------------------------------------------------

   Here, I calculate attrition rate by job title.

   This helps identify specific roles that may have higher employee
   turnover.

   Role-level attrition analysis is useful because retention issues may
   not always appear at department level.
   ------------------------------------------------------------ */

SELECT
    jobtitle,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY jobtitle
HAVING COUNT(*) >= 10
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   7.7 RANK DEPARTMENTS BY HEADCOUNT USING WINDOW FUNCTION
   ------------------------------------------------------------

   I use the RANK window function to rank departments by total workforce
   size.

   This helps identify departments with the largest employee population.
   ------------------------------------------------------------ */

WITH department_headcount AS (
    SELECT
        department,
        COUNT(*) AS total_employees
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    RANK() OVER (ORDER BY total_employees DESC) AS department_headcount_rank
FROM department_headcount
ORDER BY department_headcount_rank;

GO


/* ------------------------------------------------------------
   7.8 RANK DEPARTMENTS BY ATTRITION RATE
   ------------------------------------------------------------

   I rank departments by attrition rate using a CTE and window function.

   This highlights departments that may need stronger retention
   strategies.
   ------------------------------------------------------------ */

WITH department_attrition AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    terminated_employees,
    attrition_rate_percentage,
    RANK() OVER (ORDER BY attrition_rate_percentage DESC) AS attrition_rank
FROM department_attrition
ORDER BY attrition_rank;

GO


/* ------------------------------------------------------------
   7.9 TOP JOB ROLES BY HEADCOUNT
   ------------------------------------------------------------

   I identify the top job roles by employee count.

   This helps show which roles make up the largest parts of the
   workforce.
   ------------------------------------------------------------ */

SELECT TOP 10
    jobtitle,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY jobtitle
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   7.10 TOP JOB ROLES BY TERMINATION COUNT
   ------------------------------------------------------------

   I identify the job roles with the highest number of terminated
   employees.

   This helps HR focus attention on roles where employee exits are more
   frequent.
   ------------------------------------------------------------ */

SELECT TOP 10
    jobtitle,
    COUNT(*) AS terminated_employees
FROM hr_data_clean
WHERE employee_status = 'Terminated'
GROUP BY jobtitle
ORDER BY terminated_employees DESC;

GO

/* ------------------------------------------------------------
   7.11 DEPARTMENT AND LOCATION COMPARISON
   ------------------------------------------------------------

   I compare departments by work location.

   This helps identify whether certain departments are more concentrated
   at Headquarters or among Remote employees.
   ------------------------------------------------------------ */

SELECT
    department,
    location,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY department, location
ORDER BY department, total_employees DESC;

GO


/* ------------------------------------------------------------
   7.12 STEP 7 SUMMARY
   ------------------------------------------------------------

   In this section, I analyzed workforce distribution across departments
   and job roles.

   I analyzed:
   - employee count by department
   - employee count by job title
   - active employees by department
   - terminated employees by department
   - attrition rate by department
   - attrition rate by job title
   - department headcount ranking using a window function
   - department attrition ranking using a CTE and window function
   - top job roles by headcount
   - top job roles by termination count
   - department distribution by work location

   These insights help identify which departments and roles dominate the
   workforce and where retention attention may be needed.

   The next section will focus on tenure and retention analysis.
   ------------------------------------------------------------ */




   /* ============================================================
   8. TENURE AND RETENTION ANALYSIS
   ============================================================

   In this section, I analyze employee tenure and retention patterns.

   Tenure analysis is important in HR Analytics because it helps the
   organization understand how long employees typically stay and whether
   retention differs across departments, job roles, and employee groups.

   This section helps answer questions such as:

   - What is the average employee tenure?
   - Which employees have stayed the longest?
   - Which departments have the highest average tenure?
   - How does tenure differ between active and terminated employees?
   - Which tenure groups have higher attrition?
   - Which departments appear more stable from a retention perspective?

   These insights can help HR leaders understand workforce stability,
   long-term employee engagement, and possible retention risks.
   ============================================================ */


/* ------------------------------------------------------------
   8.1 AVERAGE EMPLOYEE TENURE
   ------------------------------------------------------------

   I start by calculating the average employee tenure across the entire
   organization.

   This gives a high-level view of how long employees typically stay
   with the company.
   ------------------------------------------------------------ */

SELECT
    CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years
FROM hr_data_clean
WHERE tenure_years IS NOT NULL;

GO


/* ------------------------------------------------------------
   8.2 TENURE SUMMARY BY EMPLOYEE STATUS
   ------------------------------------------------------------

   I compare average tenure between Active and Terminated employees.

   This helps me understand whether employees who left had shorter or
   longer tenure compared to employees who are still active.
   ------------------------------------------------------------ */

SELECT
    employee_status,
    COUNT(*) AS total_employees,
    CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years,
    MIN(tenure_years) AS minimum_tenure_years,
    MAX(tenure_years) AS maximum_tenure_years
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
GROUP BY employee_status
ORDER BY average_tenure_years DESC;

GO


/* ------------------------------------------------------------
   8.3 TENURE DISTRIBUTION
   ------------------------------------------------------------

   I analyze how employees are distributed by exact tenure year.

   This helps me see whether most employees are new, mid-tenure, or
   long-serving employees.
   ------------------------------------------------------------ */

SELECT
    tenure_years,
    COUNT(*) AS total_employees
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
GROUP BY tenure_years
ORDER BY tenure_years;

GO


/* ------------------------------------------------------------
   8.4 TENURE GROUP SEGMENTATION
   ------------------------------------------------------------

   Instead of analyzing every exact tenure year, I group employees into
   tenure bands.

   Tenure groups make the analysis easier to interpret for HR reporting.

   The tenure groups are:
   - Less than 1 Year
   - 1 to 3 Years
   - 4 to 6 Years
   - 7 to 10 Years
   - More than 10 Years
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END AS tenure_group,
    COUNT(*) AS total_employees,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(10,2)) AS percentage_share
FROM hr_data_clean
GROUP BY
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   8.5 TENURE GROUP BY EMPLOYEE STATUS
   ------------------------------------------------------------

   I compare tenure groups against employee status.

   This helps identify whether attrition is concentrated among newer
   employees, mid-tenure employees, or long-serving employees.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END AS tenure_group,
    employee_status,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END,
    employee_status
ORDER BY tenure_group, employee_status;

GO


/* ------------------------------------------------------------
   8.6 ATTRITION RATE BY TENURE GROUP
   ------------------------------------------------------------

   I calculate attrition rate for each tenure group.

   This is important because it shows whether employees are more likely
   to leave during a specific stage of their employment lifecycle.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END AS tenure_group,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   8.7 AVERAGE TENURE BY DEPARTMENT
   ------------------------------------------------------------

   I calculate average tenure for each department.

   This helps identify departments where employees tend to stay longer
   or leave earlier.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS total_employees,
    CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
GROUP BY department
ORDER BY average_tenure_years DESC;

GO


/* ------------------------------------------------------------
   8.8 AVERAGE TENURE BY JOB TITLE
   ------------------------------------------------------------

   Here, I calculate average tenure by job title.

   I only include job titles with at least 10 employees to avoid drawing
   conclusions from very small sample sizes.
   ------------------------------------------------------------ */

SELECT
    jobtitle,
    COUNT(*) AS total_employees,
    CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
GROUP BY jobtitle
HAVING COUNT(*) >= 10
ORDER BY average_tenure_years DESC;

GO


/* ------------------------------------------------------------
   8.9 LONGEST SERVING EMPLOYEES
   ------------------------------------------------------------

   I identify the top 20 longest-serving employees in the dataset.

   This helps recognize employees with the highest organizational tenure.
   ------------------------------------------------------------ */

SELECT TOP 20
    id,
    first_name,
    last_name,
    department,
    jobtitle,
    hire_date,
    termdate,
    employee_status,
    tenure_years
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
ORDER BY tenure_years DESC, hire_date ASC;

GO


/* ------------------------------------------------------------
   8.10 RANK EMPLOYEES BY TENURE USING WINDOW FUNCTION
   ------------------------------------------------------------

   I use a window function to rank employees by tenure.

   This demonstrates advanced SQL while also identifying the most
   experienced employees in the organization.
   ------------------------------------------------------------ */

SELECT
    id,
    first_name,
    last_name,
    department,
    jobtitle,
    employee_status,
    tenure_years,
    RANK() OVER (ORDER BY tenure_years DESC) AS tenure_rank
FROM hr_data_clean
WHERE tenure_years IS NOT NULL
ORDER BY tenure_rank;

GO


/* ------------------------------------------------------------
   8.11 DEPARTMENT RETENTION SUMMARY USING CTE
   ------------------------------------------------------------

   I use a Common Table Expression to summarize retention by department.

   For each department, I calculate:
   - total employees
   - active employees
   - terminated employees
   - retention rate
   - average tenure

   This gives a strong view of department-level workforce stability.
   ------------------------------------------------------------ */

WITH department_retention AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
        CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years
    FROM hr_data_clean
    WHERE tenure_years IS NOT NULL
    GROUP BY department
)

SELECT
    department,
    total_employees,
    active_employees,
    terminated_employees,
    CAST(active_employees * 100.0 / total_employees AS DECIMAL(10,2)) AS retention_rate_percentage,
    average_tenure_years
FROM department_retention
ORDER BY retention_rate_percentage DESC, average_tenure_years DESC;

GO


/* ------------------------------------------------------------
   8.12 RANK DEPARTMENTS BY RETENTION RATE
   ------------------------------------------------------------

   I rank departments by retention rate.

   This helps identify departments with stronger workforce stability
   compared to others.
   ------------------------------------------------------------ */

WITH department_retention AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees
    FROM hr_data_clean
    GROUP BY department
),
retention_rates AS (
    SELECT
        department,
        total_employees,
        active_employees,
        terminated_employees,
        CAST(active_employees * 100.0 / total_employees AS DECIMAL(10,2)) AS retention_rate_percentage
    FROM department_retention
)

SELECT
    department,
    total_employees,
    active_employees,
    terminated_employees,
    retention_rate_percentage,
    RANK() OVER (ORDER BY retention_rate_percentage DESC) AS retention_rank
FROM retention_rates
ORDER BY retention_rank;

GO


/* ------------------------------------------------------------
   8.13 STEP 8 SUMMARY
   ------------------------------------------------------------

   In this section, I analyzed employee tenure and retention patterns.

   I analyzed:
   - average employee tenure
   - tenure by employee status
   - tenure distribution
   - tenure group segmentation
   - tenure group by employee status
   - attrition rate by tenure group
   - average tenure by department
   - average tenure by job title
   - longest-serving employees
   - employee tenure ranking using a window function
   - department retention summary using a CTE
   - department retention ranking using a window function

   These insights help show how long employees stay with the organization
   and where retention appears strongest or weakest.

   The next section will focus more deeply on attrition analysis.
   ------------------------------------------------------------ */


   /* ============================================================
   9. ATTRITION ANALYSIS
   ============================================================

   In this section, I analyze employee attrition in detail.

   Attrition analysis is one of the most important parts of HR Analytics
   because it helps organizations understand where employee exits are
   happening and which workforce groups may need retention attention.

   This section helps answer questions such as:

   - What is the overall attrition rate?
   - Which departments have the highest attrition rate?
   - Which job roles have the highest attrition rate?
   - How does attrition vary by gender, race, age group, and tenure group?
   - How has attrition changed over time?
   - Which employee groups may require stronger retention strategies?

   These insights can support HR planning, employee engagement strategies,
   and workforce stability improvement.
   ============================================================ */


/* ------------------------------------------------------------
   9.1 OVERALL ATTRITION SUMMARY
   ------------------------------------------------------------

   I begin by calculating the overall attrition summary.

   This query shows:
   - total employees
   - active employees
   - terminated employees
   - overall attrition rate
   - overall retention rate

   This provides a high-level view of workforce stability.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage,

    CAST(
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS retention_rate_percentage
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   9.2 ATTRITION BY DEPARTMENT
   ------------------------------------------------------------

   I calculate attrition rate by department.

   This helps identify departments where employee exits are more
   concentrated.

   This is more meaningful than only counting terminated employees because
   departments may have different workforce sizes.
   ------------------------------------------------------------ */

SELECT
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY department
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.3 ATTRITION BY JOB TITLE
   ------------------------------------------------------------

   I calculate attrition rate by job title.

   To make the analysis more reliable, I only include job titles with at
   least 10 employees. This helps avoid drawing conclusions from very
   small groups.
   ------------------------------------------------------------ */

SELECT
    jobtitle,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY jobtitle
HAVING COUNT(*) >= 10
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.4 ATTRITION BY LOCATION TYPE
   ------------------------------------------------------------

   I compare attrition between Headquarters and Remote employees.

   This helps identify whether work location may be related to employee
   exits.
   ------------------------------------------------------------ */

SELECT
    location,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY location
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.5 ATTRITION BY STATE
   ------------------------------------------------------------

   I analyze attrition by employee state.

   This helps identify geographic areas where employee exits may be more
   common.
   ------------------------------------------------------------ */

SELECT
    location_state,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY location_state
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.6 ATTRITION BY AGE GROUP
   ------------------------------------------------------------

   I analyze attrition by age group.

   This helps reveal whether certain age groups have higher employee
   exits than others.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END AS age_group,

    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age >= 55 THEN '55 and Above'
        ELSE 'Unknown'
    END
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.7 ATTRITION BY TENURE GROUP
   ------------------------------------------------------------

   I analyze attrition by tenure group.

   This helps identify whether employee exits are more common among
   newer employees, mid-tenure employees, or long-serving employees.
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END AS tenure_group,

    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.8 YEARLY TERMINATION TREND
   ------------------------------------------------------------

   I analyze the number of employee terminations by year.

   This helps identify whether employee exits increased or decreased
   over time.
   ------------------------------------------------------------ */

SELECT
    YEAR(termdate) AS termination_year,
    COUNT(*) AS terminated_employees
FROM hr_data_clean
WHERE employee_status = 'Terminated'
  AND termdate IS NOT NULL
GROUP BY YEAR(termdate)
ORDER BY termination_year;

GO


/* ------------------------------------------------------------
   9.9 MONTHLY TERMINATION TREND
   ------------------------------------------------------------

   I analyze employee terminations by year and month.

   This gives a more detailed view of when employee exits happened.
   ------------------------------------------------------------ */

SELECT
    YEAR(termdate) AS termination_year,
    MONTH(termdate) AS termination_month,
    COUNT(*) AS terminated_employees
FROM hr_data_clean
WHERE employee_status = 'Terminated'
  AND termdate IS NOT NULL
GROUP BY YEAR(termdate), MONTH(termdate)
ORDER BY termination_year, termination_month;

GO


/* ------------------------------------------------------------
   9.10 ATTRITION RANKING BY DEPARTMENT USING CTE
   ------------------------------------------------------------

   I use a Common Table Expression to calculate department attrition,
   then rank departments by attrition rate.

   This helps identify departments with the highest attrition risk.
   ------------------------------------------------------------ */

WITH department_attrition AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    terminated_employees,
    attrition_rate_percentage,
    RANK() OVER (ORDER BY attrition_rate_percentage DESC) AS attrition_rank
FROM department_attrition
ORDER BY attrition_rank;

GO


/* ------------------------------------------------------------
   9.11 ATTRITION RANKING BY JOB TITLE USING CTE
   ------------------------------------------------------------

   I rank job titles by attrition rate.

   I only include job titles with at least 10 employees to keep the
   analysis practical and reliable.
   ------------------------------------------------------------ */

WITH jobtitle_attrition AS (
    SELECT
        jobtitle,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage
    FROM hr_data_clean
    GROUP BY jobtitle
    HAVING COUNT(*) >= 10
)

SELECT
    jobtitle,
    total_employees,
    terminated_employees,
    attrition_rate_percentage,
    RANK() OVER (ORDER BY attrition_rate_percentage DESC) AS attrition_rank
FROM jobtitle_attrition
ORDER BY attrition_rank, total_employees DESC;

GO


/* ------------------------------------------------------------
   9.12 HIGH ATTRITION RISK SEGMENTS
   ------------------------------------------------------------

   I identify workforce segments with relatively high attrition.

   This query combines department, location, and tenure group to reveal
   where attrition may be more concentrated.

   I only include groups with at least 20 employees to avoid overreacting
   to very small sample sizes.
   ------------------------------------------------------------ */

SELECT
    department,
    location,
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END AS tenure_group,

    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY
    department,
    location,
    CASE
        WHEN tenure_years < 1 THEN 'Less than 1 Year'
        WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
        WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
        WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
        WHEN tenure_years > 10 THEN 'More than 10 Years'
        ELSE 'Unknown'
    END
HAVING COUNT(*) >= 20
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   9.13 STEP 9 SUMMARY
   ------------------------------------------------------------

   In this section, I performed a detailed attrition analysis.

   I analyzed:
   - overall attrition and retention
   - attrition by department
   - attrition by job title
   - attrition by location type
   - attrition by state
   - attrition by age group
   - attrition by tenure group
   - yearly termination trends
   - monthly termination trends
   - department attrition ranking using a CTE and window function
   - job title attrition ranking using a CTE and window function
   - high attrition risk segments

   These insights help identify where employee exits are concentrated
   and where HR may need to focus retention strategies.

   The next section will summarize the final findings and recommendations
   from the project.
   ------------------------------------------------------------ */




   /* ============================================================
   10. FINAL HR INSIGHTS AND RECOMMENDATIONS
   ============================================================

   In this final section, I summarize the most important HR insights
   from the analysis.

   The goal of this section is to bring together the key findings from
   workforce overview, demographics, department analysis, tenure analysis,
   and attrition analysis.

   This section helps answer final business questions such as:

   - What is the overall workforce health?
   - Which departments require retention attention?
   - Which employee groups show higher attrition?
   - Which departments have stronger retention?
   - What recommendations can HR consider based on the data?

   This section turns SQL analysis into business insight.
   ============================================================ */


/* ------------------------------------------------------------
   10.1 FINAL EXECUTIVE HR SUMMARY
   ------------------------------------------------------------

   I create a final executive summary of the organization's workforce.

   This query gives a compact snapshot of:
   - total employees
   - active employees
   - terminated employees
   - attrition rate
   - retention rate
   - average age
   - average tenure

   This can be used as the main KPI summary for the project.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage,

    CAST(
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS retention_rate_percentage,

    CAST(AVG(CAST(age AS FLOAT)) AS DECIMAL(10,2)) AS average_employee_age,
    CAST(AVG(CAST(tenure_years AS FLOAT)) AS DECIMAL(10,2)) AS average_tenure_years
FROM hr_data_clean;

GO


/* ------------------------------------------------------------
   10.2 TOP 5 DEPARTMENTS BY HEADCOUNT
   ------------------------------------------------------------

   I identify the five largest departments by employee count.

   This helps show where the workforce is most concentrated.
   ------------------------------------------------------------ */

SELECT TOP 5
    department,
    COUNT(*) AS total_employees
FROM hr_data_clean
GROUP BY department
ORDER BY total_employees DESC;

GO


/* ------------------------------------------------------------
   10.3 TOP 5 DEPARTMENTS BY ATTRITION RATE
   ------------------------------------------------------------

   I identify the departments with the highest attrition rate.

   This helps highlight departments that may require stronger retention
   strategies.
   ------------------------------------------------------------ */

SELECT TOP 5
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS attrition_rate_percentage
FROM hr_data_clean
GROUP BY department
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.4 TOP 5 DEPARTMENTS BY RETENTION RATE
   ------------------------------------------------------------

   I identify the departments with the strongest retention rate.

   These departments may have stronger workforce stability and can be
   studied for positive HR practices.
   ------------------------------------------------------------ */

SELECT TOP 5
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    CAST(
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS retention_rate_percentage
FROM hr_data_clean
GROUP BY department
ORDER BY retention_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.5 ATTRITION RISK SUMMARY BY DEPARTMENT
   ------------------------------------------------------------

   I create a department-level risk summary.

   I classify departments into attrition risk categories based on their
   attrition rate:

   - High Risk: attrition rate is 20% or higher
   - Medium Risk: attrition rate is between 10% and 19.99%
   - Low Risk: attrition rate is below 10%

   This helps convert raw attrition numbers into a business-friendly
   risk classification.
   ------------------------------------------------------------ */

WITH department_attrition AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,
        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    terminated_employees,
    attrition_rate_percentage,
    CASE
        WHEN attrition_rate_percentage >= 20 THEN 'High Risk'
        WHEN attrition_rate_percentage >= 10 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS attrition_risk_level
FROM department_attrition
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.6 RETENTION STRENGTH SUMMARY BY DEPARTMENT
   ------------------------------------------------------------

   I summarize department retention strength.

   Departments are classified based on retention rate:

   - Strong Retention: 90% and above
   - Moderate Retention: 80% to 89.99%
   - Needs Attention: below 80%

   This helps identify departments that are stable and departments that
   may need HR intervention.
   ------------------------------------------------------------ */

WITH department_retention AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        CAST(
            SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS retention_rate_percentage
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    active_employees,
    retention_rate_percentage,
    CASE
        WHEN retention_rate_percentage >= 90 THEN 'Strong Retention'
        WHEN retention_rate_percentage >= 80 THEN 'Moderate Retention'
        ELSE 'Needs Attention'
    END AS retention_strength
FROM department_retention
ORDER BY retention_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.7 EMPLOYEE LIFECYCLE INSIGHT BY TENURE GROUP
   ------------------------------------------------------------

   I summarize attrition by tenure group and classify each group by
   retention concern.

   This helps HR understand at what stage employees may be more likely
   to leave the organization.
   ------------------------------------------------------------ */

WITH tenure_attrition AS (
    SELECT
        CASE
            WHEN tenure_years < 1 THEN 'Less than 1 Year'
            WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
            WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
            WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
            WHEN tenure_years > 10 THEN 'More than 10 Years'
            ELSE 'Unknown'
        END AS tenure_group,

        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage
    FROM hr_data_clean
    GROUP BY
        CASE
            WHEN tenure_years < 1 THEN 'Less than 1 Year'
            WHEN tenure_years BETWEEN 1 AND 3 THEN '1-3 Years'
            WHEN tenure_years BETWEEN 4 AND 6 THEN '4-6 Years'
            WHEN tenure_years BETWEEN 7 AND 10 THEN '7-10 Years'
            WHEN tenure_years > 10 THEN 'More than 10 Years'
            ELSE 'Unknown'
        END
)

SELECT
    tenure_group,
    total_employees,
    terminated_employees,
    attrition_rate_percentage,
    CASE
        WHEN attrition_rate_percentage >= 20 THEN 'High Retention Concern'
        WHEN attrition_rate_percentage >= 10 THEN 'Medium Retention Concern'
        ELSE 'Low Retention Concern'
    END AS retention_concern_level
FROM tenure_attrition
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.8 FINAL BUSINESS RECOMMENDATION MATRIX
   ------------------------------------------------------------

   I create a final recommendation matrix based on department attrition
   and retention performance.

   This query translates the analysis into practical HR action areas.
   ------------------------------------------------------------ */

WITH department_summary AS (
    SELECT
        department,
        COUNT(*) AS total_employees,
        SUM(CASE WHEN employee_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) AS terminated_employees,

        CAST(
            SUM(CASE WHEN employee_status = 'Terminated' THEN 1 ELSE 0 END) * 100.0
            / COUNT(*)
            AS DECIMAL(10,2)
        ) AS attrition_rate_percentage,

        CAST(
            AVG(CAST(tenure_years AS FLOAT))
            AS DECIMAL(10,2)
        ) AS average_tenure_years
    FROM hr_data_clean
    GROUP BY department
)

SELECT
    department,
    total_employees,
    active_employees,
    terminated_employees,
    attrition_rate_percentage,
    average_tenure_years,

    CASE
        WHEN attrition_rate_percentage >= 20 AND average_tenure_years < 5
            THEN 'Priority Action: Investigate early exits and improve retention programs'

        WHEN attrition_rate_percentage >= 20 AND average_tenure_years >= 5
            THEN 'Action Needed: Review workload, engagement, and career growth opportunities'

        WHEN attrition_rate_percentage BETWEEN 10 AND 19.99
            THEN 'Monitor: Strengthen employee engagement and manager support'

        ELSE 'Maintain: Continue current retention practices'
    END AS hr_recommendation
FROM department_summary
ORDER BY attrition_rate_percentage DESC;

GO


/* ------------------------------------------------------------
   10.9 FINAL PROJECT SUMMARY
   ------------------------------------------------------------

   This project analyzed HR data using SQL to understand workforce
   structure, employee demographics, department distribution, tenure,
   retention, and attrition.

   Through the analysis, I demonstrated how SQL can support HR decision-
   making by transforming raw employee records into meaningful business
   insights.

   Key project achievements include:

   - Cleaning and preparing raw HR data for analysis
   - Creating employee status, age, and tenure fields
   - Analyzing workforce size and employee status
   - Exploring demographic distribution
   - Evaluating department and job role patterns
   - Measuring tenure and retention trends
   - Performing detailed attrition analysis
   - Using CTEs and window functions for advanced insights
   - Translating data findings into HR recommendations

   This final step connects the technical SQL analysis to practical HR
   decision-making.
   ------------------------------------------------------------ */