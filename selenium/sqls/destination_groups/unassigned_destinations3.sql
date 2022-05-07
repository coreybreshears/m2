DELETE FROM `destinationgroups` WHERE `name` = 'Albania';
INSERT INTO `destinationgroups` (`id`, `name`, `flag`) VALUES
(603, 'Albania - Fixed AMC', 'alb');

DELETE FROM `destinations` WHERE `prefix` LIKE '355%';
INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(20076, '3552253', 'ALB', 'Albania - Fixed AMC', 603),
(20077, '35522530', 'ALB', 'ALBANIA AMC FXD', 0),
(20078, '3552254', 'ALB', 'Albania - Fixed AMC', 603),
(20079, '35522540', 'ALB', 'ALBANIA AMC FXD', 0),
(20080, '3552440', 'ALB', 'Albania - Fixed AMC', 603),
(20081, '35524401', 'ALB', 'ALBANIA AMC FXD', 0),
(20082, '35524402', 'ALB', 'ALBANIA AMC FXD', 0),
(20083, '35524403', 'ALB', 'ALBANIA AMC FXD', 0),
(20084, '35524404', 'ALB', 'ALBANIA AMC FXD', 0),
(20085, '35524405', 'ALB', 'ALBANIA AMC FXD', 0),
(20086, '35524406', 'ALB', 'ALBANIA AMC FXD', 0),
(20087, '35524407', 'ALB', 'ALBANIA AMC FXD', 0),
(20088, '35524408', 'ALB', 'ALBANIA AMC FXD', 0),
(20089, '35524409', 'ALB', 'ALBANIA AMC FXD', 0),
(20090, '35526160', 'ALB', 'Albania - Fixed AMC', 603),
(20091, '35526250', 'ALB', 'Albania - Fixed AMC', 603),
(20092, '35526293', 'ALB', 'Albania - Fixed AMC', 603);