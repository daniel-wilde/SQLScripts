-- 2nd Highest salary: 
SELECT MAX(salary) AS SecondHighestSalary 
FROM Employee 
WHERE salary < (SELECT MAX(salary) FROM Employee);

-- Nth Highest Salary: 
CREATE FUNCTION getNthHighestSalary(N INT) RETURNS INT 
BEGIN 
    SET N = N-1; 
    RETURN  
    ( 
        SELECT DISTINCT salary 
        FROM Employee 
        ORDER BY salary DESC 
        LIMIT 1 
        OFFSET N  -- LIMIT X OFFSET Y – OFFSET = "SKIP" 
    ); 
END; 

-- Rank Scores
SELECT
    score
    ,dense_rank() over (ORDER BY score DESC) AS 'rank'
FROM Scores
ORDER BY 'rank' ASC

-- Consecutive Numbers
SELECT 
    DISTINCT(n.Nums) AS ConsecutiveNums
FROM
(
    SELECT 
        CASE 
            WHEN cast(l1.num as decimal(8,2)) = cast(l2.num as decimal(8,2))
                AND cast(l1.num as decimal(8,2)) = cast(l3.num as decimal(8,2)) 
                THEN l1.num
            ELSE NULL
        END AS Nums
    FROM Logs l1
        LEFT OUTER JOIN Logs l2 ON l1.id = l2.id-1
        LEFT OUTER JOIN Logs l3 ON l1.id = l3.id-2
) n
WHERE n.Nums IS NOT NULL

-- Employees Earning more than their Managers
SELECT e.name as Employee
FROM Employee e
    INNER JOIN Employee m ON e.ManagerId = m.id
WHERE e.salary > m.salary

SELECT e.name as Employee
FROM Employee e
WHERE EXISTS 
(
    SELECT 1
    FROM Employee m
    WHERE m.id = e.managerId
        AND m.salary < e.salary
)

-- Departmet Highest Salary - Mine
WITH emp_sals AS
(
    SELECT 
        d.name as Department
        ,e.name as Employee
        ,e.Salary 
        ,RANK() OVER (PARTITION BY d.name ORDER BY e.salary DESC) as rnk
    FROM Department d
        INNER JOIN Employee e on d.id = e.departmentid
)
SELECT 
    e.Department
    ,e.Employee
    ,e.Salary
FROM emp_sals e
where e.rnk = 1

-- Departmet Highest Salary - CTE
WITH max_sals AS
(
    SELECT 
        d.id as dept_id
        ,d.name AS Department
        ,MAX(e.Salary) as Salary
    FROM Department d
        INNER JOIN Employee e on d.id = e.departmentid
    GROUP BY d.id
)
SELECT 
    m.Department
    ,e.name as Employee
    ,e.Salary
FROM max_sals m
    INNER JOIN Employee e on m.dept_id = e.departmentID
        AND m.Salary = e.salary

-- Departmet Highest Salary - OPTIMAL:
SELECT
    Department.name AS 'Department',
    Employee.name AS 'Employee',
    Salary
FROM
    Employee
        JOIN
    Department ON Employee.DepartmentId = Department.Id
WHERE
    (Employee.DepartmentId , Salary) IN
    (   SELECT
            DepartmentId, MAX(Salary)
        FROM
            Employee
        GROUP BY DepartmentId
    )
;

-- Managers with at least 5 employees
WITH managers_5r AS
(
    SELECT managerID
    FROM Employee
    GROUP BY managerID
    HAVING COUNT(*) >= 5
)
SELECT name
FROM Employee e
    INNER JOIN managers_5r m ON e.id = m.managerID;

-- TOP 3 Salaries in each department
WITH top3 AS 
(
    SELECT
        id
        ,DENSE_RANK() OVER (PARTITION BY departmentId ORDER BY salary DESC) as RNK
    FROM Employee
)
SELECT 
    d.name as Department
    ,e.name AS Employee
    ,e.salary
FROM Employee e 
    INNER JOIN top3 t ON e.id = t.id AND t.RNK <= 3
    INNER JOIN Department d on e.departmentId = d.id

-- Customers who never order
SELECT name AS Customers
FROM Customers c
WHERE NOT EXISTS (
    select 1 
    from Orders o 
    where o.customerId = c.id
    LIMIT 1
)

-- Friend Requests I: Overall Acceptance Rate 
WITH ac AS 
(
    SELECT requester_id, accepter_id 
    from RequestAccepted 
    GROUP BY requester_id, accepter_id 
),
rq AS
(
    SELECT sender_id, send_to_id
    from FriendRequest  
    GROUP BY sender_id, send_to_id
)
SELECT ROUND( COALESCE( (SELECT COUNT(*) FROM ac) / (SELECT COUNT(*) FROM rq), 0) , 2) as accept_rate 










