INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(120101, 12001, 2, NULL, 5.000000000000000, '2013-01-01 00:00:00', 93),
(120104, 12001, 5, NULL, 5.000000000000000, '2013-01-01 00:00:00', 9340),
(120105, 12001, 9, NULL, 5.000000000000000, '2013-01-01 00:00:00', 9350),
(120106, 12001, 6, NULL, 5.000000000000000, '2013-01-01 00:00:00', 9360),
(120107, 12001, 11338, NULL, 5.000000000000000, '2013-01-01 00:00:00', 937),
(120108, 12001, 10, NULL, 5.000000000000000, '2013-01-01 00:00:00', 9370),
(120109, 12001, 11, NULL, 5.000000000000000, '2013-01-01 00:00:00', 9371),
(120110, 12001, 12, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9372),
(120111, 12001, 3, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9375),
(120112, 12001, 13, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9376),
(120113, 12001, 14, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9377),
(120114, 12001, 15, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9378),
(120115, 12001, 16, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9379),
(120116, 12001, 4, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9380),
(120117, 12001, 17, NULL, 10.000000000000000, '2013-01-01 00:00:00', 9390);

#add rates.prefix ir rates.name
#UPDATE rates JOIN destinations ON destinations.id = rates.destination_id SET rates.prefix = destinations.prefix, rates.name = destinations.name WHERE rates.name = '' AND rates.prefix = '';

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(120101, '00:00:00', '23:59:59', 0.025600000000000, 0.000000000000000, 120101, 1, 0, ''),
(120104, '00:00:00', '23:59:59', 0.585600000000000, 0.000000000000000, 120104, 1, 0, ''),
(120105, '00:00:00', '23:59:59', 0.589600000000000, 0.000000000000000, 120105, 1, 0, ''),
(120106, '00:00:00', '23:59:59', 0.258600000000000, 0.000000000000000, 120106, 1, 0, ''),
(120107, '00:00:00', '23:59:59', 0.236900000000000, 0.000000000000000, 120107, 1, 0, ''),
(120108, '00:00:00', '23:59:59', 0.125900000000000, 0.000000000000000, 120108, 1, 0, ''),
(120109, '00:00:00', '23:59:59', 0.025690000000000, 0.000000000000000, 120109, 1, 0, ''),
(120110, '00:00:00', '23:59:59', 0.059600000000000, 0.000000000000000, 120110, 1, 0, ''),
(120111, '00:00:00', '23:59:59', 0.269800000000000, 0.000000000000000, 120111, 1, 0, ''),
(120112, '00:00:00', '23:59:59', 0.269600000000000, 0.000000000000000, 120112, 1, 0, ''),
(120113, '00:00:00', '23:59:59', 0.699500000000000, 0.000000000000000, 120113, 1, 0, ''),
(120114, '00:00:00', '23:59:59', 0.695250000000000, 0.000000000000000, 120114, 1, 0, ''),
(120115, '00:00:00', '23:59:59', 0.699000000000000, 0.000000000000000, 120115, 1, 0, ''),
(120116, '00:00:00', '23:59:59', 0.250000000000000, 0.000000000000000, 120116, 1, 0, ''),
(120117, '00:00:00', '23:59:59', 0.269000000000000, 0.000000000000000, 120117, 1, 0, '');
