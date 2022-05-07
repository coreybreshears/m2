DELETE FROM `servers`;
INSERT INTO `servers` (`id`, `server_ip`, `stats_url`, `server_type`, `active`, `comment`, `hostname`, `maxcalllimit`, `ami_port`, `ami_secret`, `ami_username`, `port`, `ssh_username`, `ssh_secret`, `ssh_port`, `gateway_active`, `version`, `uptime`, `gui`, `db`, `core`, `load_ok`, `hdd_free_space`) VALUES
(1, '127.0.0.1', NULL, 'proxy', 0, '', '127.0.0.1', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 1, 1, 1, 1, 11),
(2, '127.0.0.2', NULL, 'freeswitch', 1, '', '127.0.0.2', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 12),
(3, '127.0.0.3', NULL, 'freeswitch', 0, '', '127.0.0.3', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 13),
(4, '127.0.0.4', NULL, 'other', 1, '', '127.0.0.4', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 14),
(5, '127.0.0.5', NULL, 'other', 0, '', '127.0.0.5', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 15),
(6, '127.0.0.6', NULL, 'freeswitch', 1, '', '127.0.0.6', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 16),
(7, '127.0.0.7', NULL, 'freeswitch', 0, '', '127.0.0.7', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 17),
(8, '127.0.0.8', NULL, 'other', 1, '', '127.0.0.8', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 18),
(9, '127.0.0.9', NULL, 'other', 0, '', '127.0.0.9', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '', 0, 0, 0, 1, 19);