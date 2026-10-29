-- =====================================================================
-- 02. Разведка данных и выбор горизонта наблюдения
-- База: olist (PostgreSQL)
-- =====================================================================
-- Гипотезы:
--   1. Клиенты, у которых заказ доставили с опозданием, реже возвращаются,
--      потому что получили плохой опыт.
--   2. Клиенты, оставившие оценку 1-2, реже возвращаются.
--   3. Возврат зависит от категории первого заказа: за некоторыми товарами
--      (расходники, одежда) возвращаются чаще, чем за дорогой техникой.
--
-- Допущения:
--   * анализируем только доставленные заказы (order_status = 'delivered'), ~97% всех
--   * старт анализа с января 2017: до этого данные неполные
--     (в каком-то месяце нет заказов вообще, в каком-то один заказ)
--
-- Как устроен файл: каждый запрос самостоятельный, его можно запускать отдельно.
-- В запросах про повторные заказы используются две заготовки (CTE):
--   base  - доставленные заказы: человек (customer_unique_id), заказ, день заказа
--           и номер заказа по порядку у этого человека (number_order)
--   pairs - по человеку: день первого и день второго заказа (только тех, у кого есть второй)


-- ---------------------------------------------------------------------
-- 1. Общий обзор заказов
-- ---------------------------------------------------------------------

-- первые 10 строк таблицы заказов
select * from orders o
limit 10;

-- сколько заказов в каждом статусе
select o.order_status, count(*) as count from orders o
group by o.order_status
order by count desc;

-- число доставленных заказов по месяцам покупки
select date_trunc('month', o.order_purchase_timestamp)::date as order_month, count(o.order_id) from orders o
where o.order_status = 'delivered'
group by date_trunc('month', o.order_purchase_timestamp)
order by order_month;


-- ---------------------------------------------------------------------
-- 2. Через сколько дней клиенты делают второй заказ
--    (по этим цифрам выбирался горизонт наблюдения: 6 месяцев)
-- ---------------------------------------------------------------------

-- 2.1. Для каждого вернувшегося человека: день первого заказа, день второго и разница в днях
with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered'), pairs as
(select customer_unique_id,
min(case when number_order = 1 then order_day end) as first_order_day,
min(case when number_order = 2 then order_day end) as second_order_day
from base
group by customer_unique_id
having min(case when number_order = 2 then order_day end) is not null)
select pairs.customer_unique_id,
	   pairs.first_order_day,
	   pairs.second_order_day,
	   pairs.second_order_day - pairs.first_order_day as dif_order_days
	   from pairs;

-- 2.2. Медиана, 75-й и 90-й процентили разницы в днях
--      только для людей, у которых первый заказ в 2017 году
--      (у поздних когорт данные обрываются, их брать нельзя: цифры исказятся)
--      Результат: 1752 человека, медиана 53, p75 183, p90 297 дней
with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered'), pairs as
(select customer_unique_id,
min(case when number_order = 1 then order_day end) as first_order_day,
min(case when number_order = 2 then order_day end) as second_order_day
from base
group by customer_unique_id
having min(case when number_order = 2 then order_day end) is not null)
select count(*) as first_order_2017,
PERCENTILE_DISC(0.5) within group (order by pairs.second_order_day - pairs.first_order_day) as median,
PERCENTILE_DISC(0.75) within group (order by pairs.second_order_day - pairs.first_order_day) as percentil_75,
PERCENTILE_DISC(0.9) within group (order by pairs.second_order_day - pairs.first_order_day) as percentil_90
from pairs
where extract('year' from pairs.first_order_day) = 2017;

-- 2.3. У скольких людей второй заказ сделан в тот же день, что и первый
--      Результат: 829 (около 30% всех вернувшихся), поэтому такой заказ возвратом не считаем
with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered'), pairs as
(select customer_unique_id,
min(case when number_order = 1 then order_day end) as first_order_day,
min(case when number_order = 2 then order_day end) as second_order_day
from base
group by customer_unique_id
having min(case when number_order = 2 then order_day end) is not null)
select count(*) from pairs
where pairs.first_order_day = pairs.second_order_day;

-- 2.4. Сколько всего людей сделали хотя бы второй заказ
--      Результат: 2801
with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered'), pairs as
(select customer_unique_id,
min(case when number_order = 1 then order_day end) as first_order_day,
min(case when number_order = 2 then order_day end) as second_order_day
from base
group by customer_unique_id
having min(case when number_order = 2 then order_day end) is not null)
select count(*) from pairs;


-- ---------------------------------------------------------------------
-- 3. Какая доля клиентов вообще сделала второй заказ
-- ---------------------------------------------------------------------

-- всего людей с доставленными заказами и доля сделавших второй заказ (в процентах)
-- числа 2801 (результат 2.4) и 93358 (число людей в этом же запросе) вписаны вручную
-- Результат: 93358 человек, около 3% сделали второй заказ
with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered')
select count(distinct base.customer_unique_id), 2801.0 / 93358.0 * 100 as retention from base;
