--Keyfob / Swipe analysis
drop view door_controller.v_keyswipes cascade;
create or replace view door_controller.v_keyswipes as
select record_id, 
fob_id, 
status, 
cast(door as integer),
door_desc,
to_timestamp(swipe_timestamp, 'YYYY-MM-DD HH24:MI:SS') as swipe_time, 
controller as door_controller,
controller_ip
from door_controller.t_keyswipes tks
inner join door_controller.door d
on d.controller_ip = ltrim(tks.door_controller_ip, 'http://')::cidr
and d.door_no = door;

-- Pool usage data, by day
create or replace view door_controller.v_pool_daily_usage as
SELECT
    DATE(tks.swipe_time) AS record_date,
    COUNT(*) AS record_count
FROM
    door_controller.v_keyswipes tks
  where door_desc like 'Pool%'
GROUP BY
    record_date
ORDER BY
    record_date;


-- ***Pool uage data, by day and hour when the pool is open
-- Day of the week
select count(*), day 
from door_controller.v_keyswipes vks
inner join public.dayofweek dow
on dow.day_no = extract('dow' from swipe_time)
where door_desc like 'Pool%'
  group by extract('dow' from swipe_time), dow.day;

-- By hour
select extract('hour' from swipe_time), count(*) from door_controller.v_keyswipes
where door_desc like 'Pool%'
  group by extract('hour' from swipe_time);

--By hour and DOW
select extract('hour' from swipe_time) as hour, extract('dow' from swipe_time) as day, count(*) from door_controller.v_keyswipes
where door_desc like 'Pool%'
  group by extract('hour' from swipe_time), extract('dow' from swipe_time);


-- Tennis Court usage data, by day
create or replace view door_controller.v_tenniscourt_daily_usage as
SELECT
    DATE(tks.swipe_time) AS record_date,
    COUNT(*) AS record_count
FROM
    door_controller.v_keyswipes tks
  where door_desc like 'Tennis%'
GROUP BY
    record_date
ORDER BY
    record_date;
-- ***Tennis Court uage data, by day and hour when the pool is open
-- Day of the week
select extract('dow' from swipe_time), count(*) from door_controller.v_keyswipes
where where door_desc like 'Tennis%'
  group by extract('dow' from swipe_time);

-- By hour
select extract('hour' from swipe_time), count(*) from door_controller.v_keyswipes
where where door_desc like 'Tennis%'
  group by extract('hour' from swipe_time);

--By hour and DOW
select extract('hour' from swipe_time) as hour, day_of_week, count(*) from door_controller.v_keyswipes
inner join door_controller.days_of_week on
dow_id =extract('dow' from swipe_time)
where where door_desc like 'Tennis%'
  group by extract('hour' from swipe_time), day_of_week;
	 
select count(*), fob_id from door_controller.v_keyswipes vk
where where door_desc like 'Tennis%'
group by fob_id;


-- compare system fobs to 2025 regenerated list
create or replace view key_fobs.v_mismatch_fobids as
with assigned_fobs as
(
select last_nam, fob_1 as fob 
from key_fobs.vw_keyfos_2025_export vke 
union
select last_nam, fob_2 as fob 
from key_fobs.vw_keyfos_2025_export vke 
)
select sfi.fob_id, fob, last_nam
from door_controller.system_fob_ids sfi 
full outer join assigned_fobs af
on af.fob = sfi.fob_id::text
where fob is null or fob_id is null;


create or replace view key_fobs.v_add_to_system
as
select * from key_fobs.v_mismatch_fobids
where fob_id is null;

create or replace view key_fobs.v_forbid_all_on_system
as
select * from key_fobs.v_mismatch_fobids
where fob is null;


-- Get the list of all fobs ever swiped
select distinct fob_id from door_controller.v_keyswipes vk ;

-- Generate the list of fobs that have been swiped but don't have a name assigned
with used_fobs as 
(
	select distinct fob_id from door_controller.v_keyswipes vk
),
known_fobs as 
(
	select last_nam, fob_1 as fob 
	from key_fobs.vw_keyfos_2025_export vke 
	union
	select last_nam, fob_2 as fob 
	from key_fobs.vw_keyfos_2025_export vke 
)
select * from used_fobs 
full outer join known_fobs 
on used_fobs.fob_id::text = known_fobs.fob
where last_nam  is null;

