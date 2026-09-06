/*
    ЭТАП 4. КОНТРОЛЬ РЕЗУЛЬТАТОВ ОЧИСТКИ

    Скрипт проверяет, что преобразования этапа 3 дали ожидаемый результат.
    Эталонные значения относятся к CSV, зафиксированному в README.md.
    Они были независимо рассчитаны в выполненном pandas/SQLite-ноутбуке.
*/

-- 1. Сверяем количество строк до и после очистки, продажи и возвраты.
-- Ожидается: raw=536350, clean=526417, sales=517898, returns=8519, zero=0.
SELECT
    (SELECT COUNT(*) FROM raw.transactions) AS raw_rows,
    COUNT(*) AS clean_rows,
    COUNT(*) FILTER (WHERE quantity > 0) AS sales_rows,
    COUNT(*) FILTER (WHERE quantity < 0) AS return_rows,
    COUNT(*) FILTER (WHERE quantity = 0) AS zero_quantity_rows
FROM clean.transactions;

/*
    2. Сверяем денежные показатели:
    - gross_revenue — сумма положительных продаж без возвратов;
    - return_amount — абсолютная сумма возвратов;
    - net_amount — продажи с учётом возвратов.

    Ожидается: 62781386.54; 2664628.15; 60116758.39.
    net_amount не является прибылью: в данных отсутствует себестоимость.
*/
SELECT
    ROUND(SUM(total_amount) FILTER (WHERE quantity > 0), 2) AS gross_revenue,
    ROUND(-SUM(total_amount) FILTER (WHERE quantity < 0), 2) AS return_amount,
    ROUND(SUM(total_amount), 2) AS net_amount
FROM clean.transactions;

/*
    3. Проверяем однозначность атрибутов заказа.
    Для одного transaction_no не должно быть нескольких покупателей,
    стран или дат. Ожидаемый результат — 0 строк.
*/
SELECT transaction_no,
       COUNT(DISTINCT customer_no) AS customer_count,
       COUNT(DISTINCT country) AS country_count,
       COUNT(DISTINCT transaction_date) AS date_count
FROM clean.transactions
GROUP BY transaction_no
HAVING COUNT(DISTINCT customer_no) > 1
    OR COUNT(DISTINCT country) > 1
    OR COUNT(DISTINCT transaction_date) > 1;

/*
    4. Ищем NULL в обязательных полях и отрицательную цену.
    Неизвестный customer_no уже представлен значением -1, а не NULL.
    Ожидаемый результат — 0 строк.
*/
SELECT * FROM clean.transactions
WHERE transaction_no IS NULL OR transaction_date IS NULL
   OR product_no IS NULL OR product_name IS NULL
   OR price IS NULL OR quantity IS NULL
   OR customer_no IS NULL OR country IS NULL
   OR price < 0
LIMIT 10;
