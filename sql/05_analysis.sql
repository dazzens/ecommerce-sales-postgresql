/*
    ЭТАП 5. АНАЛИТИЧЕСКИЕ SQL-ЗАПРОСЫ

    Запросы рекомендуется выполнять по одному сочетанием Ctrl+Enter.
    По описанию источника Kaggle поле Price указано в фунтах стерлингов (£).
    Поэтому денежные показатели ниже интерпретируются в этой валюте.
*/

-- 1. Просмотр подготовленных продаж.
-- Выводим первые 20 положительных товарных операций для ручной проверки.
SELECT transaction_no, transaction_date, product_name,
       quantity, price, total_amount
FROM analytics.sales
ORDER BY transaction_date, transaction_no, product_no, price,
         customer_no, country, product_name
LIMIT 20;

-- 2. Валовые продажи по странам без учёта возвратов.
-- Считаем число заказов, проданные единицы и выручку каждой страны.
SELECT country,
       COUNT(DISTINCT transaction_no) AS orders_count,
       SUM(quantity) AS units_sold,
       ROUND(SUM(total_amount), 2) AS gross_revenue
FROM analytics.sales
GROUP BY country
ORDER BY gross_revenue DESC, country;

-- 3. Десять товаров с наибольшей валовой выручкой.
-- Товар определяется сочетанием product_no и product_name.
SELECT product_no, product_name,
       SUM(quantity) AS units_sold,
       ROUND(SUM(total_amount), 2) AS gross_revenue
FROM analytics.sales
GROUP BY product_no, product_name
ORDER BY gross_revenue DESC, product_no, product_name
LIMIT 10;

/*
    4. Динамика валовой выручки по месяцам.
    Последний наблюдаемый месяц исключается, как в исходном ноутбуке,
    поскольку он представлен неполным периодом. Это решение не доказывает
    полноту остальных месяцев и должно быть явно указано в выводах проекта.
*/
SELECT DATE_TRUNC('month', transaction_date)::date AS month,
       COUNT(DISTINCT transaction_no) AS orders_count,
       ROUND(SUM(total_amount), 2) AS gross_revenue
FROM analytics.sales
WHERE transaction_date < (
    SELECT DATE_TRUNC('month', MAX(transaction_date)) FROM analytics.sales
)
GROUP BY DATE_TRUNC('month', transaction_date)::date
ORDER BY month;

-- 5. Средний чек на уровне заказа.
-- Используется analytics.orders, поэтому считается средняя сумма заказа,
-- а не средняя стоимость отдельной товарной строки.
SELECT COUNT(*) AS orders_count,
       ROUND(AVG(order_amount), 2) AS average_order_value,
       ROUND(SUM(order_amount), 2) AS gross_revenue
FROM analytics.orders;

/*
    6. Повторные покупатели за весь наблюдаемый период.
    В результат входят клиенты с более чем одним заказом. Технический
    customer_no=-1 исключается. Это не когортный показатель удержания.
*/
SELECT customer_no,
       COUNT(DISTINCT transaction_no) AS orders_count,
       ROUND(SUM(total_amount), 2) AS gross_revenue
FROM analytics.sales
WHERE customer_no <> -1
GROUP BY customer_no
HAVING COUNT(DISTINCT transaction_no) > 1
ORDER BY orders_count DESC, customer_no
LIMIT 20;

-- 7. Товары с наибольшей суммой возвратов.
-- В analytics.returns количество отрицательное, а return_amount специально
-- хранится положительным, поэтому итог удобно сравнивать по убыванию.
SELECT product_no, product_name,
       SUM(ABS(quantity)) AS returned_units,
       ROUND(SUM(return_amount), 2) AS return_amount
FROM analytics.returns
GROUP BY product_no, product_name
ORDER BY return_amount DESC, product_no, product_name
LIMIT 10;

-- 8. Детализация крупнейших продаж для выбранной страны.
-- Значение Germany можно заменить другой страной для самостоятельного анализа.
SELECT transaction_no, product_name, quantity, total_amount
FROM analytics.sales
WHERE country = 'Germany'
ORDER BY total_amount DESC, transaction_no, product_no,
         transaction_date, price, customer_no, product_name
LIMIT 20;
