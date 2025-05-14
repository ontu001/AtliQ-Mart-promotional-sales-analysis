UPDATE fact_events
SET fact_events.base_price = CAST(fact_events.base_price AS UNSIGNED)
where fact_events.base_price is not null ;

ALTER TABLE fact_events
MODIFY COLUMN base_price INT;


ALTER TABLE fact_events
MODIFY COLUMN `quantity_sold(after_promo)` INT ,
MODIFY COLUMN `quantity_sold(before_promo)` int;


ALTER TABLE dim_campaigns
MODIFY COLUMN start_date date,
MODIFY COLUMN end_date date
;


UPDATE dim_campaigns
SET start_date = str_to_date(start_date,'%d-%m-%Y')
where start_date is not null ;


UPDATE dim_campaigns
SET end_date = str_to_date(end_date,'%d-%m-%Y');

describe fact_events;

describe dim_campaigns;

describe dim_products;

# Store performance analysis
# Top ten Stote based on IR
with  cte1 as (
SELECT ds.store_id,ds.city, f.base_price,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price as IR from fact_events f
join dim_stores ds on ds.store_id = f.store_id
        where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price > 0                                                                                    )


SELECT c.store_id, c.city,sum(c.IR) as Total_IR from cte1 c
   group by 1,2 order by 3 desc limit 10;


# Store performance analysis
# Top ten ISU based on IR
with  cte2 as (
SELECT ds.store_id,ds.city,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) as ISU from fact_events f
join dim_stores ds on ds.store_id = f.store_id
        where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price > 0                                                                                    )


SELECT c.store_id, c.city,sum(c.ISU) as Total_ISU  from cte2 c
   group by 1,2 order by 3 desc limit 10;


# Combined.
with  cte3 as (
SELECT ds.store_id,ds.city, f.base_price, dc.campaign_name , f.promo_type , dp.product_name ,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price as IR,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) as ISU
      from fact_events f
join dim_stores ds on ds.store_id = f.store_id
join dim_campaigns dc on dc.campaign_id = f.campaign_id
join dim_products dp on dp.product_code = f.product_code
        where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price > 0)


SELECT c.store_id, c.city,
      c.campaign_name, c.promo_type, sum(c.base_price) as Total_Price,
      sum(c.ISU) as Total_ISU, sum(c.IR) as Total_IR,
      dense_rank() over (order by sum(c.ISU) desc) as ISU_Rnk,
      dense_rank() over (order by sum(c.IR) desc) as IR_Rnk
       from cte3 c
   group by 1,2,3,4;

-- Promotion Type Analysis.
-- Top 2 Promotional Type.
with cte4 as ( 
SELECT f.promo_type,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price as IR from fact_events f
        where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price > 0 )

select c.promo_type, sum(c.IR) as Total_IR from cte4 c
group by 1 order by 2 desc;

-- Bottom 2 Promotional Type.
with cte5 as ( 
SELECT f.promo_type,
(f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) as ISU from fact_events f
        where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) > 0 )

select c.promo_type, sum(c.ISU) as Total_ISU from cte5 c
group by 1 order by 2 ;

-- Significance Difference between promotion type.
with cte6 as (
SELECT f.promo_type,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price as IR,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) as ISU
      from fact_events f
      where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) * f.base_price > 0  and
        (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) > 0)

select c.promo_type, sum(c.IR) as Total_IR, sum(c.ISU) as Total_ISU,
lag(sum(c.IR),1) over ( order by sum(c.IR) desc ) - sum(c.IR) IR_Gap
from cte6 c
group by 1;

--  Best Margins of Promotions 
with cte6 as (
SELECT f.promo_type,
      (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) as ISU
      from fact_events f
      where (f.`quantity_sold(after_promo)`- f.`quantity_sold(before_promo)`) > 0)

select c.promo_type,  sum(c.ISU) as Total_ISU, avg(c.ISU) as Avg_ISU 
from cte6 c group by 1 order by 2 desc;

-- Product and Category type Analysis.

SELECT dp.category, 
      sum(f.`quantity_sold(after_promo)`) as Total_Sales 
      from fact_events f
join dim_products dp on dp.product_code = f.product_code
group by 1 order by 2 desc;


