DELETE FROM `destinations` WHERE `prefix` LIKE '435%';
INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(20100, '4357', 'AUT', 'AUSTRIA-M-MILKOM', 0),
(20101, '43544', 'AUT', 'AUSTRIA-M-MILKOM', 0);

UPDATE `destinations` SET `destinationgroup_id`= 0 WHERE `prefix`= '672';