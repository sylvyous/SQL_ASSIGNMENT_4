--•	Calculate the average rental duration and total revenue for each customer,
--along with their top 3 most rented film categories.
SELECT concat(se_customer.first_name, ' ', se_customer.last_name) AS customer_name,
       se_category.name AS genre,
	   COUNT(se_rental.rental_id) AS total_rental,
       AVG(se_rental.return_date - se_rental.rental_date) AS average_rental_duration,
	   SUM(se_payment.amount) AS total_revenue
	  
FROM customer AS se_customer
INNER JOIN rental AS se_rental
	ON se_customer.customer_id = se_rental.customer_id
INNER JOIN payment AS se_payment
	ON se_customer.customer_id = se_payment.customer_id
INNER JOIN inventory AS se_inventory
	ON se_rental.inventory_id = se_inventory.inventory_id
INNER JOIN film AS se_film
	ON se_inventory.film_id = se_film.film_id
INNER JOIN film_category AS film_category
	ON film_category.film_id = se_film.film_id
INNER JOIN category AS se_category
	ON se_category.category_id = film_category.category_id
GROUP BY customer_name, genre



-----------------------------------------------------------------

--	Identify customers who have never rented films but have made payments.
SELECT	concat(se_customer.first_name, ' ', se_customer.last_name) AS customer_name,
		se_payment.payment_id as payment,
		se_rental.rental_id as rentals
		
FROM customer AS se_customers 
LEFT OUTER JOIN rental as se_rental  
		ON se_customer.customer_id = se_rental.customer_id
INNER JOIN payment AS se_payment 
		ON se_customer.customer_id = se_payment.customer_id
WHERE se_rental.rental_id IS NULL
GROUP BY concat(se_customer.first_name, ' ', se_customer.last_name), se_payment.payment_id, se_rental.rental_id

--------------------------------------------------------------------------
--	Determine the average number of films rented per customer, broken down by city.
SELECT	concat(se_customer.first_name, ' ', se_customer.last_name) AS customer_name,
		se_city.city as city_name,
		count(se_rental.rental_id)as rented_number_films
FROM customer AS se_customer
INNER JOIN rental AS se_rental  
	ON se_customer.customer_id = se_rental.customer_id
INNER JOIN address AS se_address
	ON se_customer.address_id = se_address.address_id
INNER JOIN city AS se_city
	ON se_address.city_id = se_city.city_id
GROUP BY concat(se_customer.first_name, ' ', se_customer.last_name), se_city.city

------------------------------------------------------------------------------------------

--Identify films that have been rented more than the average number of times and are currently not in inventory.
WITH CTE_RENTAL AS(
	SELECT	se_film.title as movie_name,
			se_film.rental_rate AS rental_rate,
			se_inventory.inventory_id
	FROM rental AS se_rental
	LEFT OUTER JOIN inventory AS se_inventory
		ON se_rental.inventory_id = se_inventory.inventory_id
	INNER JOIN film AS se_film
		ON se_inventory.film_id = se_film.film_id
	GROUP BY se_film.title,se_inventory.inventory_id, se_film.rental_rate
)


SELECT * FROM CTE_RENTAL
WHERE CTE_RENTAL.rental_rate > (SELECT AVG(rental_rate) FROM film)

-----------------------------------------------------------------------------
--	Calculate the replacement cost of lost films for each store, considering the rental history.


SELECT	se_film.title as movie_name,
		se_film.rental_rate AS rental_rate,
		se_film.rental_duration AS rental_duration,
		se_film.replacement_cost AS replacement_cost
FROM film AS se_film
INNER JOIN inventory AS se_inventory
	ON se_film.film_id = se_inventory.film_id
INNER JOIN store AS se_store
	ON se_inventory.store_id = se_store.store_id
GROUP BY se_film.title,se_film.rental_rate, se_film.replacement_cost, se_film.rental_duration
ORDER BY rental_duration
----------------------------------------------------------------------------
--	Identify stores where the revenue from film rentals exceeds the revenue from payments for all customers.
WITH CTE_REVENUE AS(
	SELECT	se_store.store_id AS store,
			SUM(se_payment.amount) AS total_revenue
	FROM payment AS se_payment
	INNER JOIN staff AS se_staff
		ON se_payment.staff_id = se_staff.staff_id
	INNER JOIN store AS se_store
		ON se_staff.store_id = se_store.store_id
	GROUP BY se_store.store_id
)

SELECT * FROM CTE_REVENUE
WHERE CTE_REVENUE.total_revenue>(SELECT SUM(amount) FROM payment )

-------------------------------------------------------------------
--Determine the average rental duration and total revenue for each store, considering different payment methods.

