/*
    ЭТАП 6. ИТОГОВЫЙ АУДИТ ПРОЕКТА

    Скрипт выполняется после этапов 1–5 и выводит все ключевые проверки
    одной таблицей. Для исходного CSV Kaggle версии 7 каждая строка должна
    иметь статус PASS.

    CTE metrics один раз рассчитывает фактические показатели базы.
    CTE audit превращает их в строки формата:
    название проверки | фактическое значение | эталон | результат.
*/

WITH metrics AS (
    SELECT
        (SELECT COUNT(*) FROM raw.transactions) AS raw_rows,
        (SELECT COUNT(*) FROM clean.transactions) AS clean_rows,
        (SELECT COUNT(*) FROM analytics.sales) AS sales_rows,
        (SELECT COUNT(*) FROM analytics.returns) AS return_rows,
        (SELECT COUNT(*) FROM clean.transactions WHERE quantity = 0) AS zero_rows,
        (SELECT ROUND(SUM(total_amount), 2)
         FROM analytics.sales) AS gross_revenue,
        (SELECT ROUND(SUM(return_amount), 2)
         FROM analytics.returns) AS return_amount,
        (SELECT ROUND(SUM(total_amount), 2)
         FROM clean.transactions) AS net_amount,
        (SELECT COUNT(*)
         FROM (
             SELECT transaction_no
             FROM clean.transactions
             GROUP BY transaction_no
             HAVING COUNT(DISTINCT customer_no) > 1
                 OR COUNT(DISTINCT country) > 1
                 OR COUNT(DISTINCT transaction_date) > 1
         ) AS inconsistent_transactions) AS inconsistent_transactions,
        (SELECT COUNT(*)
         FROM clean.transactions
         WHERE transaction_no IS NULL OR transaction_date IS NULL
            OR product_no IS NULL OR product_name IS NULL
            OR price IS NULL OR quantity IS NULL
            OR customer_no IS NULL OR country IS NULL
            OR price < 0) AS invalid_clean_rows,
        (SELECT COUNT(*) FROM analytics.orders) AS orders_view_rows,
        (SELECT COUNT(DISTINCT transaction_no) FROM analytics.sales) AS distinct_sales_orders
),
-- Для каждой метрики сравниваем фактическое значение с ожидаемым.
audit AS (
    SELECT 1 AS check_order, 'raw row count' AS check_name,
           raw_rows::text AS actual, '536350' AS expected,
           raw_rows = 536350 AS passed FROM metrics
    UNION ALL
    SELECT 2, 'clean row count', clean_rows::text, '526417',
           clean_rows = 526417 FROM metrics
    UNION ALL
    SELECT 3, 'sales view row count', sales_rows::text, '517898',
           sales_rows = 517898 FROM metrics
    UNION ALL
    SELECT 4, 'returns view row count', return_rows::text, '8519',
           return_rows = 8519 FROM metrics
    UNION ALL
    SELECT 5, 'zero quantity rows', zero_rows::text, '0',
           zero_rows = 0 FROM metrics
    UNION ALL
    SELECT 6, 'gross revenue', gross_revenue::text, '62781386.54',
           gross_revenue = 62781386.54 FROM metrics
    UNION ALL
    SELECT 7, 'return amount', return_amount::text, '2664628.15',
           return_amount = 2664628.15 FROM metrics
    UNION ALL
    SELECT 8, 'net amount', net_amount::text, '60116758.39',
           net_amount = 60116758.39 FROM metrics
    UNION ALL
    SELECT 9, 'inconsistent transactions', inconsistent_transactions::text, '0',
           inconsistent_transactions = 0 FROM metrics
    UNION ALL
    SELECT 10, 'invalid clean rows', invalid_clean_rows::text, '0',
           invalid_clean_rows = 0 FROM metrics
    UNION ALL
    SELECT 11, 'orders view matches distinct sales orders',
           orders_view_rows::text, distinct_sales_orders::text,
           orders_view_rows = distinct_sales_orders FROM metrics
)
SELECT
    check_name,
    actual,
    expected,
    -- PASS означает совпадение, FAIL указывает на расхождение.
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status
FROM audit
ORDER BY check_order;
