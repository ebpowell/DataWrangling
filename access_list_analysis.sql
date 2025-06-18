select count(*), status from access_control ac 
where door like '%4%'
group by status;

select * from access_control ac 
where door like '%4%' and status ='Forbid'
group by status;

--Deterine access list by door controller
drop view v_fobcount_comparison;
create or replace view v_fobcount_comparison as
with fob_List as
(
	select distinct fob_id, controller_id
	from door_controller.fobs
	order by fob_id
)
select count(fob_id), controller_id
from fob_list
group by controller_id;

-- Which of the fobs are in the official list compared to what is on the controllers
drop view v_system_assigned_fob_compare cascade;
create or replace view v_system_assigned_fob_compare as
with system_fob_List as
(
	select distinct fob_id, controller_id 
	from door_controller.fobs
	order by fob_id
)
select k.fob_id as assigned_fob_id, fsl.fob_id as sysem_fob_id, controller_id from 
key_fobs.keyfobs k 
full outer join system_fob_list fsl
on k.fob_id = fsl.fob_id
order by k.fob_id;

--Find the assigned fobs missing from both controllers
create or replace view v_system_missing_assigned_fobs as
select * from v_system_assigned_fob_compare 
where sysem_fob_id is null
and assigned_fob_id > 0;

--Unassigned FOb_ids needing removal
drop view v_fob_ids_to_remove cascade;
create or replace view v_fob_ids_to_remove as
with controllers as
(
	select distinct controller, controller_ip from door_controller.door
)
select distinct sysem_fob_id, controller_id, d.controller_ip from 
v_system_assigned_fob_compare vsafc
inner join controllers d
on d.controller = vsafc.controller_id
where assigned_fob_id is null
order by controller_id asc;


-- Check integrity of polled results
select count(*), fob_id from door_controller.fobs f 
group by fob_id;


--Support view: Find the fob_ids present on only one door controller
create or replace view v_error_fobid_on_single_controller as
with controller_count as 
(
	select count(controller_id) as controller_count, sysem_fob_id
	from v_system_assigned_fob_compare
	group by sysem_fob_id
)
select sysem_fob_id
from controller_count
where controller_count = 1;


-- Determine the door controller the fob_ids in v_error_fobid_on_single_controller as associated with
drop view v_error_detail_fobid_single_controller;
create or replace view v_error_detail_fobid_single_controller as
select distinct sysem_fob_id, controller_ip
from v_error_fobid_on_single_controller sc 
left join door_controller.fobs ac
on sc.sysem_fob_id = ac.fob_id
left join door_controller.door d
on d.controller = ac.controller_id
order by sc.sysem_fob_id asc;

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

/*--- Associate the list of Fobs on a single controller with the controller they are present on
create view v_error_detail_fobid_single_controller_to_remove as
select vedfsc.* from 
v_error_detail_fobid_single_controller vedfsc 
full outer join v_fob_ids_to_remove vfitr
on vedfsc.sysem_fob_id = vfitr.sysem_fob_id
where vfitr.sysem_fob_id is null;
*/

--Identify assigned fobs that are missing by controller



/* Trend Queries */
-- Identify number of fobs added / removed from each controller over that past 7 days


--