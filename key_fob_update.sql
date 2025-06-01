drop view vw_sales_data ;
create view vw_sales_data as
select replace(lower(address), 'ct','court') as address, owner from sales where substr(trim(address), -2, 2) = 'CT'
union
select replace(lower(address), 'rd','road') as address, owner from sales where substr(trim(address), -2, 2) = 'RD'
union
select replace(lower(address), 'dr','drive') as address, owner from sales where substr(trim(address), -2, 2) = 'DR';

drop view vw_fobs;
create view vw_fobs as 
select lower(address) as address, last_name, first_name, fob_1, fob_2, fob_1a, fob_2a, rowid
from keyfob_assignment_2021 ka ;

drop view vw_keysfobs_2025;
create view vw_keysfobs_2025 as
select ka.address, vps.last_nam , vps.first_name , vf.fob_1 , vf.fob_1a, vf.fob_2, vf.fob_2a FROM 
vw_fobs vf
inner join keyfob_assignment_2021 ka 
on ka.rowid = vf.rowid
inner join vw_parsed_sales vps
on trim(vf.address) = trim(vps.address)
where vf.last_name != vps.last_nam
union
select ka.address, ka.last_name, ka.first_name, ka.fob_1, ka.fob_1a, ka.fob_2, ka.fob_2a
from keyfob_assignment_2021 ka
inner join vw_fobs vf on vf.rowid = ka.rowid
where trim(vf.address) not in (select trim(address) from vw_parsed_sales vps ); 


--Find the first spacec in the owner name column in the sales table and convert to Intial Cap for Last Name
select substr(owner,1,1)||lower(substr(owner,2, instr(owner, ' ')-1)) as last_name from vw_sales_data vf;

--Find first and last name from the sales data
create view vw_parsed_sales as
select address, 
substr(owner, instr(owner, ' ')+1,1)||lower(substr(owner, instr(owner, ' ')+2)) as first_name, 
substr(owner,1,1)||lower(substr(owner,2, instr(owner, ' ')-1)) as last_nam from 
vw_sales_data vf;

create view vw_keyfos_2025_export as
select address, last_nam, first_name,
	case
		when vk.fob_1 = vk.fob_1a then 
			vk.fob_1
		else 
			vk.fob_1a
		end fob_1,
	case
		when vk.fob_2 = vk.fob_2a then 
			vk.fob_2
		else 
			vk.fob_2a
		end fob_2	
from vw_keysfobs_2025 vk ;

-- Verification - compare generated list to list uo0dated based on sales since 2021
select wd.bill_to_2 ,wd.first_name, wd.last_name, vke.first_name , vke.last_nam from vw_keyfos_2025_export vke
inner join WW_Directory wd 
on lower(vke.address )=lower(bill_to_2) 
where trim(vke.last_nam) != trim(wd.last_name);


-- Determine fobs in the system not in output list1
/*with cti as 
(select fob_1 as fob_id from vw_keyfos_2025_export vke
union
select fob_2 as fob_id from vw_keyfos_2025_export vke)
select sfi.fob_id, cti.fob_id from system_fob_ids sfi 
full outer join cti
on sfi.fob_id = cti.fob_id
where cti.fob_id is null; */


create or replace view key_fobs.v_system_fobids_to_remove as
with system_fobs as(
select distinct fob_id from door_controller.access_list_from_controller)
select sf.fob_id 
from key_fobs.keyfobs k 
full outer join system_fobs sf
on sf.fob_id = k.fob_id
where k.fob_id is null;

-- 2025 Fob Assignemnts - homeowners

create or replace view key_fobs.v_2025_fob_list as
select distinct g."name" group_name, o.last_name, p.address, k.fob_id
from key_fobs."groups" g inner join
key_fobs.group_permissions gp 
on g.group_id = gp.group_id
inner join key_fobs.property_group_permissions pgp 
on g.group_id =pgp.group_id
inner join key_fobs.properties p 
on p.property_id = pgp.property_id
inner join key_fobs.owners o 
on o.property_id =p.property_id
inner join key_fobs.keyfobs k 
on p.property_id =k.property_id
where gp.allow = true
and g.group_id =7
and p.address not like '%429 Gwin%'
order by address, last_name; 



-- Coverall Swipes
with swipes as 
(
	select vk.last_nam, vk.first_name, ss.timestamp, ss.door 
	from vw_keysfobs_2025 vk
	inner join system_swipes ss
	on vk.fob_1 = ss.fob_id 
	--where ss.status = 'Allow'
	union
	select vk.last_nam, vk.first_name, ss.timestamp, ss.door 
	from vw_keysfobs_2025 vk
	inner join system_swipes ss
	on vk.fob_2 = ss.fob_id 
	--where ss.status = 'Allow'
)
select * from swipes 
--where last_nam = 'Coverall Cleaners'
order by timestamp asc;


--permissions summary view
create or replace view key_fobs.v_group_permissions as
select g.name, d.door_desc, gp.start_date, gp.end_date, gp.start_time, gp.end_time
from key_fobs.groups g inner join 
key_fobs.group_permissions gp 
on g.group_id = gp.group_id 
inner join door_controller.door d
on d.door_id = gp.door_id
where gp.allow = true;

--Non owner summary view
create or replace view key_fobs.v_special_access_fobs as
select distinct g."name" group_name, o.last_name, k.fob_id
from key_fobs."groups" g inner join
key_fobs.group_permissions gp 
on g.group_id = gp.group_id
inner join key_fobs.property_group_permissions pgp 
on g.group_id =pgp.group_id
inner join key_fobs.properties p 
on p.property_id = pgp.property_id
inner join key_fobs.owners o 
on o.property_id =p.property_id
inner join key_fobs.keyfobs k 
on p.property_id =k.property_id
where gp.allow = true
and g.group_id !=7;
