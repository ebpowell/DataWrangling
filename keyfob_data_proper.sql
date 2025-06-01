-- key_fobs.group_permissions definition

-- Drop table

-- DROP TABLE key_fobs.group_permissions;

CREATE TABLE key_fobs.group_permissions (
	perm_id int4 NOT NULL,
	start_date date NULL,
	end_date date NULL,
	start_timie time NULL,
	end_time time NULL,
	door_id int4 NULL,
	allow bool NULL,
	group_id int4 NULL,
	CONSTRAINT group_permissions_pk PRIMARY KEY (perm_id)
);



-- property table data from keyfobs
drop view key_fobs.v_property_data;
create or replace view key_fobs.v_property_data as
select property_id, address
from key_fobs.keyfobs_2025 k
where property_id is not null 
and address is not null;

-- Owners
create sequence key_fobs.seq_ownerid increment by 1 minvalue 1;
drop view key_fobs.v_owners_data;
create or replace view key_fobs.v_owners_data as
select nextval('key_fobs.seq_ownerid') as owner_id, property_id, last_nam as last_name, first_name
from key_fobs.keyfobs_2025 k
where last_nam is not null
or length(first_name) >1;

--keyfobs
create sequence key_fobs.seq_fobrecid increment by 1 minvalue 1;
drop view key_fobs.v_keyfobs_data ;
create or replace view key_fobs.v_keyfobs_data as
select nextval('key_fobs.seq_fobrecid') as keyfob_id, property_id, fob_id::int from
(
select k.property_id, k.fob_1 as fob_id
from key_fobs.keyfobs_2025 k 
union 
select k.property_id, k.fob_2 as fob_id
from key_fobs.keyfobs_2025 k ) as a 
where length(a.fob_id::text) >2;

--Add Homeowners to proprty_group_permissions table
create sequence key_fobs.seq_prgrecid increment by 1 minvalue 1 start 17;
insert into key_fobs.property_group_permissions 
(prop_grp_id, property_id, group_id) 
select nextval('key_fobs.seq_prgrecid'), 
property_id, 7
from key_fobs.properties;

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

--For each of the special access fobs, what doors are they entitle to and when?


--Homeonwers access table


-- Owner Fobid matrix
select o.last_name, o.first_name, k.fob_id
from key_fobs.owners o
inner join key_fobs.properties p 
on o.property_id =p.property_id
inner join key_fobs.keyfobs k 
on k.property_id = p.property_id;
--Reset sequences
ALTER SEQUENCE key_fobs.seq_ownerid RESTART WITH 1;
ALTER SEQUENCE key_fobs.seq_fobrecid RESTART WITH 1;


update key_fobs.keyfobs k set fob_id = 6338386 where fob_id = 2893920;


select max(record_id), door_controller_ip from door_controller.t_keyswipes tk
group by tk.door_controller_ip ;