-- Compare above to the list of fobs authorized on the system
with the_data as
	(
	with phantoms as 
	(
		with used_fobs as 
		(
			select distinct fob_id from door_controller.v_keyswipes vk
		),
		known_fobs as 
		(
			select last_nam, fob_1 as fob 
			from key_fobs.vw_keyfos_2025_export vke 
			union
			select last_nam, fob_2 as fob 
			from key_fobs.vw_keyfos_2025_export vke 
		)
		select * from used_fobs 
		full outer join known_fobs 
		on used_fobs.fob_id::text = known_fobs.fob
		where last_nam  is null
	)
	select phantoms.fob_id from phantoms
	full outer join door_controller.system_fob_ids sfi
	on phantoms.fob_id = sfi.fob_id
	where rec_id is null
	)
	select ks.* from 
	door_controller.v_keyswipes ks
	inner join the_data
	on the_data.fob_id =ks.fob_id;


-- Count Tennis Court usage by family
drop view door_controller.v_tennis_annual_family_usgae;
create or replace view door_controller.v_tennis_annual_family_usage as
with family_usage as 
(
	with tennis_swipes as 
	(
		select count(*) swipe_count, last_name, address, extract('year' from swipe_time) as year  from 
		door_controller.v_keyswipes vk 
		inner join key_fobs.v_2025_fob_list vfl on vk.fob_id = vfl.fob_id 
		where vk.door_desc like 'Tennis%'
		group by last_name, extract('year' from swipe_time), address
		order by year desc
	)
	select * from tennis_swipes where swipe_count > 10
)
select count(*), year from family_usage
group by year;

--Pool Usage by family
drop view door_controller.v_pool_annual_family_usage;
create or replace view door_controller.v_pool_annual_family_usage as
with family_usage as 
(
	with pool_swipes as 
	(
		select count(*) swipe_count, last_name, address, extract('year' from swipe_time) as year  from 
		door_controller.v_keyswipes vk 
		inner join key_fobs.v_2025_fob_list vfl on vk.fob_id = vfl.fob_id 
		where vk.door_desc like 'Pool%'
		group by last_name, extract('year' from swipe_time), address
		order by year desc
	)
	select * from pool_swipes where swipe_count > 10
)
select count(*), year from family_usage
group by year;
--

-- Isolate a "visit" from the Fob data
-- Bin visits by date for the pool, count famileis per day
drop view door_controller.v_pool_familes_day ;
create or replace view door_controller.v_pool_familes_day as
with raw_data as
(
	select distinct date(swipe_time), fob_id from
	door_controller.v_keyswipes vks
	inner join door_controller.door d 
	on d.door_no = vks.door and d.controller = vks.door_controller
	where d.door_desc like 'Pool%'
)
select count(fob_id) as families, date from raw_data
 group by date
 order by date desc;


-- Isolate a "visit" from the Fob data
-- Bin visits by date for the pool, count famileis per day
drop view door_controller.v_tennis_familes_day ;
create or replace view door_controller.v_tennis_familes_day as
with raw_data as
(
	select distinct date(swipe_time), fob_id from
	door_controller.v_keyswipes vks
	inner join door_controller.door d 
	on d.door_no = vks.door and d.controller = vks.door_controller
	where d.door_desc like 'Tennis%'
)
select count(fob_id) as families, date from raw_data
 group by date
 order by date desc;

-- Count Pool Court usage by family
drop view door_controller.v_pool_annual_family_usage;
create or replace view door_controller.v_pool_annual_family_usage as
with family_usage as 
(
	with court_swipes as 
	(
		with known_fobs as 
				(
					select last_nam, address, fob_1 as fob 
					from key_fobs.keyfos_2025 vke 
					where vke.address not like '429 Gwin%'
					union
					select last_nam, address, fob_2 as fob 
					from key_fobs.keyfos_2025 vke 
					where vke.address not like '429 Gwin%'
				)
		select count(*) swipe_count, last_nam, address, extract('year' from swipe_time) as year  from 
		door_controller.v_keyswipes vk 
		inner join known_fobs on vk.fob_id::text = fob
		inner join door_controller.door d 
		on d.door_no = vk.door
		and d.controller = vk.door_controller
		where d.door_desc like 'Pool%'
		group by last_nam , extract('year' from swipe_time), address
		order by year desc
	)
	select * from court_swipes
	order by year desc, swipe_count asc
)
select count(*), year from family_usage
group by year;



