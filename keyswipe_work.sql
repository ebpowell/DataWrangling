-- door_controller.t_keyswipes definition

-- Drop table

-- DROP TABLE door_controller.t_keyswipes;

CREATE TABLE dataload.t_keyswipes_slop (
	record_id int8 NULL,
	fob_id int8 NULL,
	status text NULL,
	door int4 NULL,
	swipe_timestamp text NULL,
	door_controller_ip text NULL
);


CREATE TABLE dataload.access_list_from_controller_slop (
	record_id int4 NULL,
	fob_id int4 NULL,
	door_controller int4 NULL,
	status text NULL,
	door_id int4 NULL,
	controller_ip text NULL,
	data_date date NULL
);

insert into dataload.t_keyswipes_slop (record_id, fob_id, status, door, swipe_timestamp, door_controller_ip)
with max_recs as
(select max(swipe_timestamp ) as swipe, door_controller_ip
from door_controller.t_keyswipes tks 
group by door_controller_ip )
select tks.record_id, tks.fob_id, tks.status, tks.door, tks.swipe_timestamp, tks.door_controller_ip 
from door_controller.t_keyswipes tks 
inner join max_recs mr 
on mr.swipe = tks.swipe_timestamp;

select max(record_id), fob_id, status, door, swipe_timestamp, door_controller_ip from door_controller.t_keyswipes
                 group by door_controller_ip;
	record_id int8 NULL,

select distinct * from dataload.t_keyswipes_slop tks where fob_id::text like '8744%';


select count(*), fob_id, door, door_controller_ip, status from dataload.t_keyswipes_slop tks 
group by fob_id, door, door_controller_ip or_controller_ip , status


insert into door_controller.t_keyswipes (record_id, fob_id , status, swipe_timestamp, door,door_controller_ip)
select distinct record_id, fob_id, status, swipe_timestamp, door,door_controller_ip 
from dataload.t_keyswipes_slop tks 
where concat(record_id, '-',substr(door_controller_ip, 18,3)) 
not in (select distinct concat(record_id, '-',substr(door_controller_ip, 18,3)) from door_controller.t_keyswipes );

select distinct record_id, fob_id, status, swipe_timestamp, door,door_controller_ip 
from dataload.t_keyswipes_slop tks 
where concat(record_id, '-',substr(door_controller_ip, 18,3)) 
not in (select distinct concat(record_id, '-',substr(door_controller_ip, 18,3)) from door_controller.t_keyswipes );


select fob_id from 
key_fobs.owners o 
inner join key_fobs.keyfobs k 
on o.property_id = k.property_id
where last_name like'Chase%';

select concat(record_id, '-',substr(door_controller_ip, 18,3)) from dataload.t_keyswipes_slop;



select fob_id, p.property_id from 
key_fobs.properties p  
inner join key_fobs.keyfobs k 
on p.property_id = k.property_id
where address  like'330 Wi%';

-- Find potentially legitimate owners forbid access

with denials as
(
	select k.fob_id , door_desc , o.last_name, address  ,swipe_time  from door_controller.v_keyswipes vk 
	inner join key_fobs.keyfobs k 
	on k.fob_id =vk.fob_id
	inner join key_fobs.owners o 
	on o.property_id =k.property_id
	inner join key_fobs.properties p 
	on p.property_id = k.property_id 
	where status = 'Forbid'
	and EXTRACT(year FROM vk.swipe_time)=2025
	order by swipe_time desc
)
select count(swipe_time) as count, EXTRACT(month from swipe_time) as month, fob_id, door_desc, last_name, address from denials
group by fob_id, door_desc, last_name, address, EXTRACT(month from swipe_time)
order by count desc;

-- Find the unassigned keyfobs that have tried to swipe into our amenites
	select distinct vk.fob_id, status, door_controller, door_desc    from door_controller.v_keyswipes vk 
	full outer join key_fobs.keyfobs k 
	on k.fob_id =vk.fob_id
	where keyfob_id is null
	and EXTRACT(year FROM vk.swipe_time)>2023
	and status not like 'Remote%'
	order by vk.fob_id
;

select tk.fob_id, address, status, d.door_desc , first_name ,last_name, swipe_time
from door_controller.v_keyswipes tk
inner join key_fobs.keyfobs k 
on k.fob_id = tk.fob_id
inner join key_fobs.owners o on
k.property_id = o.property_id
inner join key_fobs.properties p 
on p.property_id = o.property_id
inner join door_controller.door d 
on d.door_no  = tk.door and d.controller = tk.door_controller
where d.door_desc like 'Clubhouse Door%'
order by swipe_time desc;

