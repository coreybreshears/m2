INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(120118, 12001, 5780, NULL, 15.000000000000000, '2013-01-01 00:00:00', 370),
(120119, 12001, 12483, NULL, 15.000000000000000, '2013-01-01 00:00:00', 3702),
(120124, 12001, 5784, NULL, NULL, '2013-01-01 00:00:00', 370463),
(120125, 12001, 5785, NULL, NULL, '2013-01-01 00:00:00', 370464),
(120126, 12001, 12524, NULL, NULL, '2013-01-01 00:00:00', 37052),
(120127, 12001, 5826, NULL, NULL, '2013-01-01 00:00:00', 370521),
(120128, 12001, 5827, NULL, NULL, '2013-01-01 00:00:00', 370523),
(120129, 12001, 5828, NULL, NULL, '2013-01-01 00:00:00', 370524),
(120130, 12001, 5829, NULL, NULL, '2013-01-01 00:00:00', 370525),
(120131, 12001, 5830, NULL, NULL, '2013-01-01 00:00:00', 370526),
(120132, 12001, 5831, NULL, NULL, '2013-01-01 00:00:00', 370527),
(120133, 12001, 5786, NULL, NULL, '2013-01-01 00:00:00', 3706),
(120134, 12001, 5815, NULL, NULL, '2013-01-01 00:00:00', 37060),
(120135, 12001, 12502, NULL, NULL, '2013-01-01 00:00:00', 370600),
(120136, 12001, 12503, NULL, NULL, '2013-01-01 00:00:00', 370601),
(120137, 12001, 12504, NULL, NULL, '2013-01-01 00:00:00', 370602),
(120138, 12001, 12505, NULL, NULL, '2013-01-01 00:00:00', 370603),
(120139, 12001, 12506, NULL, NULL, '2013-01-01 00:00:00', 370604),
(120140, 12001, 12507, NULL, NULL, '2013-01-01 00:00:00', 370605),
(120141, 12001, 12508, NULL, NULL, '2013-01-01 00:00:00', 370606),
(120146, 12001, 5819, NULL, NULL, '2013-01-01 00:00:00', 370648);

#add rates.prefix ir rates.name
#UPDATE rates JOIN destinations ON destinations.id = rates.destination_id SET rates.prefix = destinations.prefix, rates.name = destinations.name WHERE rates.name = '' AND rates.prefix = '';

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(120118, '00:00:00', '23:59:59', 0.269500000000000, 0.000000000000000, 120118, 1, 0, ''),
(120119, '00:00:00', '23:59:59', 0.595600000000000, 0.000000000000000, 120119, 1, 0, ''),
(120124, '00:00:00', '23:59:59', 0.695500000000000, 0.000000000000000, 120124, 1, 0, ''),
(120125, '00:00:00', '23:59:59', 0.125600000000000, 0.000000000000000, 120125, 1, 0, ''),
(120126, '00:00:00', '23:59:59', 0.058900000000000, 0.000000000000000, 120126, 1, 0, ''),
(120127, '00:00:00', '23:59:59', 0.250000000000000, 0.000000000000000, 120127, 1, 0, ''),
(120128, '00:00:00', '23:59:59', 0.120000000000000, 0.000000000000000, 120128, 1, 0, ''),
(120129, '00:00:00', '23:59:59', 0.158000000000000, 0.000000000000000, 120129, 1, 0, ''),
(120130, '00:00:00', '23:59:59', 0.658900000000000, 0.000000000000000, 120130, 1, 0, ''),
(120131, '00:00:00', '23:59:59', 0.125800000000000, 0.000000000000000, 120131, 1, 0, ''),
(120132, '00:00:00', '23:59:59', 0.258800000000000, 0.000000000000000, 120132, 1, 0, ''),
(120133, '00:00:00', '23:59:59', 0.259500000000000, 0.000000000000000, 120133, 1, 0, ''),
(120134, '00:00:00', '23:59:59', 0.288000000000000, 0.000000000000000, 120134, 1, 0, ''),
(120135, '00:00:00', '23:59:59', 0.269800000000000, 0.000000000000000, 120135, 1, 0, ''),
(120136, '00:00:00', '23:59:59', 0.589600000000000, 0.000000000000000, 120136, 1, 0, ''),
(120137, '00:00:00', '23:59:59', 0.258800000000000, 0.000000000000000, 120137, 1, 0, ''),
(120138, '00:00:00', '23:59:59', 0.258500000000000, 0.000000000000000, 120138, 1, 0, ''),
(120139, '00:00:00', '23:59:59', 0.258000000000000, 0.000000000000000, 120139, 1, 0, ''),
(120140, '00:00:00', '23:59:59', 0.256980000000000, 0.000000000000000, 120140, 1, 0, ''),
(120141, '00:00:00', '23:59:59', 0.258800000000000, 0.000000000000000, 120141, 1, 0, ''),
(120146, '00:00:00', '23:59:59', 0.200000000000000, 0.000000000000000, 120146, 1, 0, '');