-- Breakdown percent usage by family per year
--create or replace view door_controller.v_pool_annual_family_usage as
create or replace view door_controller.v_tennis_usage_sats as
with family_year as(
	with family_usage as 
	(
		with court_swipes as 
		(
			with known_fobs as 
					(
						select last_nam, address, fob_1 as fob 
						from key_fobs.vw_keyfos_2025_export vke 
						union
						select last_nam, address, fob_2 as fob 
						from key_fobs.vw_keyfos_2025_export vke 
					)
			select count(*) swipe_count, last_nam, address, extract('year' from swipe_time) as year  from 
			door_controller.v_keyswipes vk 
			inner join known_fobs on vk.fob_id::text = fob
			inner join door_controller.door d 
			on d.door_no = vk.door
			and d.controller = vk.door_controller
			where d.door_desc like 'Tennis%'
			group by last_nam , extract('year' from swipe_time), address
			order by year desc
		)
		select * from court_swipes
		order by year desc, swipe_count asc
	)
	select address, swipe_count, year from family_usage
	group by year, swipe_count, address
), annual_swipes as
(
	select count(*) annual_swipe_count, extract(year from swipe_time) as year
	from door_controller.v_keyswipes vks
	inner join door_controller.door d
	on vks.door_controller = d.controller and vks.door = d.door_no
	where d.door_desc like 'Tennis%'
	group by year
)
select round((swipe_count::numeric/annual_swipe_count::numeric)::numeric*100, 1) as percent_swipes, fy.year, address
from annual_swipes a inner join family_year fy on a.year = fy.year
;

--Sasme for the Pool
create or replace view door_controller.v_pool_usage_sats as
with family_year as(
	with family_usage as 
	(
		with court_swipes as 
		(
			--with known_fobs as 
			--		(
			--			select last_nam, address, fob_1 as fob 
			--			from key_fobs.vw_keyfos_2025_export vke 
			--			union
			--			select last_nam, address, fob_2 as fob 
			--			from key_fobs.vw_keyfos_2025_export vke 
			--		)
			select count(*) swipe_count, last_name, address, extract('year' from swipe_time) as year  from 
			door_controller.v_keyswipes vk 
			inner join key_fobs.v_2025_fob_list vfl on vk.fob_id = vfl.fob_id
			inner join door_controller.door d 
			on d.door_no = vk.door
			and d.controller = vk.door_controller
			where d.door_desc like 'Pool%'
			group by last_name, extract('year' from swipe_time), address
			order by year desc
		)
		select * from court_swipes
		order by year desc, swipe_count asc
	)
	select address, swipe_count, year from family_usage
	group by year, swipe_count, address
), annual_swipes as
(
	select count(*) annual_swipe_count, extract(year from swipe_time) as year
	from door_controller.v_keyswipes vks
	inner join door_controller.door d
	on vks.door_controller = d.controller and vks.door = d.door_no
	where d.door_desc like 'Pool%'
	group by year
)
select round((swipe_count::numeric/annual_swipe_count::numeric)::numeric*100, 1) as percent_swipes, fy.year, address
from annual_swipes a inner join family_year fy on a.year = fy.year


--with the above views, amalgamate < 1% to other, 2021
select sum(percent_swipes) as swipe_percent, 'Other'  as prop_address
from door_controller.v_tennis_usage_sats vtus 
where percent_swipes <+ 2 and year = 2021
union
select percent_swipes, address as prop_address from door_controller.v_tennis_usage_sats vtus 
where percent_swipes > 2 and year = 2021;