/*****************************************************************************/
/* Data Quality Metric Queries												*/ 
/***************************************************************************/
-- Metric 1: Count of Forbids to Pool / Tennis Courts by Week/Year
with forbids as
(
	select distinct fob_id, door_desc,  EXTRACT(week from vk.swipe_time) as week_value, EXTRACT(year from vk.swipe_time) as year_value
	from door_controller.v_keyswipes vk
	where vk.status = 'Forbid'
	and door_desc not like '%Club%'
	and EXTRACT(hour from vk.swipe_time)>6 and EXTRACT(hour from vk.swipe_time) <22
	order by year_value desc, week_value desc
)
select count(*), TO_DATE(year_value::text || week_value::text, 'IYYYIW'), year_value, week_value
--from door_controller.v_keyswipes vk
from forbids f
inner join key_fobs.keyfobs k on
k.fob_id = f.fob_id
where f.fob_id in (select fob_id from key_fobs.v_2025_homeowner_fob_list)
group by week_value, year_value
order by year_value desc, week_value desc;


-- Current week stats

WITH forbids AS (
    SELECT DISTINCT
        fob_id,
        door_desc,
        EXTRACT(week FROM vk.swipe_time) AS week_value,
        EXTRACT(year FROM vk.swipe_time) AS year_value
    FROM
        door_controller.v_keyswipes vk
    WHERE
        vk.status = 'Forbid'
        AND EXTRACT(hour FROM vk.swipe_time) > 6
        AND EXTRACT(hour FROM vk.swipe_time) < 22
        and vk.door_desc not like '%Club%'
),
current_forbids_summary AS (
    SELECT
        COALESCE(COUNT(*), 0) AS forbid_count,
        TO_DATE(year_value::text || LPAD(week_value::text, 2, '0'), 'IYYYIW') AS the_date
    FROM
        forbids f
    INNER JOIN
        key_fobs.keyfobs k ON k.fob_id = f.fob_id
    WHERE
        f.fob_id IN (SELECT fob_id FROM key_fobs.v_2025_homeowner_fob_list)
    GROUP BY
        week_value,
        year_value
),
this_week_calc AS (
    -- Calculate the current week's Monday date based on ISO week
    SELECT
        TO_DATE(EXTRACT(year FROM CURRENT_DATE)::text || LPAD(EXTRACT(week FROM CURRENT_DATE)::text, 2, '0'), 'IYYYIW') AS current_week_monday
)
SELECT
    COALESCE(cfs.forbid_count, 0) AS final_forbid_count
FROM
    this_week_calc twc
LEFT JOIN
    current_forbids_summary cfs ON twc.current_week_monday = cfs.the_date;


--Metric 2: Unassigned Keyfobs with access to Amenites

with allows as
(
	select distinct fob_id, door_desc,  EXTRACT(week from vk.swipe_time) as week_value, EXTRACT(year from vk.swipe_time) as year_value
	from door_controller.v_keyswipes vk
	where vk.status = 'Allow'
	and door_desc not like '%Club%'
	and EXTRACT(hour from vk.swipe_time)>6 and EXTRACT(hour from vk.swipe_time) <22
	order by year_value desc, week_value desc
)
select count(*), TO_DATE(year_value::text || week_value::text, 'IYYYIW'), year_value, week_value
--from door_controller.v_keyswipes vk
from allows a
inner join key_fobs.keyfobs k on
k.fob_id = a.fob_id
where a.fob_id not in (select fob_id from key_fobs.v_2025_homeowner_fob_list)
group by week_value, year_value
order by year_value desc, week_value desc;


-- Current week stats

