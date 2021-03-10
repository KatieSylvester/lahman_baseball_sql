/* LAHMAN BASEBALL ANALYSIS */

--Q1 --
-- What range of years for baseball games played does the provided database cover?
select min(yearid), max(yearid)
from appearances;

--Q2 --
--Find the name and height of the shortest player in the database. 
--How many games did he play in? What is the name of the team for which he played?
SELECT DISTINCT ppl.namefirst, ppl.namelast, app.g_all AS games, t.name AS team
FROM people AS ppl
LEFT JOIN appearances AS app
ON ppl.playerid = app.playerid
RIGHT JOIN teams AS t
ON app.teamid = t.teamid
WHERE ppl.height IN (SELECT MIN(height) FROM people);


/* 3. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player’s first and last names as well as the total salary 
they earned in the major leagues. Sort this list in descending order by the total 
salary earned. Which Vanderbilt player earned the most money in the majors? */
--Q3--Option1
WITH vandy_players AS (
	SELECT DISTINCT playerid
	FROM collegeplaying
	WHERE schoolid = (SELECT schoolid
	FROM schools
	WHERE schoolname iLIKE '%vand%'))
SELECT 
	namefirst AS first_name, 
	namelast AS last_name,
	SUM(salary::decimal::money) AS total_major_league_salary
FROM vandy_players
LEFT JOIN people
USING (playerid)
LEFT JOIN salaries
USING (playerid) 
GROUP BY namefirst,namelast
HAVING SUM(salary) >0
ORDER BY SUM(salary) DESC;
	
--Q3-- Option2
WITH vandy_salaries as (SELECT DISTINCT namefirst AS namefirst, namelast, schoolid, salaries.yearid AS yearid, salary
						 FROM people INNER JOIN collegeplaying USING(playerid)
						 INNER JOIN salaries USING(playerid)
						 WHERE schoolid = 'vandy'
						 ORDER BY namefirst, namelast, yearid)
SELECT namefirst, namelast, schoolid, SUM(salary)::text::money AS total_salary
FROM vandy_salaries
GROUP BY namefirst, namelast, schoolid
ORDER BY total_salary DESC;

-- Q3 MISC - To confirm David Price's lifetime salary 81,851,296
SELECT SUM(salary) FROM SALARIES where playerid = 'priceda01' GROUP BY playerid;
SELECT * FROM people WHERE namefirst='David' AND namelast='Price'
SELECT * FROM collegeplaying LIMIT 10;
	
/*Q4
Using the fielding table, group players into three groups based on their position: 
label players with position OF as "Outfield", those with position "SS", "1B", "2B", 
and "3B" as "Infield", and those with position "P" or "C" as "Battery". 
Determine the number of putouts made by each of these three groups in 2016. */
WITH calculation AS (
		SELECT playerid, pos,
			CASE WHEN pos = 'OF' THEN 'Outfield'
			WHEN pos = 'SS' OR pos ='1B' OR pos = '2B' OR pos = '3B' THEN 'Infield'
			ELSE 'Battery' END AS position,
			po AS PutOut,
			yearid
		FROM fielding
		WHERE yearid = '2016')
SELECT position, SUM(putout) AS number_putouts
FROM calculation
GROUP BY position;


/* Q5 
Find the average number of strikeouts per game by decade since 1920. 
Round the numbers you report to 2 decimal places. 
Do the same for home runs per game. Do you see any trends? */
SELECT teams.yearid /10*10 as decade, sum(so) AS total_strike_out,
	   Sum(g) as total_games,
	   round(sum(so)::decimal / sum(g),2)::decimal as average_strike_out
	   FROM teams
	   WHERE yearid >= '1920'
	   GROUP BY yearid/10*10
	   ORDER BY decade DESC
	   
	   -- Home Runs
SELECT teams.yearid /10*10 as decade, sum(hr) AS homerun,
	   Sum(g) as total_games,
	   round(sum(hr)::decimal / sum(g),2)::decimal as average_homerun
	   FROM teams
	   WHERE yearid >= '1920'
	   GROUP BY yearid/10*10
	   ORDER BY decade DESC

/* Q6
Find the player who had the most success stealing bases in 2016, where success is measured 
as the percentage of stolen base attempts which are successful. 
(A stolen base attempt results either in a stolen base or being caught stealing.) 
Consider only players who attempted at least 20 stolen bases */
--Q6--Option1
SELECT DISTINCT b.playerid, 
				CONCAT(p.namefirst,' ',p.namelast) AS player_name, 
				(b.sb) AS stolen_bases, 
				(b.cs) AS caught_stealing, 
				b.sb+b.cs AS sb_cs, 
				ROUND(CAST(float8 (b.sb/(b.sb+b.cs)::float*100) AS NUMERIC),2) AS successful_stolen_bases_percent
