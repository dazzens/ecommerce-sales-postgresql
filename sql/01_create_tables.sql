
/*
    ЭТАП 1. СОЗДАНИЕ СТРУКТУРЫ БАЗЫ ДАННЫХ

    Подключение: база ecommerce, пользователь ecommerce_user.
    Скрипт выполняется один раз в новой проектной базе до импорта CSV.

    Архитектура проекта разделена на три слоя:
    - raw       — исходные данные без преобразований;
    - clean     — очищенные и типизированные данные;
    - analytics — представления для аналитических запросов.
*/

-- Создаём схемы. IF NOT EXISTS предотвращает ошибку, если схема уже существует.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS clean;
CREATE SCHEMA IF NOT EXISTS analytics;

/*
    Создаём таблицу для прямой загрузки CSV.

    Все поля намеренно имеют тип text. Такой staging-подход позволяет сначала
    сохранить исходные значения, а проверку и преобразование типов выполнить
    отдельным контролируемым этапом в 03_prepare_data.sql.

    transaction_no не является первичным ключом: одна транзакция может включать
    несколько товарных позиций.
*/
CREATE TABLE raw.transactions (
    transaction_no   text,
    transaction_date text,
    product_no       text,
    product_name     text,
    price            text,
    quantity         text,
    customer_no      text,
    country          text
);

-- Контроль: запрос показывает базу и пользователя текущего подключения.
SELECT
    current_database() AS database_name,
    current_user AS user_name;