WITH allows AS (
    SELECT DISTINCT
        fob_id,
        door_desc,
        EXTRACT(week FROM vk.swipe_time) AS week_value,
        EXTRACT(year FROM vk.swipe_time) AS year_value
    FROM
        door_controller.v_keyswipes vk
    WHERE
        vk.status = 'Allow'
        AND EXTRACT(hour FROM vk.swipe_time) > 6
        AND EXTRACT(hour FROM vk.swipe_time) < 22
        and vk.door_desc not like '%Club%'
),
current_allows_summary AS (
    SELECT
        COALESCE(COUNT(*), 0) AS allow_count,
        TO_DATE(year_value::text || LPAD(week_value::text, 2, '0'), 'IYYYIW') AS the_date
    FROM
        allows a
    INNER JOIN
        key_fobs.keyfobs k ON k.fob_id = a.fob_id
    WHERE
        a.fob_id not IN (SELECT fob_id FROM key_fobs.v_2025_homeowner_fob_list)
    GROUP BY
        week_value,
        year_value
),
this_week_calc AS (
    -- Calculate the current week's Monday date based on ISO week
    SELECT
        TO_DATE(EXTRACT(year FROM CURRENT_DATE)::text || LPAD(EXTRACT(week FROM CURRENT_DATE)::text, 2, '0'), 'IYYYIW') AS current_week_monday
)
SELECT
    COALESCE(cfs.allow_count, 0) AS final_allow_count
FROM
    this_week_calc twc
LEFT JOIN
    current_allows_summary cfs ON twc.current_week_monday = cfs.the_date;


-- Metric 3: # of Fobs on Controller 1 not present on COntroller 2
with fob_controller_list as
(
select distinct fob_id, door_controller from door_controller.access_list_from_controller alfc 
order by fob_id, door_controller 
),
controller_1 as 
(select * from fob_controller_list where door_controller = 1),
controller_2 as 
(select * from fob_controller_list where door_controller = 2)
select count(*) from 
controller_1 c1
full outer join
controller_2 c2
on c1.fob_id = c2.fob_id
where c2.fob_id is null;

-- Metric 4: # Fobs on Controller 2 not present on Controller 1
with fob_controller_list as
(
select distinct fob_id, door_controller from door_controller.access_list_from_controller alfc 
order by fob_id, door_controller 
),
controller_1 as 
(select * from fob_controller_list where door_controller = 1),
controller_2 as 
(select * from fob_controller_list where door_controller = 2)
select count(*) from 
controller_2 c2
full outer join
controller_1 c1
on c1.fob_id = c2.fob_id
where c1.fob_id is null;

-- Metric 5: # Fobs in Keyfob list not on COntroller 1
with control_list as
(
	select distinct fob_id from door_controller.access_list_from_controller alfc
	where alfc.door_controller = 1
)
select count(*) 
from  control_list cl
full outer join key_fobs.keyfobs k 
on k.fob_id = cl.fob_id
where cl.fob_id is null;



-- Metric 6: # Fobs in Keyfob list not on COntroller 2
with control_list as
(
	select distinct fob_id from door_controller.access_list_from_controller alfc 
	where alfc.door_controller = 2
)
select count(*) 
from  control_list cl
full outer join key_fobs.keyfobs k 
on k.fob_id = cl.fob_id
where cl.fob_id is null;


-- Metric 7: Count of Fobs on DC1 not in assigned list
with control_list as
(
	select distinct fob_id from door_controller.access_list_from_controller alfc
	where alfc.door_controller = 1
)
select count(*) 
from  control_list cl
full outer join key_fobs.keyfobs k 
on k.fob_id = cl.fob_id
where k.fob_id is null;

-- Metric 7: Count of Fobs on DC2 not in assigned list
with control_list as
(
	select distinct fob_id from door_controller.access_list_from_controller alfc
	where alfc.door_controller = 2
)
select count(*) 
from  control_list cl
full outer join key_fobs.keyfobs k 
on k.fob_id = cl.fob_id
where k.fob_id is null;



select distinct address, last_name  from key_fobs.properties p
inner join key_fobs.keyfobs kf
on p.property_id =kf.property_id
inner join key_fobs.owners o 
on o.property_id = p.property_id
inner join door_controller.v_keyswipes ks on 
ks.fob_id =kf.fob_id
where extract(year from ks.swipe_time) = 2025 and extract(month from ks.swipe_time) = 6 
and extract(day from ks.swipe_time ) = 8 and extract(hour from ks.swipe_time ) > 15
and extract(hour from swipe_time) < 20;


select max(record_id) 
            from dataload.fobs_slop
            where controller_ip = '69.21.119.147/32'::cidr

update dataload.fobs_slop fs2 set record_time = '2025-06-15 18:01:10.360 -0400';    

insert into door_controller.fobs (record_id, fob_id, record_time, controller_id)
select distinct record_id, fob_id, record_time, controller
from dataload.v_fob_slop_append vfsa ;