FROM batting AS b
LEFT JOIN people AS p 
ON b.playerid = p.playerid
WHERE b.yearid = '2016'
GROUP BY b.playerid, p.namefirst, p.namelast, b.sb, b.cs
HAVING SUM(b.sb+b.cs) >= 20
ORDER BY successful_stolen_bases_percent DESC

--Q6--Option2
select  distinct(p.playerid),
		p.namefirst, p.namelast,
		a.yearid, b.sb,
		cast(b.sb as numeric) + cast(b.cs as numeric) as total_attempts,
		round(cast(b.sb as numeric) /(cast(b.sb as numeric) + cast(b.cs as numeric)),2) as percentage_stole
from people as p left join appearances as a
	on p.playerid = a.playerid 
	left join batting as b
	on p.playerid = b.playerid
where	a.yearid = 2016
		and b.yearid =2016
		and cast(b.sb as numeric) + cast(b.cs as numeric) >= 20
order by percentage_stole desc;


/* Q7 */
/* Q7, part 1 
From 1970 – 2016, what is the largest number of wins for a team 
that did not win the world series during that time frame? */
SELECT yearid, teamid, MAX(w) as max_wins
FROM teams
WHERE 
	yearid BETWEEN 1970 AND 2016
	AND teamid NOT IN (
	SELECT teamid
	FROM teams
	WHERE wswin = 'Y' 
	AND yearid >= 1970 AND yearid <=2016)
GROUP BY yearid, teamid
ORDER BY MAX(w)DESC
LIMIT 1;

/* Q7 - part2 
What is the smallest number of wins for a team that did win the world series? 
Doing this will probably result in an unusually small number of wins for a world series champion – 
determine why this is the case. Then redo your query, excluding the problem year. 
The smallest number of wins was in 1981 with the Toronto Blue Jays with 37 wins.
1981 was the year of the player's strike and the season was cut short. */
SELECT yearid, teamid, MIN(w) as min_wins
FROM teams
WHERE 
	yearid BETWEEN 1970 AND 2016
	AND teamid IN (
	SELECT teamid
	FROM teams
	WHERE wswin = 'Y' 
	AND yearid BETWEEN 1970 AND 2016)
GROUP BY yearid, teamid
ORDER BY MIN(w)
LIMIT 1;

/* Q7 - part 3  when you remove 1981 from the query, the lowest number of 
wins is from Detroit Tigers in 2003 with 43 wins*/
SELECT yearid, teamid, MIN(w) as min_wins
FROM teams
WHERE (yearid BETWEEN 1970 AND 1980 OR yearid BETWEEN 1982 AND 2016)
	AND teamid IN (
	SELECT teamid
	FROM teams
	WHERE wswin = 'Y' 
	AND yearid BETWEEN 1970 AND 2016)
GROUP BY yearid, teamid
ORDER BY MIN(w)
LIMIT 1;

/* Q7 - part 4  How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? 
What percentage of the time?  */
WITH most_wins AS (
	SELECT 
		yearid,
		MAX(w) AS max_w
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
	GROUP BY yearid
	ORDER BY yearid),
teams_most_wins AS (
	SELECT t.yearid,
	t.teamid
	FROM teams AS t
	INNER JOIN most_wins
	ON t.yearid = most_wins.yearid AND t.w = most_wins.max_w),
ws_wins AS (
	SELECT
		yearid,
		teamid
	FROM teams
	WHERE wswin = 'Y'
		AND yearid BETWEEN 1970 AND 2016),
combined_stats AS (
SELECT
	teams_most_wins.yearid,
	teams_most_wins.teamid AS most_wins_team,
	ws_wins.teamid AS ws_wins_team
FROM teams_most_wins
LEFT JOIN ws_wins
USING(yearid)
ORDER BY yearid)
SELECT
	COUNT(CASE WHEN cs.most_wins_team = cs.ws_wins_team THEN 1 END) AS count_most_wins_also_ws_winner,
	CONCAT(ROUND(100*(COUNT(CASE WHEN cs.most_wins_team = cs.ws_wins_team THEN 1 END)::decimal) / (COUNT(Distinct yearid)::decimal),2),'%') AS percentage_most_wins_also_ws_winner
FROM combined_stats AS cs;

