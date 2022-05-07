INSERT INTO `directions` (`id`, `name`, `code`, `iso31661code`, `iso3166code`) VALUES 
(300, 'AAAAA', 'AAA', '000', '00');

INSERT INTO `destinations` (`id`, `prefix`, `direction_code`, `name`, `destinationgroup_id`) VALUES
(300000001, '1A1A', 'AAA', 'AAA', 0),
(300000002, '2B2B', 'AAA', 'BBB', 0),
(300000003, '3C3C', 'AAA', 'CCC', 0);

INSERT INTO `rates` (`id`, `tariff_id`, `prefix`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `old_id`, `currently_effective`) VALUES
(3001, 5, '1A1A', 300000001, NULL, 0.000000000000000, '2021-06-15 00:00:00', NULL, 0),
(3002, 5, '2B2B', 300000002, NULL, 0.000000000000000, '2021-06-16 00:00:00', NULL, 0),
(521, 5, '3C3C', 300000003, NULL, 0.000000000000000, '2021-06-17 00:00:00', NULL, 0);

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`, `blocked`) VALUES
(3001, '00:00:00', '23:59:59', 1.000000000000000, 0.000000000000000, 3001, 1, 0, '', 0),
(3002, '00:00:00', '23:59:59', 2.000000000000000, 0.000000000000000, 3002, 1, 0, '', 0),
(3003, '00:00:00', '23:59:59', 3.000000000000000, 0.000000000000000, 3003, 1, 0, '', 0);