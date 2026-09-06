/*
    ЭТАП 3. ОЧИСТКА И ПОДГОТОВКА ДАННЫХ

    Скрипт выполняется один раз после успешных проверок этапа 2.
    Он воспроизводит логику исходного аналитического ноутбука:
    1) преобразует текстовые значения в рабочие типы PostgreSQL;
    2) заменяет отсутствующий CustomerNo техническим значением -1;
    3) удаляет полностью одинаковые строки;
    4) объединяет одинаковые товарные позиции и суммирует количество;
    5) рассчитывает сумму строки price * quantity.

    Замена неизвестного клиента на -1 — правило именно этого проекта,
    а не универсальная практика для любых данных электронной коммерции.
*/

CREATE TABLE clean.transactions AS
-- typed: переводим текстовые поля raw-слоя в дату и числовые типы.
WITH typed AS (
    SELECT
        transaction_no,
        TO_DATE(transaction_date, 'MM/DD/YYYY') AS transaction_date,
        product_no,
        product_name,
        price::numeric AS price,
        quantity::numeric::bigint AS quantity,
        COALESCE(
            NULLIF(NULLIF(UPPER(BTRIM(customer_no)), 'NA'), '')::numeric::bigint,
            -1
        ) AS customer_no,
        country
    FROM raw.transactions
),
-- deduplicated: удаляем только полностью одинаковые исходные записи.
deduplicated AS (
    SELECT DISTINCT * FROM typed
),
/*
    grouped: сворачиваем одинаковые товарные строки.
    Все идентифицирующие признаки входят в GROUP BY, поэтому объединяются
    только записи одной транзакции, даты, товара, цены, покупателя и страны.
*/
grouped AS (
    SELECT
        transaction_no,
        transaction_date,
        product_no,
        product_name,
        price,
        SUM(quantity)::bigint AS quantity,
        customer_no,
        country
    FROM deduplicated
    GROUP BY transaction_no, transaction_date, product_no, product_name,
             price, customer_no, country
)
-- total_amount положителен для продаж и отрицателен для возвратов.
SELECT *, price * quantity AS total_amount
FROM grouped;

-- Представление продаж содержит только строки с положительным количеством.
CREATE OR REPLACE VIEW analytics.sales AS
SELECT * FROM clean.transactions WHERE quantity > 0;

-- Представление возвратов содержит отрицательные количества.
-- return_amount выводится положительным числом для удобства анализа ущерба.
CREATE OR REPLACE VIEW analytics.returns AS
SELECT *, -total_amount AS return_amount
FROM clean.transactions
WHERE quantity < 0;

/*
    Представление заказов агрегирует продажи до уровня transaction_no:
    одна строка соответствует одному заказу. Покупатель и страна сюда
    намеренно не добавляются без отдельной проверки их однозначности.
*/
CREATE OR REPLACE VIEW analytics.orders AS
SELECT transaction_no,
       SUM(total_amount) AS order_amount,
       SUM(quantity) AS total_quantity,
       COUNT(*) AS product_lines
FROM analytics.sales
GROUP BY transaction_no;

-- Обновляем статистику планировщика PostgreSQL для новой таблицы.
ANALYZE clean.transactions;