/* Q8 - Using the attendance figures from the homegames table, 
find the teams and parks which had the top 5 average attendance per game in 2016 
where average attendance is defined as total attendance divided by number of games). 
Only consider parks where there were at least 10 games played. Report the park name, 
team name, and average attendance. Repeat for the lowest 5 average attendance. */
WITH avg_attend AS (SELECT park, team, attendance/games AS avg_attendance
					FROM homegames
					WHERE year = 2016
						  AND games >= 10),
	 avg_attend_full AS (SELECT park_name, name as team_name, avg_attendance
						 FROM avg_attend INNER JOIN teams ON avg_attend.team = teams.teamid
						 	  INNER JOIN parks ON avg_attend.park = parks.park
						 WHERE teams.yearid = 2016
						 GROUP BY park_name, avg_attendance, name),
	 top_5 AS (SELECT *, 'top_5' AS category
			   FROM avg_attend_full
			   ORDER BY avg_attendance DESC
			   LIMIT 5),
	 bottom_5 AS (SELECT *, 'bottom_5' AS category
			      FROM avg_attend_full
			      ORDER BY avg_attendance
			      LIMIT 5)
SELECT *
FROM top_5
UNION ALL
SELECT *
FROM bottom_5;


/* Q9 - Which managers have won the TSN Manager of the Year award in both the 
National League (NL) and the American League (AL)? Give their full name and the teams 
that they were managing when they won the award. */
WITH mngr_list AS (SELECT playerid, awardid, COUNT(DISTINCT lgid) AS lg_count
				   FROM awardsmanagers
				   WHERE awardid = 'TSN Manager of the Year'
				   		 AND lgid IN ('NL', 'AL')
				   GROUP BY playerid, awardid
				   HAVING COUNT(DISTINCT lgid) = 2),
	 mngr_full AS (SELECT playerid, awardid, lg_count, yearid, lgid
				   FROM mngr_list INNER JOIN awardsmanagers USING(playerid, awardid))
SELECT DISTINCT namegiven, namelast, name AS team_name, mngr_full.lgid, mngr_full.yearid
FROM mngr_full INNER JOIN people USING(playerid)
	 INNER JOIN managers USING(playerid, yearid, lgid)
	 INNER JOIN teams ON mngr_full.yearid = teams.yearid AND mngr_full.lgid = teams.lgid AND managers.teamid = teams.teamid;

/* Q10 - Analyze all the colleges in the state of Tennessee. Which college has had the most 
success in the major leagues. Use whatever metric for success you like - number of players, 
number of games, salaries, world series wins, etc. */
WITH tn_schools AS (SELECT schoolname, schoolid
					FROM schools
					WHERE schoolstate = 'TN'
					GROUP BY schoolname, schoolid)
SELECT schoolname, COUNT(DISTINCT playerid) AS player_count, SUM(salary)::text::money AS total_salary, (SUM(salary)/COUNT(DISTINCT playerid))::text::money AS money_per_player
FROM tn_schools INNER JOIN collegeplaying USING(schoolid)
	 INNER JOIN people USING(playerid)
	 INNER JOIN salaries USING(playerid)
GROUP BY schoolname
ORDER BY money_per_player DESC;


/* Q11 - Is there any correlation between number of wins and team salary? Use data from 2000 
and later to answer this question. As you do this analysis, keep in mind that salaries across 
the whole league tend to increase together, so you may want to look on a year-by-year basis. */
WITH team_year_sal_w AS (SELECT teamid, yearid, SUM(salary) AS total_team_sal, AVG(w)::integer AS w
						 FROM salaries INNER JOIN teams USING(yearid, teamid)
						 WHERE yearid >= 2000
						 GROUP BY yearid, teamid)
SELECT yearid, CORR(total_team_sal, w) AS sal_win_corr 
--correlation results intrepretation:  0 means no correlation, 1 means exact correlation where you can make perfect predictions
FROM team_year_sal_w
GROUP BY yearid
ORDER BY yearid;


/* Q12 In this question, you will explore the connection between number of wins and attendance.
Does there appear to be any correlation between attendance at home games and number of wins? 
As you scroll through the results and see the average attendance numbers decrease
you would expect to see percent_wins also decrease if they were correlated, but that is
not the case so there doesn't appear to be a correlation between home game attendance
and number of wins */
SELECT CORR(homegames.attendance, w) AS corr_attend_w
FROM teams INNER JOIN homegames ON teamid = team AND yearid = year
WHERE homegames.attendance IS NOT NULL


/* Q12 - part 2 - Do teams that win the world series see a boost in attendance the following year?  */
--Q12--part2--Option1
SELECT 
	t.yearid,
	t.teamid,
	SUM(h.attendance) AS attendance_wswin_yr,
	SUM(h2.attendance) AS yr_after_attendance,
	SUM(h2.attendance) - SUM(h.attendance) AS attendance_diff
