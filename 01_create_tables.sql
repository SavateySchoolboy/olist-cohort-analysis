-- =====================================================================
-- 01. Создание таблиц, первичных и внешних ключей
-- База: olist (PostgreSQL)
-- =====================================================================
-- Порядок: сначала родительские таблицы, потом дочерние.
-- После каждого create table данные загружаются из CSV через DBeaver
-- (Import Data, режим existing, пустые строки превращать в NULL).
-- Проверочные запросы оставлены между командами: ими проверялась
-- уникальность ключей и отсутствие "потерянных" ссылок.


-- ---------------------------------------------------------------------
-- 1. customers (клиенты)
-- ---------------------------------------------------------------------

-- создание таблицы customers
create table customers (
    customer_id               text,
    customer_unique_id        text,
    customer_zip_code_prefix  text,
    customer_city             text,
    customer_state            text
);

-- сравнение айди для выявления праймари ключа
-- (customer_id уникален в каждой строке, customer_unique_id повторяется: это один и тот же человек)
select count(distinct customer_id), count(distinct customer_unique_id) from customers;

-- добавление праймари ключа
ALTER TABLE customers ADD PRIMARY KEY (customer_id);


-- ---------------------------------------------------------------------
-- 2. orders (заказы)
-- ---------------------------------------------------------------------

-- создание таблицы orders
create table orders (
order_id text,
customer_id text,
order_status text,
order_purchase_timestamp timestamp,
order_approved_at timestamp,
order_delivered_carrier_date timestamp,
order_delivered_customer_date timestamp,
order_estimated_delivery_date timestamp
);

-- проверяем на уникальность столбец с айди для добавления его как праймари ключ
-- (число строк должно совпасть с числом разных order_id)
select count(*) from orders;
select count(distinct order_id) from orders;

-- добавляем праймари ключ для таблицы orders
ALTER TABLE orders ADD PRIMARY KEY (order_id);

-- проверка перед внешним ключом: есть ли заказы без клиента (должно быть 0)
select count(*) from customers c
right join orders o on c.customer_id = o.customer_id
where c.customer_id is null;

-- добавление внешнего ключа: orders.customer_id -> customers.customer_id
alter table orders
add foreign key (customer_id) references customers (customer_id);


-- ---------------------------------------------------------------------
-- 3. products (товары)
-- ---------------------------------------------------------------------

-- создание таблицы продукты
create table products (
product_id text,
product_category_name text,
product_name_lenght integer,
product_description_lenght integer,
product_photos_qty integer,
product_weight_g integer,
product_length_cm integer,
product_height_cm integer,
product_width_cm integer
);

-- проверка уникальности product_id (число разных айди должно совпасть с числом строк)
select count(distinct product_id), count(*) from products;

-- добавление праймари ключа
alter table products add primary key (product_id);

-- проверка: у какой части товаров категория не заполнена (NULL)
select p.product_category_name from products p
where p.product_category_name is null;


-- ---------------------------------------------------------------------
-- 4. sellers (продавцы)
-- ---------------------------------------------------------------------

-- создание таблицы sellers
create table sellers (
seller_id text,
seller_zip_code_prefix text,
seller_city text,
seller_state text);

-- проверка числа строк после загрузки
select count(*) from sellers s;

-- добавление праймари ключа
alter table sellers add primary key (seller_id);


-- ---------------------------------------------------------------------
-- 5. product_category_name_translation (перевод категорий)
-- ---------------------------------------------------------------------

-- создание таблицы переводов категорий
create table product_category_name_translation (
product_category_name text,
product_category_name_english text);

-- проверка уникальности названия категории
select count(*), count(distinct pcnt.product_category_name) from product_category_name_translation pcnt;

-- добавление праймари ключа
alter table product_category_name_translation add primary key (product_category_name);


-- ---------------------------------------------------------------------
-- 6. order_items (позиции заказов)
-- ---------------------------------------------------------------------

-- создание таблицы order_items
create table order_items (
order_id TEXT,
order_item_id INTEGER,
product_id TEXT,
seller_id TEXT,
shipping_limit_date timestamp,
price numeric(8, 2),
freight_value numeric(8, 2));

-- проверка: сколько разных пар (order_id, order_item_id)? Должно совпасть с числом строк,
-- тогда пара подходит как составной праймари ключ
select count(*) from (select distinct oi.order_id , order_item_id from order_items oi);

-- добавление составного праймари ключа
ALTER TABLE order_items ADD PRIMARY KEY (order_id, order_item_id);

-- просмотр первых 10 строк
select * from order_items oi
limit 10;

-- проверки перед внешними ключами: есть ли "потерянные" ссылки (везде должно быть 0 / пусто)
-- позиции без заказа
select oi.order_id from order_items oi
left join orders o on oi.order_id = o.order_id
where o.order_id is null;

-- позиции без товара
select count(*) from order_items oi
left join products p  on oi.product_id = p.product_id
where p.product_id is null;

-- позиции без продавца
select count(*) from order_items oi
left join sellers s  on oi.seller_id = s.seller_id
where s.seller_id is null;

-- внешние ключи: order_items -> orders, products, sellers
alter table order_items
add foreign key (order_id) references orders (order_id);

alter table order_items
add foreign key (product_id) references products (product_id);

alter table order_items
add foreign key (seller_id) references sellers (seller_id);


-- ---------------------------------------------------------------------
-- 7. Проверка связи products -> product_category_name_translation
-- ---------------------------------------------------------------------

-- сколько товаров имеют категорию, которой нет в таблице переводов
-- (результат больше 0, поэтому внешний ключ на таблицу переводов НЕ создавался:
--  связь делается обычным left join в запросах)
select count(*) from product_category_name_translation pcnt
right join products p  on pcnt.product_category_name = p.product_category_name
where pcnt.product_category_name is null and p.product_category_name is not null;
