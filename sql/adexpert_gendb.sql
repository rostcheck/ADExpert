DROP TABLE IF EXISTS trading_partner;
CREATE TABLE trading_partner
(
	trading_partner_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(80) NOT NULL,
	ffl_license_number VARCHAR(20) NULL,
	premises_address1 VARCHAR(50) NOT NULL,
	premises_address2 VARCHAR(50) NULL,
	premises_city VARCHAR(30) NOT NULL,
	premises_state CHAR(2) NOT NULL,
	premises_zip VARCHAR(10) NULL,
	mailing_address1 VARCHAR(50) NOT NULL,
	mailing_address2 VARCHAR(50) NULL,
	mailing_city VARCHAR(30) NOT NULL,
	mailing_state CHAR(2) NOT NULL,
	mailing_zip VARCHAR(10) NULL,
	website VARCHAR(30) NULL,
	email VARCHAR(40) NULL,
	phone VARCHAR(20) NULL,
	notes VARCHAR(256) NULL
);

DROP TABLE IF EXISTS trading_partner_pre_edit;
CREATE TABLE trading_partner_pre_edit
(
	trading_partner_pre_edit_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	trading_partner_id MEDIUMINT UNSIGNED NOT NULL,
	name VARCHAR(80) NOT NULL,
	ffl_license_number VARCHAR(20) NULL,
	premises_address1 VARCHAR(50) NOT NULL,
	premises_address2 VARCHAR(50) NULL,
	premises_city VARCHAR(30) NOT NULL,
	premises_state CHAR(2) NOT NULL,
	premises_zip VARCHAR(10) NULL,
	mailing_address1 VARCHAR(50) NOT NULL,
	mailing_address2 VARCHAR(50) NULL,
	mailing_city VARCHAR(30) NOT NULL,
	mailing_state CHAR(2) NOT NULL,
	mailing_zip VARCHAR(10) NULL,
	website VARCHAR(30) NULL,
	email VARCHAR(40) NULL,
	phone VARCHAR(20) NULL,
	notes VARCHAR(256) NULL
);


DROP TABLE IF EXISTS firearm;
CREATE TABLE firearm
(
	firearm_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	manufacturer VARCHAR(50) NOT NULL,
	importer VARCHAR(50),
	model VARCHAR(20) NOT NULL,
	serial_number VARCHAR(10),
	firearm_type VARCHAR(20) NOT NULL,
	caliber VARCHAR(15) NOT NULL,
	cabinet VARCHAR(30),
	tray VARCHAR(10),
	hammer VARCHAR(20) NOT NULL,
	butt VARCHAR(20) NOT NULL,
	grips VARCHAR(20) NOT NULL,
	parts VARCHAR(20) NOT NULL,
	grade VARCHAR(20) NOT NULL,
	lockup VARCHAR(20) NOT NULL,
	trigger_type VARCHAR(20) NOT NULL,
	notes VARCHAR(256) NULL,

	INDEX serial_number_index (serial_number)
);

DROP TABLE IF EXISTS firearm_pre_edit;
CREATE TABLE firearm_pre_edit
(
	firearm_pre_edit_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	firearm_id MEDIUMINT UNSIGNED NOT NULL,
	manufacturer VARCHAR(50) NOT NULL,
	importer VARCHAR(50),
	model VARCHAR(20) NOT NULL,
	serial_number VARCHAR(10),
	firearm_type VARCHAR(20) NOT NULL,
	caliber VARCHAR(15) NOT NULL,
	cabinet VARCHAR(30),
	tray VARCHAR(10),
	hammer VARCHAR(20) NOT NULL,
	butt VARCHAR(20) NOT NULL,
	grips VARCHAR(20) NOT NULL,
	parts VARCHAR(20) NOT NULL,
	grade VARCHAR(20) NOT NULL,
	lockup VARCHAR(20) NOT NULL,
	trigger_type VARCHAR(20) NOT NULL,
	notes VARCHAR(256) NULL,

	INDEX serial_number_index (serial_number)
);

