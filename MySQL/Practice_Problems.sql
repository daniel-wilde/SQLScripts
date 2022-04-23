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





















