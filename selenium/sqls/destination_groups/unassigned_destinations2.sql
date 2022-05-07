DELETE FROM `destinationgroups` WHERE `name` = 'Reunion';
INSERT INTO `destinationgroups` (`id`, `name`, `flag`) VALUES
(600, 'Reunion - Fixed', 'reu'),
(601, 'Reunion - Mobile Others', 'reu'),
(602, 'Reunion - Mobile Orange', 'reu');

DELETE FROM `destinations` WHERE `prefix` LIKE '262%';
INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(20070, '262', 'REU', 'Reunion - Fixed', 0),
(20071, '262262', 'REU', 'Reunion - Fixed', 600),
(20072, '262692', 'REU', 'Reunion - Mobile Others', 601),
(20073, '26269200', 'REU', 'Reunion - Mobile Orange', 602);