--with the above views, amalgamate < 1% to other, 2022
select sum(percent_swipes) as swipe_percent, 'Other'  as prop_address
from door_controller.v_tennis_usage_sats vtus 
where percent_swipes <+ 2 and year = 2022
union
select percent_swipes, address as prop_address from door_controller.v_tennis_usage_sats vtus 
where percent_swipes > 2 and year = 2022;

--with the above views, amalgamate < 1% to other, 2023
select sum(percent_swipes) as swipe_percent, 'Other'  as prop_address
from door_controller.v_tennis_usage_sats vtus 
where percent_swipes <+ 2 and year = 2023
union
select percent_swipes, address as prop_address from door_controller.v_tennis_usage_sats vtus 
where percent_swipes > 2 and year = 2023;


--with the above views, amalgamate < 1% to other, 2024
select sum(percent_swipes) as swipe_percent, 'Other'  as prop_address
from door_controller.v_tennis_usage_sats vtus 
where percent_swipes <+ 2 and year = 2024
union
select percent_swipes, address as prop_address from door_controller.v_tennis_usage_sats vtus 
where percent_swipes > 2 and year = 2024;


--with the above views, amalgamate < 1% to other, 2025
select sum(percent_swipes) as swipe_percent, 'Other'  as prop_address
from door_controller.v_tennis_usage_sats vtus 
where percent_swipes <+ 2 and year = 2025
union
select percent_swipes, address as prop_address from door_controller.v_tennis_usage_sats vtus 
where percent_swipes > 2 and year = 2025;


-- Breakdown tennis court percent usage by address 
create or replace view door_controller.v_tannis_court_usage as
with usage_data as 
(
	with family_year as(
		with family_usage as 
		(
			with court_swipes as 
			(
				select count(*) swipe_count, address from 
				door_controller.v_keyswipes vk 
				inner join key_fobs.v_2025_fob_list vfl on vk.fob_id = vfl.fob_id
				inner join door_controller.door d 
				on d.door_no = vk.door
				and d.controller = vk.door_controller
				where d.door_desc like 'Tennis%'
				group by last_name, address
			)
			select * from court_swipes
			order by swipe_count asc
		)
		select address, swipe_count from family_usage
		group by swipe_count, address
	), total_swipes as
	(
		select count(*) tot_swipe_count
		from door_controller.v_keyswipes vks
		inner join door_controller.door d
		on vks.door_controller = d.controller and vks.door = d.door_no
		inner join key_fobs.v_2025_fob_list vfl on vks.fob_id = vfl.fob_id
		where d.door_desc like 'Tennis%'
	)
	select round((swipe_count::numeric/tot_swipe_count::numeric)::numeric*100, 1) as percent_swipes, address
	from total_swipes a, family_year fy 
)
select sum(percent_swipes) as swipe_percent, 'Other' as prop_address
from usage_data 
where percent_swipes <= 2
union
select percent_swipes, address as prop_address 
from usage_data  
where percent_swipes > 2
;

-- Breakdown pool percent usage by address 
create or replace view door_controller.v_pool_usage as
with usage_data as 
(
	with family_year as(
		with family_usage as 
		(
			with court_swipes as 
			(
				select count(*) swipe_count, address from 
				door_controller.v_keyswipes vk 
				inner join key_fobs.v_2025_fob_list vfl on vk.fob_id = vfl.fob_id
				inner join door_controller.door d 
				on d.door_no = vk.door
				and d.controller = vk.door_controller
				where d.door_desc like 'Pool%'
				group by last_name, address
			)
			select * from court_swipes
			order by swipe_count asc
		)
		select address, swipe_count from family_usage
		group by swipe_count, address
	), total_swipes as
	(
		select count(*) tot_swipe_count
		from door_controller.v_keyswipes vks
		inner join door_controller.door d
		on vks.door_controller = d.controller and vks.door = d.door_no
		inner join key_fobs.v_2025_fob_list vfl on vks.fob_id = vfl.fob_id
		where d.door_desc like 'Pool%'
	)
	select round((swipe_count::numeric/tot_swipe_count::numeric)::numeric*100, 1) as percent_swipes, address
	from total_swipes a, family_year fy 
)
select sum(percent_swipes) as swipe_percent, 'Other' as prop_address
from usage_data 
where percent_swipes <= 2
union
select percent_swipes, address as prop_address from usage_data  
where percent_swipes > 2
;


