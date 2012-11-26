# Run this script in the core database that hosts Instant Framework
# BE CAREFUL! Running this script deletes admin users and trace data!

drop table if exists admin;
create table admin
(
  admin_id MEDIUMINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  login_id CHAR(8) NOT NULL,
  email VARCHAR(40) NOT NULL,
  password VARCHAR(20) NOT NULL
);

drop table if exists trace_log;
create table trace_log (
  log_id MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  date DATE NOT NULL,
  time TIME NOT NULL,
  message VARCHAR(255)
);

drop table if exists login_log;
create table login_log (
  log_id MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(40) NOT NULL,
  date DATE NOT NULL,
  time TIME NOT NULL,
  result VARCHAR(40)
);
