use dannys_diner;

/* What is the total amount each customer spent at the restaurant? */
select 
	sales.customer_id,
    sum(case when sales.customer_id in ('A', 'B', 'C') then price else null end) as total_price
from sales
	left join menu
		on sales.product_id = menu.product_id
group by 1;

/* How many days has each customer visited the restaurant? */
select
	customer_id,
    count(distinct order_date) as no_of_days
from sales
group by 1;

/* What was the first item from the menu purchased by each customer and on each individual day? */
create temporary table first_orders
select
	customer_id,
    order_date,
    menu.product_name,
    rank() over(
		partition by sales.customer_id
        order by sales.order_date) as ranks
from sales
	left join menu
		on sales.product_id = menu.product_id;

select
	customer_id,
    product_name
from first_orders
where ranks = 1
group by customer_id, product_name;

/* What is the most purchased item on the menu and how many times was it purchased by all customers? */
select 
	product_name,
    count(sales.product_id) as most_purchased_item
from menu
	left join sales
		on menu.product_id = sales.product_id
group by product_name
order by most_purchased_item desc
limit 1;

/* Which item was the most popular for each customer? */
create temporary table popular_item_demos
select 
	sales.customer_id,
   menu.product_name,
	count(menu.product_id ) as most_popular_item,
    rank() over( 
		partition by customer_id
        order by count(sales.customer_id) desc) as ranks
from sales
	left join menu
		on sales.product_id = menu.product_id
group by 1,2;

select 
	popular_item_demos.customer_id,
    product_name,
    most_popular_item
from popular_item_demos
where ranks = 1
group by 1,2;

/* Which item was purchased first by the customer after they became a member? */
create temporary table members_orders
select
	members.customer_id,
    sales.product_id,
    ROW_NUMBER() OVER(
      PARTITION BY members.customer_id
      ORDER BY sales.order_date) AS row_num
from members
	left join sales
		on sales.customer_id = members.customer_id
        and members.join_date < sales.order_date
group by members.customer_id,2;

select 
	members_orders.customer_id,
    menu.product_name
from members_orders
	left join menu
		on members_orders.product_id = menu.product_id
where row_num = 1
order by 1;

/*  Which item was purchased just before the customer became a member? */

create temporary table before_members_first_orders
select
	members.customer_id,
    sales.order_date,
    sales.product_id,
    row_number() OVER(
      PARTITION BY members.customer_id
      ORDER BY sales.order_date desc) AS row_num
from members
	left join sales
		on sales.customer_id = members.customer_id
        and members.join_date > sales.order_date;

select 
	before_members_first_orders.customer_id,
    menu.product_name
from before_members_first_orders
	left join menu
		on before_members_first_orders.product_id = menu.product_id
where row_num = 1
order by 1 asc;

/* What is the total items and amount spent for each member before they became a member */
select
	sales.customer_id,
    count(sales.product_id) as total_items,
   sum(menu.price) as total_price
from members
	left join sales
		on sales.customer_id = members.customer_id
         and members.join_date > sales.order_date
	left join menu
		on sales.product_id = menu.product_id
group by members.customer_id;

/* If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have? */
create temporary table multiplier
select
	menu.product_id,
    case when menu.product_id =1 then price*20
		else price*10
        end as new_price
	from menu;
    
select 
	sales.customer_id,
    sum(multiplier.new_price) as total_price
from sales
	left join multiplier
		on sales.product_id = multiplier.product_id
group by sales.customer_id;

/* In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January? */
SELECT 
  sales.customer_id, 
  menu.product_name,
  sales.order_date,
  sum(CASE
    WHEN menu.product_name = 'sushi' THEN 2 *10* menu.price
    WHEN sales.order_date between members.join_date and (members.join_date +6 )THEN 2 * 10 * menu.price
    ELSE 10 * menu.price END) AS points
FROM sales
left JOIN menu
  ON sales.product_id = menu.product_id
left join members
	on sales.customer_id = members.customer_id
where sales.order_date <= '2021-01-31'
GROUP BY sales.customer_id
having sales.customer_id in('A','B');

/*  Join All The Things */
select
	sales.customer_id,
    sales.order_date,
    menu.product_name,
    menu.price,
case
	when sales.order_date >=join_date then 'Y' 
    when sales.order_date < join_date then 'N'
    else 'N' 
	end as Members
from menu
	left join sales
		on menu.product_id = sales.product_id
	left join members
		on sales.customer_id = members.customer_id
order by 1,2;
    
/* Rank All The Things */
create temporary table Members_ranking
select
	sales.customer_id,
    sales.order_date,
	menu.product_name,
    menu.price,
case
	when sales.order_date >=join_date then 'Y' 
    when sales.order_date < join_date then 'N'
    else 'N' 
    end as Members
	from menu
		left join sales
			on menu.product_id = sales.product_id
		left join members
			on sales.customer_id = members.customer_id
order by 1,2;

select
	*,
case
	when Members = 'N' then null else rank() over(
			partition by customer_id, Members
            order by order_date) end as Ranking
from Members_ranking;