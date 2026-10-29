-- =====================================================================
-- 03. Когортный анализ: возврат клиентов в течение 180 дней
-- База: olist (PostgreSQL)
-- =====================================================================
-- Когорта: люди, сделавшие первый заказ в одном месяце.
-- Возврат: у человека есть заказ в ДРУГОЙ день, не позже чем через 180 дней
--          после дня первого заказа (заказ в тот же день возвратом не считается).
-- Период: когорты с января 2017 по январь 2018. У более поздних когорт
--         180 дней ещё не прошли до конца данных (август 2018).
--
-- Заготовки (CTE):
--   base   - доставленные заказы: человек (customer_unique_id), заказ, день заказа
--            и номер заказа по порядку у этого человека (number_order)
--   firsts - по человеку: день первого заказа
--   flags  - по человеку: вернулся ли он (returned: 1 или 0)


-- ---------------------------------------------------------------------
-- 1. Возврат по когортам
--    Итог: размер когорты, число вернувшихся и доля вернувшихся (%) по месяцам
--    Результат: от 1.66% до 2.55%, около 2% по всем когортам
-- ---------------------------------------------------------------------

with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered')
,firsts as (select base.customer_unique_id, base.order_day as first_day from base
where base.number_order = 1), flags as
(select firsts.customer_unique_id,
	   firsts.first_day,
	   max(case when base.order_day - firsts.first_day <= 180 and base.order_day != firsts.first_day then 1 else 0 end) as returned
	   from base
join firsts on base.customer_unique_id = firsts.customer_unique_id
group by firsts.customer_unique_id, firsts.first_day)
select date_trunc('month', first_day)::date as cohort_month, sum(returned) as returned_cnt, count(*) as cohort_size,
round(100.0 * sum(returned)/count(*), 2) as returned_pct from flags
where date_trunc('month', first_day)::date >= '2017-01-01' and date_trunc('month', first_day)::date <= '2018-01-01'
group by date_trunc('month', first_day)::date
order by date_trunc('month', first_day)::date;


-- ---------------------------------------------------------------------
-- 2. Размеры когорт (сколько человек впервые купили в каждом месяце)
-- ---------------------------------------------------------------------
-- Исправление: раньше стояло условие base.order_day <= '2018-01-01'. Оно сравнивало полную
-- дату, и в когорту января 2018 попадали только заказы 1 января (71 человек вместо 6842).
-- Теперь условие base.order_day < '2018-02-01', январь 2018 считается полностью.
-- Размеры когорт совпадают с колонкой cohort_size из запроса 1.

with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered')
select date_trunc('month', base.order_day)::date as cohort_month,
	   count(*) as cohort_size
	   from base
where number_order = 1 and base.order_day >= '2017-01-01' and base.order_day < '2018-02-01'
group by date_trunc('month', base.order_day)
order by cohort_month;
