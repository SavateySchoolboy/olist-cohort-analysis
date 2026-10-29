-- Проверка гипотезы возвращаются ли реже те у кого первый заказ пришел позже обещанной даты
with orders_flagged as (select c.customer_unique_id, 
	   row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order,
	   o.order_delivered_customer_date,
	   o.order_estimated_delivery_date,
	   (case when o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date then 1 else 0 end) as is_late_order
from orders o
join customers c on o.customer_id = c.customer_id 
where order_status = 'delivered' and o.order_delivered_customer_date is not null)
select 100.0 * avg(is_late_order) as pcn_late from orders_flagged 
where number_order = 1;

with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order,
(case when o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date then 1 else 0 end) as is_late_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered' and o.order_delivered_customer_date is not null)
,firsts as (select base.customer_unique_id, 
				   base.order_day as first_day,
				   is_late_order as first_is_late
				   from base
where base.number_order = 1), flags as(select firsts.customer_unique_id,
	   firsts.first_day,
	   max(case when base.order_day - firsts.first_day <= 180 and base.order_day != firsts.first_day then 1 else 0 end) as returned,
	   first_is_late
	   from base
join firsts on base.customer_unique_id = firsts.customer_unique_id
group by firsts.customer_unique_id, firsts.first_day, first_is_late)
select first_is_late, count(*) as people, sum(returned) as reterned_cnt, (100.0 * avg(returned)) as returned_pct from flags
where first_day >= '2017-01-01' and first_day < '2018-02-01'
group by first_is_late;


with base as (
select c.customer_unique_id, o.order_id, date_trunc('day', o.order_purchase_timestamp)::date as order_day,
row_number() over (partition by c.customer_unique_id order by o.order_purchase_timestamp) as number_order,
(case when o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date then 1 else 0 end) as is_late_order
from customers c
join orders o on o.customer_id = c.customer_id
where o.order_status = 'delivered' and o.order_delivered_customer_date is not null)
,firsts as (select base.customer_unique_id, 
				   base.order_day as first_day,
				   is_late_order as first_is_late
				   from base
where base.number_order = 1), flags as(select firsts.customer_unique_id,
	   firsts.first_day,
	   max(case when base.order_day - firsts.first_day <= 180 and base.order_day != firsts.first_day then 1 else 0 end) as returned,
	   first_is_late
	   from base
join firsts on base.customer_unique_id = firsts.customer_unique_id
group by firsts.customer_unique_id, firsts.first_day, first_is_late), hi_square_data as (
select first_is_late, sum(returned) as returned, count(returned) - sum(returned) as not_returned  from flags
where first_day >= '2017-01-01' and first_day < '2018-02-01'
group by first_is_late), counting_hi_square as
--select * from hi_square_data
(select (sum(returned) + sum(not_returned)) as all_sum,
	    (select returned + not_returned  from hi_square_data where first_is_late = 0) as not_late_sum,
	    (select returned + not_returned  from hi_square_data where first_is_late = 1) as late_sum,
	    sum(returned) as sum_returned,
	    sum(not_returned) as sum_not_returned,
	    (select returned     from hi_square_data where first_is_late = 0) as o1,
		(select not_returned from hi_square_data where first_is_late = 0) as o2,
		(select returned     from hi_square_data where first_is_late = 1) as o3,
		(select not_returned from hi_square_data where first_is_late = 1) as o4
		from hi_square_data), sec_hi_square_Es as
(select o1, o2, o3, o4,
(not_late_sum  * sum_returned / all_sum) as E1,
	   (not_late_sum * sum_not_returned / all_sum) as E2,
	   (late_sum  * sum_returned / all_sum) as E3,
	   (late_sum * sum_not_returned / all_sum) as E4
	    from counting_hi_square) 
select ((((o1 - e1)^2)/e1) + (((o2 - e2)^2)/e2) + (((o3 - e3)^2)/e3) + (((o4 - e4)^2)/e4)) as chi_square_stat from sec_hi_square_Es;