WITH CTE_STORE_REVENUE AS
(
	SELECT	se_store.store_id AS store,
			SUM(se_payment.amount) AS total_revenue,
	        AVG(se_rental.return_date-se_rental.rental_date)
	FROM payment AS se_payment
	INNER JOIN staff AS se_staff
		ON se_payment.staff_id = se_staff.staff_id
	INNER JOIN rental AS se_rental 
		ON se_payment.rental_id = se_rental.rental_id
	INNER JOIN store AS se_store
		ON se_staff.store_id = se_store.store_id
	GROUP BY se_store.store_id
)

SELECT * FROM CTE_STORE_REVENUE


-----------------------------------------------------------------

--•	Create a report that shows the top 5 most rented films in each category,
--along with their corresponding rental counts and revenue.

SELECT  se_category.name AS genre,
		se_film.title AS movie_name,
		count(se_rental.rental_id) AS  rental_count,
	    SUM (se_payment.amount) AS revenue
FROM payment AS se_payment
INNER JOIN rental AS se_rental
	ON se_payment.rental_id = se_rental.rental_id
INNER JOIN inventory AS se_inventory
	ON se_rental.inventory_id = se_inventory.inventory_id
INNER JOIN film AS se_film
	ON se_inventory.film_id = se_film.film_id
INNER JOIN film_category AS film_category
	ON film_category.film_id = se_film.film_id
INNER JOIN category AS se_category
	ON se_category.category_id = film_category.category_id
GROUP BY se_category.name, se_film.title
ORDER BY se_category.name, count(se_rental.rental_id) DESC

--------------------------------------------------------------------------------------

--•	Find the correlation between customer rental frequency and the average rating of the rented films.

WITH CTE_RENTAL_RATE AS
(
SELECT se_film.title AS movie,
       
	   COUNT(se_rental.rental_id) AS total_rentals,
       se_film.rating AS rating
	   
FROM rental AS se_rental
INNER JOIN payment AS se_payment
	ON se_rental.rental_id = se_payment.rental_id
INNER JOIN inventory AS se_inventory
	ON se_rental.inventory_id = se_inventory.inventory_id
INNER JOIN film AS se_film
	ON se_inventory.film_id = se_film.film_id

GROUP BY se_film.title, se_film.rating
ORDER BY rating

)

SELECT  rating, 
		COUNT(total_rentals) AS rental_frequency 
FROM CTE_RENTAL_RATE
GROUP BY rating
ORDER BY rental_frequency DESC

-- Although PG-13 rated movies are rented most frequently, There doesn't seem to be a strong correlation between
-- the MPA rating and the rental frequency

-------------------------------------------------------------------------------------
-- Analyse the seasonal variation in rental activity and payments for each store.


SELECT	se_store.store_id ,
		EXTRACT(MONTH FROM se_rental.rental_date ) AS MONTH,
        COUNT(se_rental.rental_id) AS total_rentals,
	    SUM(se_payment.amount) AS revenue
			
FROM rental AS se_rental
INNER JOIN payment AS se_payment
	ON se_rental.rental_id = se_payment.rental_id
INNER JOIN staff AS se_staff
	ON se_payment.staff_id = se_staff.staff_id
INNER JOIN store AS se_store
	ON se_staff.store_id = se_store.store_id
GROUP BY se_store.store_id, EXTRACT(MONTH FROM se_rental.rental_date )
ORDER BY EXTRACT(MONTH FROM se_rental.rental_date )

-- We can see from our table that both stores 1 and 2 are very close in terms of rental activity and revenue during 
--the same months of the season. In the month of February we witness the lowest activity and revenue 
--for both stores, This increases substantially during the month of June with July recording the highest 
--total revenue and rentals for both stores, and slowly tapering further into the month of August . 
--we can conclude that the summer seasons have far greater overall activity for both stores

-------------------------------------------------------------------------------------

--•	Develop a query that automatically updates the top 10 most frequently rented films, 
--considering a rolling 3-month window.
SELECT	
		se_film.title,
        COUNT(se_rental.rental_id) AS total_rentals,
		EXTRACT(MONTH FROM se_rental.rental_date ) AS MONTH
	    
			
FROM rental AS se_rental
INNER JOIN payment AS se_payment
	ON se_rental.rental_id = se_payment.rental_id
INNER JOIN inventory AS se_inventory
	ON se_rental.inventory_id = se_inventory.inventory_id
INNER JOIN film AS se_film
	ON se_inventory.film_id = se_film.film_id

GROUP BY se_film.title, EXTRACT(MONTH FROM se_rental.rental_date )
ORDER BY EXTRACT(MONTH FROM se_rental.rental_date ) DESC, COUNT(se_rental.rental_id) DESC
LIMIT 10















