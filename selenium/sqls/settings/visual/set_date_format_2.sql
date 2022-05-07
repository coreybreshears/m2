DELETE FROM `conflines` where name='Date_format';
INSERT INTO `conflines` (`value`,`name`) VALUES ('%Y,%m,%d %H:%M:%S','Date_format');
