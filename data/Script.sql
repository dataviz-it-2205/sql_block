--Using data from the tables customer_info.xlsx (customer information) and transactions_info.xlsx 
--(information about transactions for the period from 06/01/2015 to 06/01/2016), you need to withdraw:

select * from customer_info ci;
select * from transactions_info ti;

--1. a list of clients with a continuous history for the year, that is, every month on a regular basis without omissions for the specified annual period, 
--the average receipt for the period from 06/01/2015 to 06/01/2016, the average amount of purchases per month, 
--the number of all transactions per client for the period;


WITH monthly_transactions AS (
    SELECT
        id_client,
        EXTRACT(MONTH FROM TO_DATE(CAST(date_new AS TEXT), 'YYYY-DD-MM')) AS month,
        SUM(sum_payment) AS total_spent_month,
        COUNT(id_check) AS transaction_count_month
    FROM transactions_info
    WHERE TO_DATE(CAST(date_new AS TEXT), 'YYYY-DD-MM') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY id_client, month
),
full_history_clients AS (
    SELECT
        id_client
    FROM monthly_transactions
    GROUP BY id_client
    HAVING COUNT(DISTINCT month) = 12
)
SELECT
    ci.id_client,
    ci.total_amount,
    ci.gender,
    ci.age,
    ci.count_city,
    ci.response_communication,
    ci.communication_3month,
    ci.tenure,
    SUM(mt.total_spent_month) / COUNT(mt.transaction_count_month) AS average_receipt,
    SUM(mt.total_spent_month) / 12 AS average_monthly_spending,
    COUNT(mt.transaction_count_month) AS total_transactions
FROM customer_info ci
JOIN full_history_clients fhc ON ci.id_client = fhc.id_client
JOIN monthly_transactions mt ON ci.id_client = mt.id_client
GROUP BY ci.id_client;

--2. information by month:
--the average amount of the check per month;
--average number of operations per month;
--the average number of clients who performed transactions;
--the share of the total number of transactions for the year and the share per month of the total amount of transactions;
--print the % ratio of M/F/NA in each month with their share of costs;

WITH monthly_transactions AS (
    SELECT
        ti.id_client,
        EXTRACT(MONTH FROM TO_DATE(CAST(ti.date_new AS TEXT), 'YYYY-DD-MM')) AS month,
        SUM(ti.sum_payment) AS total_spent_month,
        COUNT(ti.id_check) AS transaction_count_month,
        COUNT(DISTINCT ti.id_client) AS clients_in_month,
        ci.gender
    FROM transactions_info ti
    JOIN customer_info ci ON ti.id_client = ci.id_client
    WHERE TO_DATE(CAST(ti.date_new AS TEXT), 'YYYY-DD-MM') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ti.id_client, month, ci.gender
),
monthly_summary AS (
    SELECT
        month,
        AVG(total_spent_month) AS avg_check,
        AVG(transaction_count_month) AS avg_operations,
        AVG(clients_in_month) AS avg_clients,
        SUM(transaction_count_month) AS total_transactions,
        SUM(total_spent_month) AS total_spent
    FROM monthly_transactions
    GROUP BY month
),
gender_summary AS (
    SELECT
        month,
        gender,
        SUM(total_spent_month) AS gender_spent,
        COUNT(id_client) AS gender_count
    FROM monthly_transactions
    GROUP BY month, gender
)
SELECT
    ms.month,
    ms.avg_check,
    ms.avg_operations,
    ms.avg_clients,
    ms.total_transactions,
    ms.total_spent,
    gs.gender,
    gs.gender_spent,
    gs.gender_count,
    (gs.gender_spent / ms.total_spent) * 100 AS gender_spent_percentage,
    (gs.gender_count / ms.avg_clients) * 100 AS gender_count_percentage
FROM monthly_summary ms
JOIN gender_summary gs ON ms.month = gs.month
ORDER BY ms.month, gs.gender;


--3. age groups of clients in increments of 10 years and separately clients who do not have this information,
-- with the parameters amount and number of transactions for the entire period, and quarterly - averages and %.


