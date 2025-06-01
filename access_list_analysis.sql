select count(*), status from access_control ac 
where door like '%4%'
group by status;

select * from access_control ac 
where door like '%4%' and status ='Forbid'
group by status;

--Deterine access list by door controller
create view v_fobcount_comparison as
with fob_List as
(
	select distinct fob_id, controller 
	from access_control
	order by fob_id
)
select count(fob_id), controller
from fob_list
group by controller;

-- Which of the fobs are in the official list compared to what is on the controllers
create view v_system_assigned_fob_compare as
with system_fob_List as
(
	select distinct fob_id, controller 
	from access_control
	order by fob_id
)
select k.fob_id as assigned_fob_id, fsl.fob_id as sysem_fob_id, controller from 
keyfobs k 
full outer join system_fob_list fsl
on k.fob_id = fsl.fob_id
order by k.fob_id;

--Find the fobs missing from both controllers
create view v_system_missing_fobs as
select * from v_system_assigned_fob_compare 
where sysem_fob_id is null
and assigned_fob_id > 0;

--FOb_ids needing removal
create view v_fob_ids_to_remove as 
select sysem_fob_id, controller from 
v_system_assigned_fob_compare vsafc 
where assigned_fob_id is null;

-- Check integrity of polled results
select count(*), fob_id from access_control
group by fob_id;

--Fibd the fob_ids present on only one Door controller
create view v_error_fobid_on_single_controller as
with controller_count as 
(
	select count(controller) as controller_count, sysem_fob_id
	from v_system_assigned_fob_compare
	group by sysem_fob_id
)
select sysem_fob_id
from controller_count
where controller_count = 1;


-- Determine the door controller the fob_ids in v_error_fobid_on_single_controller as associated with
create view v_error_detail_fobid_single_controller as
select distinct sysem_fob_id, controller
from v_error_fobid_on_single_controller sc 
left join access_control ac
where sc.sysem_fob_id = ac.fob_id
order by sc.sysem_fob_id asc;


--- Associate the list of Fobs on a single controller with the controller they are present on
create view v_error_detail_fobid_single_controller_with_present_controller_ip as
select vedfsc.* from 
v_error_detail_fobid_single_controller vedfsc 
full outer join v_fob_ids_to_remove vfitr
on vedfsc.sysem_fob_id = vfitr.sysem_fob_id
where vfitr.sysem_fob_id is null;
