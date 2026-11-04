-- =====================================================================
-- 05. Оценка первого заказа и повторная покупка за 180 дней
-- База: olist (PostgreSQL)
-- =====================================================================
-- Сравниваем покупателей с оценкой первого доставленного заказа 1–3 и 4–5.
-- Покупатель: customer_unique_id. Период первого заказа: с января 2017
-- по январь 2018 включительно. Доставленные заказы в тот же день не
-- считаются возвратом; повторная покупка учитывается в пределах 180 дней.
--
-- base: доставленные заказы и их номер по времени у каждого покупателя.
-- firsts: первый заказ покупателя; flags: признак возврата за 180 дней.
-- reviews_return: отзыв по первому заказу и выбор анализируемых когорт.
-- reviews_return_num: номер отзыва по времени ответа, затем по review_id;
--   заказы без оценки исключаются из сравнения.
-- group_review: первый по указанной сортировке отзыв, группы 1–3 и 4–5.
-- Итог: число покупателей, вернувшихся и средний returned — доля возврата.
-- Для проверки значимости используем 05_review_score_chi_square.ipynb.
-- Последовательность повторного заказа и оценки требует отдельной проверки.

with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered')
,firsts as 
(select base.customer_unique_id, 
	    base.order_day as first_day,
	    base.order_id as order_id
		from base
where base.number_order = 1), flags as
(select firsts.customer_unique_id,
	   firsts.first_day,
	   firsts.order_id,
	   max(case when base.order_day - firsts.first_day <= 180 and base.order_day != firsts.first_day then 1 else 0 end) as returned
	   from base
join firsts on base.customer_unique_id = firsts.customer_unique_id
group by firsts.customer_unique_id, firsts.first_day, firsts.order_id), reviews_return as
(select f.customer_unique_id,
	   f.first_day,
	   f.returned,
	   t.review_score,
	   f.order_id,
	   t.review_answer_timestamp,
	   t.review_id
       from flags f
left join order_reviews t on t.order_id = f.order_id
where first_day::date >= '2017-01-01' and first_day::date < '2018-02-01'), reviews_return_num as
(select *, row_number() over (partition by reviews_return.order_id order by review_answer_timestamp, review_id) as number_review
from reviews_return
where review_score is not null), group_review as
(select returned, review_score, case when review_score in (1, 2, 3) then '1-3' else '4-5' end as score_group
from reviews_return_num
where number_review = 1)
select score_group, AVG(returned), count(*) as size,  sum(returned) as returned from group_review
group by score_group