/* Access Control List
 */
-- Clubhouse23
create or replace view door_controller.v_clubhouse_access as
with known_fobs as 
						(
							select last_nam, address, fob_1  fob 
							from key_fobs.keyfos_2025 vke 
							union
							select last_nam, address, fob_2 fob 
							from key_fobs.keyfos_2025 vke 
						)
select distinct fob_id, last_nam, address, status, door_desc  
from door_controller.access_list_from_controller alfc 
inner join door_controller.door d 
on alfc.door_id = d.door_no and alfc.door_controller =d.controller
inner join known_fobs kf 
on kf.fob = alfc.fob_id::text
where status = 'Allow'
and d.door_desc like 'Club%'
order by last_nam asc;

--Tennis Court
create or replace view door_controller.v_tennis_access as
with known_fobs as 
						(
							select last_nam, address, fob_1  fob 
							from key_fobs.keyfos_2025 vke 
							union
							select last_nam, address, fob_2 fob 
							from key_fobs.keyfos_2025 vke 
						)
select distinct fob_id, last_nam, address, status, door_desc  
from door_controller.access_list_from_controller alfc 
inner join door_controller.door d 
on alfc.door_id = d.door_no and alfc.door_controller =d.controller
inner join known_fobs kf 
on kf.fob = alfc.fob_id::text
where status = 'Allow'
and d.door_desc like 'Tennis%'
order by last_nam asc;


-- Pool
create or replace view door_controller.v_pool_access as
with known_fobs as 
						(
							select last_nam, address, fob_1  fob 
							from key_fobs.keyfos_2025 vke 
							union
							select last_nam, address, fob_2 fob 
							from key_fobs.keyfos_2025 vke
						)
select distinct fob_id, last_nam, address, status, door_desc  
from door_controller.access_list_from_controller alfc 
inner join door_controller.door d 
on alfc.door_id = d.door_no and alfc.door_controller =d.controller
inner join known_fobs kf 
on kf.fob = alfc.fob_id::text
where status = 'Allow'
and d.door_desc like 'Pool%'
order by last_nam asc;


--delete from door_controller.access_list_from_controller;

-- Determine average attendance to Pool events
drop view public.v_pool_event_attendance;
create or replace view public.v_pool_event_attendance as
with family_date as 
(
	select distinct date(swipe_time) as event_date, fob_id, pe.event from door_controller.v_keyswipes vk 
	inner join public.pool_events pe 
	on date(swipe_time) = pe.event_date
	group by date(vk.swipe_time), fob_id, event
)
select count(fob_id) families, event_date, event from family_date
group by event_date, event
order by event_date asc;

-- get the avaerage
create or replace view public.v_average_event_attendance as
select avg(families) average_num_families, event  from 
public.v_pool_event_attendance
group by event;

--When did converall visit
create or replace view door_controller.v_coverall_visits as
select distinct(swipe_time) from door_controller.v_keyswipes ks 
inner join key_fobs.keyfos_2025 k 
on k.fob_1::bigint = ks.fob_id::bigint or k.fob_2::bigint = ks.fob_id::bigint
where k.last_nam like '%Cover%'
order by swipe_time desc;

-- Remove duplicates from door_controller.t_keyswipes
DELETE FROM door_controller.t_keyswipes
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT
            ctid, -- Use the system column ctid to uniquely identify physical rows
            -- Assign a row number within each group of duplicates
            -- Duplicates are defined by having the same values in the PARTITION BY columns
            ROW_NUMBER() OVER (
                PARTITION BY
                    fob_id,
                    status,
                    door,
                    swipe_timestamp,
                    door_controller_ip
                ORDER BY
                    ctid ASC -- Keep the row with the 'first' physical location (lowest ctid)
            ) as rn
        FROM
            door_controller.t_keyswipes
    ) t
    WHERE t.rn > 1 -- Select rows that are duplicates (i.e., not the first one in their group based on ctid)
);



