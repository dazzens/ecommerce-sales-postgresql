/*
    ЭТАП 2. ПРОВЕРКА ИМПОРТА CSV

    Скрипт выполняется после загрузки файла через DBeaver.
    Контрольные значения относятся к Kaggle-датасету версии 7,
    указанному в README.md.
*/

-- 1. Проверяем полноту загрузки. Ожидается 536350 строк.
-- Если число отличается, дальнейшую обработку выполнять нельзя.
SELECT COUNT(*) AS raw_rows
FROM raw.transactions;

-- 2. Просматриваем десять строк в стабильном порядке.
-- Это позволяет визуально проверить распределение значений по столбцам.
SELECT *
FROM raw.transactions
ORDER BY transaction_no, product_no, price, quantity, customer_no,
         transaction_date, product_name, country
LIMIT 10;

/*
    3. Считаем пропуски по каждому полю.

    В исходном CSV отсутствующий CustomerNo записан как NA. Пустая строка
    также считается пропуском. Для customer_no ожидается 55 пропусков,
    для остальных полей — 0.
*/
SELECT
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(transaction_no), '') IS NULL) AS missing_transaction_no,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(transaction_date), '') IS NULL) AS missing_date,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(product_no), '') IS NULL) AS missing_product_no,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(product_name), '') IS NULL) AS missing_product_name,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(price), '') IS NULL) AS missing_price,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(quantity), '') IS NULL) AS missing_quantity,
    COUNT(*) FILTER (
        WHERE NULLIF(NULLIF(UPPER(BTRIM(customer_no)), 'NA'), '') IS NULL
    ) AS missing_customer_no,
    COUNT(*) FILTER (WHERE NULLIF(BTRIM(country), '') IS NULL) AS missing_country
FROM raw.transactions;

-- 4. Проверяем временной диапазон.
-- В CSV используется формат MM/DD/YYYY. Ожидается 2018-12-01 — 2019-12-09.
SELECT
       MIN(TO_DATE(transaction_date, 'MM/DD/YYYY')) AS first_date,
       MAX(TO_DATE(transaction_date, 'MM/DD/YYYY')) AS last_date
FROM raw.transactions;

/*
    5. Ищем дробные значения количества или идентификатора покупателя.
    В этом датасете оба поля должны быть целыми. Маркер NA предварительно
    превращается в NULL, чтобы PostgreSQL не пытался преобразовать его в число.
    Ожидаемый результат — 0 строк.
*/
SELECT *
FROM raw.transactions
WHERE quantity::numeric <> TRUNC(quantity::numeric)
   OR NULLIF(NULLIF(UPPER(BTRIM(customer_no)), 'NA'), '')::numeric
      <> TRUNC(NULLIF(NULLIF(UPPER(BTRIM(customer_no)), 'NA'), '')::numeric)
LIMIT 10;
