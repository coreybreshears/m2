DELETE FROM `destinationgroups` WHERE `name` = 'Jordan';
INSERT INTO `destinationgroups` (`id`, `name`, `flag`) VALUES
(600, 'Jordan - Fixed', 'jor'),
(601, 'Jordan - Mobile Orange', 'jor'),
(602, 'Jordan - Mobile Umniah', 'jor'),
(603, 'Jordan - Mobile Zain', 'jor');

DELETE FROM `destinations` WHERE `prefix` LIKE '962%';
INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(20070, '962', 'JOR', 'Jordan - Fixed', 600),
(20071, '962745', 'JOR', 'Jordan - Mobile Others', 0),
(20072, '962746', 'JOR', 'Jordan - Mobile Others', 0),
(20073, '962747', 'JOR', 'Jordan - Mobile Others', 0),
(20074, '9627555', 'JOR', 'Jordan - Mobile Fastlink', 0),
(20075, '9627556', 'JOR', 'Jordan - Mobile Fastlink', 0),
(20076, '9627557', 'JOR', 'Jordan - Mobile Fastlink', 0),
(20077, '9627558', 'JOR', 'Jordan - Mobile Fastlink', 0),
(20078, '96277', 'JOR', 'Jordan - Mobile Orange', 601),
(20079, '962772', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20080, '962775', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20081, '962776', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20082, '962777', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20083, '962778', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20084, '962779', 'JOR', 'Jordan - Mobile Mobilecom', 0),
(20085, '96278', 'JOR', 'Jordan - Mobile Umniah', 602),
(20086, '96279', 'JOR', 'Jordan - Mobile Zain', 603);