WITH age_groups AS (
    SELECT
        ci.id_client,
        CASE
            WHEN ci.age IS NULL THEN 'Unknown'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+' 
        END AS age_group,
        SUM(ti.sum_payment) AS total_spent,
        COUNT(ti.id_check) AS transaction_count
    FROM customer_info ci
    LEFT JOIN transactions_info ti ON ci.id_client = ti.id_client
    WHERE ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ci.id_client, age_group
),
quarterly_data AS (
    SELECT
        ci.id_client,
        EXTRACT(QUARTER FROM TO_DATE(CAST(ti.date_new AS TEXT), 'YYYY-DD-MM')) AS quarter,
        CASE
            WHEN ci.age IS NULL THEN 'Unknown'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+' 
        END AS age_group,
        SUM(ti.sum_payment) AS total_spent_qtr,
        COUNT(ti.id_check) AS transaction_count_qtr
    FROM customer_info ci
    LEFT JOIN transactions_info ti ON ci.id_client = ti.id_client
    WHERE ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ci.id_client, quarter, age_group
)
SELECT
    ag.age_group,
    SUM(ag.total_spent) AS total_spent_all,
    SUM(ag.transaction_count) AS total_transactions_all,
    AVG(ag.total_spent) AS avg_spent_all,
    AVG(ag.transaction_count) AS avg_transactions_all,
    -- Quarter-wise averages
    SUM(CASE WHEN qtr.quarter = 1 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr1_spent,
    SUM(CASE WHEN qtr.quarter = 2 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr2_spent,
    SUM(CASE WHEN qtr.quarter = 3 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr3_spent,
    SUM(CASE WHEN qtr.quarter = 4 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr4_spent,
    SUM(CASE WHEN qtr.quarter = 1 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr1_count,
    SUM(CASE WHEN qtr.quarter = 2 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr2_count,
    SUM(CASE WHEN qtr.quarter = 3 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr3_count,
    SUM(CASE WHEN qtr.quarter = 4 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr4_count,
    -- Percentages
    (SUM(ag.total_spent) / SUM(SUM(ag.total_spent)) OVER ()) * 100 AS spent_percentage,
    (SUM(ag.transaction_count) / SUM(SUM(ag.transaction_count)) OVER ()) * 100 AS transactions_percentage
FROM age_groups ag
LEFT JOIN quarterly_data qtr ON ag.id_client = qtr.id_client AND ag.age_group = qtr.age_group
GROUP BY ag.age_group
ORDER BY ag.age_group;


WITH age_groups AS (
    SELECT
        ci.id_client,
        CASE
            WHEN ci.age IS NULL THEN 'Unknown'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+' 
        END AS age_group,
        SUM(ti.sum_payment) AS total_spent,
        COUNT(ti.id_check) AS transaction_count
    FROM customer_info ci
    LEFT JOIN transactions_info ti ON ci.id_client = ti.id_client
    WHERE ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ci.id_client, age_group
),
quarterly_data AS (
    SELECT
        ci.id_client,
        EXTRACT(QUARTER FROM TO_DATE(CAST(ti.date_new AS TEXT), 'YYYY-DD-MM')) AS quarter,
        CASE
            WHEN ci.age IS NULL THEN 'Unknown'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+' 
        END AS age_group,
        SUM(ti.sum_payment) AS total_spent_qtr,
        COUNT(ti.id_check) AS transaction_count_qtr
    FROM customer_info ci
    LEFT JOIN transactions_info ti ON ci.id_client = ti.id_client
    WHERE ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ci.id_client, quarter, age_group
)
SELECT
    ag.age_group,
    SUM(ag.total_spent) AS total_spent_all,
    SUM(ag.transaction_count) AS total_transactions_all,
    AVG(ag.total_spent) AS avg_spent_all,
    AVG(ag.transaction_count) AS avg_transactions_all,
    SUM(CASE WHEN qtr.quarter = 1 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr1_spent,
    SUM(CASE WHEN qtr.quarter = 2 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr2_spent,
    SUM(CASE WHEN qtr.quarter = 3 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr3_spent,
    SUM(CASE WHEN qtr.quarter = 4 THEN qtr.total_spent_qtr ELSE 0 END) AS qtr4_spent,
    SUM(CASE WHEN qtr.quarter = 1 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr1_count,
    SUM(CASE WHEN qtr.quarter = 2 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr2_count,
    SUM(CASE WHEN qtr.quarter = 3 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr3_count,
    SUM(CASE WHEN qtr.quarter = 4 THEN qtr.transaction_count_qtr ELSE 0 END) AS qtr4_count,
    (SUM(ag.total_spent) / SUM(SUM(ag.total_spent)) OVER ()) * 100 AS spent_percentage,
    (SUM(ag.transaction_count) / SUM(SUM(ag.transaction_count)) OVER ()) * 100 AS transactions_percentage
FROM age_groups ag
LEFT JOIN quarterly_data qtr ON ag.id_client = qtr.id_client AND ag.age_group = qtr.age_group
GROUP BY ag.age_group
ORDER BY ag.age_group;
