DELETE FROM `destinationgroups` WHERE `name` = 'Afghanistan';
INSERT INTO `destinationgroups` (`id`, `name`, `flag`) VALUES
(604, 'Afghanistan - Fixed', 'afg');

DELETE FROM `destinations` WHERE `prefix` LIKE '93%';
INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(20095, '93', 'AFG', 'Afghanistan - Fixed', 604),
(20096, '9320', 'AFG', 'AFGHANISTAN ', 0),
(20097, '9320210', 'AFG', 'AFGHANISTAN ', 0),
(20098, '93202108', 'AFG', 'AFGHANISTAN ', 0),
(20099, '93202109', 'AFG', 'AFGHANISTAN ', 0);