FROM teams AS t
JOIN homegames AS h
ON t.teamid=h.team AND t.yearid=h.year
JOIN homegames AS h2
ON t.teamid=h2.team and (t.yearid+1)=h2.year
WHERE wswin = 'Y'
GROUP BY t.yearid, t.teamid
ORDER BY yearid
--Q12--part2--Option2 with a summary approach
SELECT AVG(hg_2.attendance - hg_1.attendance) AS avg_attend_increase,
	   stddev_pop(hg_2.attendance - hg_1.attendance) AS stdev_attend_increase,
	   MAX(hg_2.attendance - hg_1.attendance) AS max_attend_increase,
	   MIN(hg_2.attendance - hg_1.attendance) AS min_attend_increase
FROM teams INNER JOIN homegames AS hg_1 ON teams.yearid = hg_1.year AND teams.teamid = hg_1.team
	 	   INNER JOIN homegames AS hg_2 ON teams.yearid + 1 = hg_2.year AND teams.teamid = hg_2.team
WHERE wswin = 'Y'
	  AND hg_1.attendance > 0
	  AND hg_2.attendance > 0;

/* Q12 - Part3 - What about teams that made the playoffs? 
Making the playoffs means either being a division winner or a wild card winner.  */
--Q12--Part3--Option1
SELECT 
	t.yearid,
	t.teamid,
	SUM(h.attendance) AS attendance_divwin_yr,
	SUM(h2.attendance) AS yr_after_attendance,
	SUM(h2.attendance) - SUM(h.attendance) AS attendance_diff
FROM teams AS t
JOIN homegames AS h
ON t.teamid=h.team AND t.yearid=h.year
JOIN homegames AS h2
ON t.teamid=h2.team and (t.yearid+1)=h2.year
WHERE DivWin = 'Y' OR WcWin = 'Y'
GROUP BY t.yearid, t.teamid
ORDER BY yearid
--Q12--part 3--Option2 with a summary approach
SELECT AVG(hg_2.attendance - hg_1.attendance) AS avg_attend_increase,
	   stddev_pop(hg_2.attendance - hg_1.attendance) AS stdev_attend_increase,
	   MAX(hg_2.attendance - hg_1.attendance) AS max_attend_increase,
	   MIN(hg_2.attendance - hg_1.attendance) AS min_attend_increase
FROM teams INNER JOIN homegames AS hg_1 ON teams.yearid = hg_1.year AND teams.teamid = hg_1.team
	 INNER JOIN homegames AS hg_2 ON teams.yearid + 1 = hg_2.year AND teams.teamid = hg_2.team
WHERE (divwin = 'Y' OR wcwin = 'Y')
	  AND hg_1.attendance > 0
	  AND hg_2.attendance > 0;


/* Q13 - It is thought that since left-handed pitchers are more rare, causing batters to face them 
less often, that they are more effective. Investigate this claim and present evidence to either 
support or dispute this claim. First, determine just how rare left-handed pitchers are compared 
with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? 
Are they more likely to make it into the hall of fame? */
WITH pitchers AS (SELECT *
				  FROM people INNER JOIN pitching USING(playerid)
				 	   INNER JOIN awardsplayers USING(playerid)
				 	   INNER JOIN halloffame USING(playerid))
SELECT (SELECT COUNT(DISTINCT playerid)::float
		FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float AS pct_left_pitch,
	   (SELECT COUNT(DISTINCT playerid)::float
		FROM pitchers WHERE awardid = 'Cy Young Award')/COUNT(DISTINCT playerid)::float AS pct_pitch_cy_young,
	   ((SELECT COUNT(DISTINCT playerid)::float
		 FROM pitchers WHERE awardid = 'Cy Young Award')/COUNT(DISTINCT playerid)::float) * ((SELECT COUNT(DISTINCT playerid)::float
																							  FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float) AS calc_pct_left_cy_young,
	   (SELECT COUNT(DISTINCT playerid)::float
		FROM pitchers WHERE awardid = 'Cy Young Award' AND throws = 'L')/COUNT(DISTINCT playerid)::float AS actual_pct_left_cy_young,
	   (SELECT COUNT(DISTINCT playerid)::float
		FROM pitchers WHERE inducted = 'Y')/COUNT(DISTINCT playerid)::float AS pct_hof,
	   ((SELECT COUNT(DISTINCT playerid)::float
		 FROM pitchers WHERE inducted = 'Y')/COUNT(DISTINCT playerid)::float) * ((SELECT COUNT(DISTINCT playerid)::float
																				  FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float) AS calc_pct_left_hof,
	   (SELECT COUNT(DISTINCT playerid)::float
		FROM pitchers WHERE inducted = 'Y' AND throws = 'L')/COUNT(DISTINCT playerid)::float AS actual_pct_left_hof
FROM pitchers;
