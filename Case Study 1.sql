create database dannys_diner;

use dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);
INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);
INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);
INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
-- 1. What is the total amount each customer spent at the restaurant?

select sales.customer_id as Customer,sum(price) as "Total Amount Spent"
from menu
inner join sales on sales.product_id=menu.product_id
group by sales.customer_id;

-- 2. How many days has each customer visited the restaurant?

select customer_id as customer , count(distinct order_date) as visits
from sales
group by customer;

-- 3. What was the first item from the menu purchased by each customer?

WITH items_puchased AS (
  SELECT 
    sales.customer_id, 
    sales.order_date, 
    menu.product_name,
    DENSE_RANK() OVER (
      PARTITION BY sales.customer_id 
      ORDER BY sales.order_date) AS rankk
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu
    ON sales.product_id = menu.product_id
)

SELECT 
  customer_id, 
  product_name
FROM items_puchased
WHERE rankk = 1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select menu.product_name, count(menu.product_name) as purchase_count
from sales inner join menu on sales.product_id=menu.product_id
group by menu.product_name
order by purchase_count desc
limit 1;

--  5. Which item was the most popular for each customer?

WITH most_popular AS (
  SELECT 
    sales.customer_id, 
    menu.product_name, 
    COUNT(menu.product_id) AS order_count,
    DENSE_RANK() OVER (
      PARTITION BY sales.customer_id 
      ORDER BY COUNT(sales.customer_id) DESC) AS rankk
  FROM dannys_diner.menu
  INNER JOIN dannys_diner.sales
    ON menu.product_id = sales.product_id
  GROUP BY sales.customer_id, menu.product_name
)

SELECT customer_id, product_name, order_count
FROM most_popular WHERE rankk = 1;

-- 6. Which item was purchased first by the customer after they became a member?

with member_purchase as(select sales.customer_id,order_date,product_name,join_date,
dense_rank() over ( partition by customer_id order by order_date) as rankk
from sales
inner join menu
on sales.product_id=menu.product_id
inner join members
on members.customer_id=sales.customer_id
where order_date>join_date)

select customer_id,product_name
from member_purchase
where rankk =1;

-- 7. Which item was purchased just before the customer became a member?

with item_purchased as (select sales.customer_id,order_date,product_name,join_date,
dense_rank() over( partition by customer_id order by order_date desc) as rankk
from sales
inner join menu
on sales.product_id=menu.product_id
inner join members
on sales.customer_id=members.customer_id
where order_date <= join_date)

select customer_id,product_name
from item_purchased
where rankk =1;

-- 8. What is the total items and amount spent for each member before they became a member?

select sales.customer_id, count(price) as "items purchased",sum(price) as "amount spent"
from sales
inner join menu
on menu.product_id=sales.product_id
inner join members
on members.customer_id=sales.customer_id
where order_date <= join_date
group by sales.customer_id
order by sales.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - 
	-- how many points would each customer have?

with points as(select customer_id,product_name,price,
CASE
WHEN product_name = 'sushi' THEN price*20
ELSE price*10
END
AS points
from sales
inner join menu
on sales.product_id=menu.product_id)

select customer_id,sum(points) as points
from points
group by customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
	-- not just sushi -  how many points do customer A and B have at the end of January?

with my_cte as( select sales.customer_id,order_date,product_name,price,join_date,
CASE
WHEN product_name = 'sushi' or (order_date >= join_date and order_date <= date_add(join_date,interval 6 day) )
THEN price*20
WHEN product_name <> 'sushi' and ( order_date< join_date or
order_date > date_add(join_date,interval 6 day) )  THEN price*10
ELSE price
END as points
from sales
inner join menu
on sales.product_id=menu.product_id
inner join members
on members.customer_id=sales.customer_id
where month(order_date)=1 )

select customer_id,sum(points) as "total points"
from my_cte
group by customer_id
order by customer_id;

-- BONUS Questions

-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N).

with my_cte as(select customer_id,order_date,product_name,price
from sales
left join menu
on menu.product_id = sales.product_id)

select my_cte.customer_id,order_date,product_name,price,
case
when order_date>= join_date then "Y"
else "N"
end as member
from my_cte
left join members
 on my_cte.customer_id=members.customer_id;
 
 -- Danny also requires further information about the ranking of customer products, but he purposely does not need
 -- the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet 
 -- part of the loyalty program.
 
 with my_cte as(select customer_id,order_date,product_name,price
from sales
left join menu
on menu.product_id = sales.product_id),

cte2 as(select my_cte.customer_id,order_date,product_name,price,
case
when order_date>= join_date then "Y"
else "N"
end as member
from my_cte
left join members
 on my_cte.customer_id=members.customer_id)
 
 select * ,
 case
when member = "N" then null
else dense_rank() over(
 partition by customer_id,member order by order_date)
end as ranking 
 from cte2