DROP TABLE IF EXISTS acquisition;
CREATE TABLE acquisition
(
	acquisition_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, 
	firearm_id MEDIUMINT UNSIGNED NOT NULL,
	acquisition_date DATE NOT NULL,
	trading_partner_id MEDIUMINT UNSIGNED NOT NULL	
); 

DROP TABLE IF EXISTS acquisition_pre_edit;
CREATE TABLE acquisition_pre_edit
(
	acquisition_pre_edit_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,	
	acquisition_id MEDIUMINT UNSIGNED NOT NULL,
	firearm_id MEDIUMINT UNSIGNED NOT NULL,
	acquisition_date DATE NOT NULL,
	trading_partner_id MEDIUMINT UNSIGNED NOT NULL	
); 


DROP TABLE IF EXISTS disposition;
CREATE TABLE disposition
(
	disposition_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	disposition_date DATE NOT NULL,
	acquisition_id MEDIUMINT UNSIGNED NOT NULL,
	trading_partner_id MEDIUMINT UNSIGNED NOT NULL,
	4473_number VARCHAR(20) NULL,
	lost_stolen_atf_incident_number VARCHAR(20) NULL,
	lost_stolen_pd_incident_number VARCHAR(20) NULL
);

DROP TABLE IF EXISTS disposition_pre_edit;
CREATE TABLE disposition_pre_edit
(
	disposition_pre_edit_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	disposition_id MEDIUMINT UNSIGNED NOT NULL, 
	disposition_date DATE NOT NULL,
	acquisition_id MEDIUMINT UNSIGNED NOT NULL,
	trading_partner_id MEDIUMINT UNSIGNED NOT NULL,
	4473_number VARCHAR(20) NULL,
	lost_stolen_atf_incident_number VARCHAR(20) NULL,
	lost_stolen_pd_incident_number VARCHAR(20) NULL
);

DROP TABLE IF EXISTS edit_log;
CREATE TABLE edit_log
(
	edit_log_id MEDIUMINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	edit_date DATE NOT NULL,
	admin_id MEDIUMINT UNSIGNED NOT NULL,
	notes VARCHAR(1024) NOT NULL		
);

CREATE OR REPLACE VIEW inventory_firearm as 
select f.firearm_id, f.manufacturer, f.importer, f.model, f.serial_number, f.firearm_type, f.caliber, f.cabinet, f.tray, f.hammer, f.butt, f.grips, f.parts, f.grade, f.lockup, f.trigger_type, f.notes
from firearm f
join acquisition a
on a.firearm_id = f.firearm_id
left join disposition d
on d.acquisition_id = a.acquisition_id
where d.disposition_id is null;

CREATE OR REPLACE VIEW noninventory_firearm as 
select f.firearm_id, f.manufacturer, f.importer, f.model, f.serial_number, f.firearm_type, f.caliber, f.cabinet, f.tray, f.hammer, f.butt, f.grips, f.parts, f.grade, f.lockup, f.trigger_type, f.notes
from firearm f
join acquisition a
on a.firearm_id = f.firearm_id
join disposition d
on d.acquisition_id = a.acquisition_id;

create or replace view ad_book_view as
select a.acquisition_id as record_id, f.manufacturer, f.importer, f.model, f.serial_number, f.firearm_type, f.caliber, a.acquisition_date, atp.name as acquisition_name, atp.ffl_license_number as acquisition_ffl, 
atp.mailing_address1 as acquisition_address1, atp.mailing_city as acquisition_city, 
atp.mailing_state as acquisition_state, atp.mailing_zip as acquisition_zip, d.disposition_date, 
dtp.name as disposition_name, dtp.ffl_license_number as disposition_ffl, d.4473_number, d.lost_stolen_atf_incident_number, d.lost_stolen_pd_incident_number, 
dtp.mailing_address1 as disposition_address1, dtp.mailing_city as disposition_city,
dtp.mailing_state as disposition_state, dtp.mailing_zip as disposition_zip
from firearm f
join acquisition a
on a.firearm_id = f.firearm_id
join trading_partner atp
on atp.trading_partner_id = a.trading_partner_id
left join disposition d
on a.acquisition_id = d.acquisition_id
left join trading_partner dtp
on dtp.trading_partner_id = d.trading_partner_id;

