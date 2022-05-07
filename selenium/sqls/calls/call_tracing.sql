INSERT INTO call_logs(id, uniqueid, log) VALUES (52,'de6b5086-d2d5-11e4-a1a8-d1449310','2015-03-25 11:01:45  [NOTICE] M2 version: 0.0.189, active_calls: 1\n2015-03-25 11:01:45  [NOTICE] ----------------------------------- AUTHENTICATION ------------------------------------\n2015-03-25 11:01:45 [WARNING] Device was found by ip, but destination number and tech prefix does not match (dst: 37065843576, tech_prefix: 00)\n2015-03-25 11:01:45   [ERROR] Authentication failed! Host: 192.168.0.184, port 5060\n2015-03-25 11:01:45  [NOTICE] Start time: 0.000000, answer time: 0.000000, end time: 0.000000, acct-session-time: 0\n2015-03-25 11:01:45  [NOTICE] Received dialstatus: , cd->dialstatus: FAILED, received hangupcause: 0, cd->hangupcause: 301, cd->chan_name: m2_call_trace\n2015-03-25 11:01:45  [NOTICE] Real Duration: 0.000000, Real Billsec: 0.000000, Duration: 0, Billsec: 0\n2015-03-25 11:01:45  [NOTICE] ----------------------------------- ACCOUNTING ------------------------------------\n2015-03-25 11:01:45  [NOTICE] Call will not be charged\n2015-03-25 11:01:45  [NOTICE] cd->dialstatus: FAILED, cd->hangupcause: 301, cd->chan_name: m2_call_trace\n2015-03-25 11:01:45  [NOTICE] Call finished\n'),(53,'e48b7aa4-d2d5-11e4-a1ac-d1449310','2015-03-25 11:01:55  [NOTICE] M2 version: 0.0.189, active_calls: 1\n2015-03-25 11:01:55  [NOTICE] ----------------------------------- AUTHENTICATION ------------------------------------\n2015-03-25 11:01:55  [NOTICE] Originator data: accountcode: 11, user_id: 6, user_name: TestUser, originator_name: ipauthLQw8fFru, balance: 9965.3338, tech_prefix: 00, routing_algorithm: weight, routing_group_id: 12002, tariff_id: 7, capacity: 1000, host: 192.168.0.184, port: 5060, src_regexp: .* (1), src_deny_regexp:  (0), blocked: 0, balance_limit: 0.00000, call_limit: 0, time_zone: UTC, time_zone_offset: -1, user\'s datetime: 2015-03-25 11:01:55 WD, custom_sip_header: , max_call_timeout: 0, ringing_timeout: 60, number_pool_id: 0, allowed codecs: PCMA,G729,PCMU, originator codec list: , static blacklist/whitelist: no, list id: 1, grace time: 0\n2015-03-25 11:01:55  [NOTICE] Stripping technical prefix from destination number\n2015-03-25 11:01:55  [NOTICE] Original destination number: 0037065843576, technical prefix: 00, stripped destination number: 37065843576\n2015-03-25 11:01:55   [DEBUG] Changed call state to: PROCESSING\n2015-03-25 11:01:55  [NOTICE] ----------------------------------- AUTHORIZATION ------------------------------------\n2015-03-25 11:01:55   [DEBUG] Checking active calls for originator\n2015-03-25 11:01:55  [NOTICE] Active calls for originator: 1, capacity: 1000\n2015-03-25 11:01:55   [DEBUG] Checking CPS for accountcode = 11\n2015-03-25 11:01:55  [NOTICE] Ratedetails for originator: prefix: 37064, rate: 0.90000, connection_fee: 0.00000, increment: 1, min_time: 0, exchange_rate: 1.00000, currency: USD, effective_from: null\n2015-03-25 11:01:55  [NOTICE] Active calls for customer: 1, call limit: 0\n2015-03-25 11:01:55  [NOTICE] User\'s total call price for all current calls: 0.000000, balance after adjustment: 9965.333800\n2015-03-25 11:01:55  [NOTICE] Originator timeout: 7200\n2015-03-25 11:01:55   [DEBUG] Checking dial peers\n2015-03-25 11:01:55  [NOTICE] Stop hunting is enabled in dial peer \'good_dp\'. Skipping other dial peers\n2015-03-25 11:01:55  [NOTICE] Dial peers list (total 1 dial peers):\n2015-03-25 11:01:55  [NOTICE] Dial peer id: 1, name: good_dp, stop_hunting: 1, minimal_rate_margin: 0.00, minimal_rate_margin_percent: -150.00, tp_priority: weight, src_regexp: .*, src_deny_regexp: , dst_regexp: .*, dst_deny_regexp: , dst mask: , priority: 0, no_follow: 0\n2015-03-25 11:01:55  [NOTICE] Searching for terminators in dial peers\n2015-03-25 11:01:55  [NOTICE] Found 2 suitable terminators\n2015-03-25 11:01:55  [NOTICE] Terminators list for dial peer good_dp, id: 1, order by: weight\n2015-03-25 11:01:55  [NOTICE] Host: 192.168.0.184, port: 5061, id: 10, tp_tech_prefix: , user_id: 7, prefix: 370, rate: 10.00000, connection_fee: 0.00000, increment: 1, min_time: 0, exchange_rate: 1.00000 currency: USD, name: good_tp, percent: 100, supplier_balance: 337.37000, supplier_balance_limit: 800.00000, tariff_id: 6, time_zone: UTC, time_zone_offset: -1, supplier\'s datetime: 2015-03-25 11:01:55 WD, rate_effective_from: null, custom_sip_header: , max_timeout: 0, ringing_timeout: 60, hgc_mapping: , grace_time: 0, interpret_noanswer_as_failed: 1, interpret_busy_as_failed: 1, capacity: 2, tp_active_calls: 0, tp_user_call_limit: 3, tp_user_active_calls: 0\n2015-03-25 11:01:55  [NOTICE] Host: 192.168.0.74, port: 5060, id: 13, tp_tech_prefix: , user_id: 7, prefix: 370, rate: 10.00000, connection_fee: 0.00000, increment: 1, min_time: 0, exchange_rate: 1.00000 currency: USD, name: good_tp_2, percent: 100, supplier_balance: 337.37000, supplier_balance_limit: 800.00000, tariff_id: 6, time_zone: UTC, time_zone_offset: -1, supplier\'s datetime: 2015-03-25 11:01:55 WD, rate_effective_from: null, custom_sip_header: , max_timeout: 0, ringing_timeout: 60, hgc_mapping: , grace_time: 0, interpret_noanswer_as_failed: 0, interpret_busy_as_failed: 0, capacity: 1, tp_active_calls: 0, tp_user_call_limit: 3, tp_user_active_calls: 1\n2015-03-25 11:01:55   [DEBUG] Changed call state to: ROUTING\n2015-03-25 11:01:55  [NOTICE] ----------------------------------- ROUTING ------------------------------------\n2015-03-25 11:01:55   [DEBUG] Generating routing list\n2015-03-25 11:01:55   [DEBUG] Sorting termination points in dial peer \'good_dp\' by WEIGHT (sorting range start: 1, range end: 2)\n2015-03-25 11:01:55   [DEBUG] Sorting termination points in dial peer \'good_dp\' by WEIGHT (sorting range start: 1, range end: 2)\n2015-03-25 11:01:55  [NOTICE] Generated routing list:\n2015-03-25 11:01:55  [NOTICE] Dial peer: \'good_dp\' (1), dp priority: 0, terminator: \'good_tp\' (10), tp_rate: 10.00000, tp_rate_after_exchange: 10.00000, tp_weight: 1, tp_percent: 100, no_follow: 0\n2015-03-25 11:01:55  [NOTICE] Dial peer: \'good_dp\' (1), dp priority: 0, terminator: \'good_tp_2\' (13), tp_rate: 10.00000, tp_rate_after_exchange: 10.00000, tp_weight: 2, tp_percent: 100, no_follow: 0\n2015-03-25 11:01:55  [NOTICE] This is call tracing, call will not be routed outside\n2015-03-25 11:01:55  [NOTICE] Start time: 0.000000, answer time: 0.000000, end time: 0.000000, acct-session-time: 0\n2015-03-25 11:01:55  [NOTICE] Received dialstatus: , cd->dialstatus: FAILED, received hangupcause: 0, cd->hangupcause: 0, cd->chan_name: m2_call_trace\n2015-03-25 11:01:55  [NOTICE] Real Duration: 0.000000, Real Billsec: 0.000000, Duration: 0, Billsec: 0\n2015-03-25 11:01:55  [NOTICE] ----------------------------------- ACCOUNTING ------------------------------------\n2015-03-25 11:01:55  [NOTICE] Call will not be charged\n2015-03-25 11:01:55  [NOTICE] cd->dialstatus: FAILED, cd->hangupcause: 0, cd->chan_name: m2_call_trace\n2015-03-25 11:01:55  [NOTICE] Call finished\n');
INSERT INTO `calls` (id, calldate, clid, src, dst, dcontext, channel, dstchannel, lastapp, lastdata, duration, billsec, disposition, amaflags, uniqueid, userfield, src_device_id, dst_device_id, provider_id, provider_rate, provider_billsec, provider_price, user_id, user_rate, user_billsec, user_price, prefix, server_id, hangupcause, localized_dst, originator_ip, terminator_ip, real_duration, real_billsec, dst_user_id, pdd, src_user_id, terminated_by, answer_time, end_time) VALUES (11523,'2015-03-25 11:01:12','\"TestUser\" <37065843576>','37065843576','37065843576','','','','','',0,0,'FAILED',0,'de6b5086-d2d5-11e4-a1a8-d1449310','',0,0,0,0,0,0,0,0,0,0,'',1,301,'37065843576','192.168.0.184','',0,0,0,0.000000000000000,0,NULL,NULL,NULL),(11524,'2015-03-25 11:01:23','\"TestUser\" <37065843576>','37065843576','0037065843576','','','','','',5,4,'ANSWERED',0,'e48b7aa4-d2d5-11e4-a1ac-d1449310','',11,10,7,10,4,0.666667,6,0.9,4,0.06,'37064',1,16,'37065843576','192.168.0.184','192.168.0.184',4.740295,3.539709,7,0.000000000000000,0,NULL,NULL,NULL);
INSERT INTO `devices` VALUES (10,'ipauthDRYnkcCU','192.168.0.184','','mor_local','192.168.0.184',5061,0,10,'','1002',0,'','SIP',17,0,1,0,0,'no','all','alaw;g729;ulaw;g723','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','','no','no',1,'good_tp',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5061,0,0,6400,0,0,0,'','',0,0,500,'.*','',1,1,'',6,2,'.*','','',0,'456456',NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,1),(11,'ipauthLQw8fFru','192.168.0.184','','m2','192.168.0.184',5060,0,11,'','1003',0,'','SIP',16,0,1,0,0,'no','all','alaw;g729;ulaw','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','no','no',1,'mano_laptopas',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,6400,0,1,1,'00','weight',12002,7,1000,'.*','',0,0,'',0,500,'','','',0,NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),(12,'mor_server_1','127.0.0.1','','mor_direct','127.0.0.1',5060,0,12,'','mor_server_1',0,'mor_server_1','SIP',0,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','no','no',NULL,'no',NULL,'rfc2833',NULL,NULL,'mor_server_1',NULL,'no','no','no','never','no',1,'DO NOT EDIT',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,NULL,0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,NULL,0,'udp','no','no',0,0,'no',5060,0,0,6400,0,0,0,'','lcr',0,0,500,'.*','',0,0,'',0,500,'','',NULL,0,'mor_server_1',NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),(13,'ipauth66jbV7U3','192.168.0.74','','mor_local','192.168.0.74',5060,0,13,'','1004',0,'','SIP',17,0,1,0,0,'no','all','alaw;h261;g729;h263;ulaw;h263p;g723;h264;g726;gsm;ilbc;lpc10;speex;adpcm;slin;g722','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','','no','no',1,'good_tp_2',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,6400,0,0,0,'','',0,0,500,'.*','',1,1,'',6,1,'.*','','',0,NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO `users` VALUES (16,'TestUser','f7c3bc1d808e04732adf679965ccc34ca7ae3441','user',0,'','',3.000000000000000,0,9965.333800000000000,0.000000000000000,0,1,0,0,0.000000000000000,'0000-00-00 00:00:00',0,0,1,11,0.000000000000000,'','0000000001','2014-07-22','',1,'',0.000000000000000,6,'',0,0,0,'2000-01-01 00:00:00','5u32hqsxu3',NULL,1,0,NULL,NULL,0,0,0,1,0.000000000000000,0.000000000000000,0.000000000000000,0.000000000000000,'2015-01-01',15,0,0,0,'',0,0,0.000000000000000,0,3,0,0,-1,-1,0,0,0,0,1,0,0,'UTC',0,NULL,0,0,-1,'global',-1,0,0,0,0.0000,800.0000,'TestUser.stoma@gmail.com','','','',0.000000000000000,0.000000000000000,'monthly',15,0,0,'',0,-1,0,-1,0,0,0,'','no',1),(17,'Provider','f7c3bc1d808e04732adf679965ccc34ca7ae3441','user',0,'','',3.000000000000000,0,337.369997000000000,0.000000000000000,0,1,0,0,0.000000000000000,'0000-00-00 00:00:00',0,0,1,10,0.000000000000000,'','0000000002','2014-07-22','',1,'',0.000000000000000,7,'',0,0,0,'2000-01-01 00:00:00','haqcqu26tq',NULL,1,3,NULL,NULL,0,0,0,1,0.000000000000000,0.000000000000000,0.000000000000000,0.000000000000000,'2015-01-01',15,0,0,0,'',0,0,0.000000000000000,0,4,0,0,-1,-1,0,0,0,0,1,0,0,'UTC',0,NULL,0,0,-1,'global',-1,0,0,0,0.0000,800.0000,'','','','',0.000000000000000,0.000000000000000,'monthly',15,0,0,'',0,-1,0,-1,0,0,0,'','whitelist',1),(19,'aabbbbaaa','59ec06207488b9e65991d3e7eb2ea95062c65c89','manager',0,'aaaaaaaaa','',3.000000000000000,0,0.000000000000000,0.000000000000000,0,1,0,0,0.000000000000000,'0000-00-00 00:00:00',0,0,1,0,-1.000000000000000,NULL,NULL,NULL,NULL,NULL,NULL,0.000000000000000,9,NULL,0,0,0,'2000-01-01 00:00:00','028b9w02jm',NULL,1,0,NULL,NULL,0,0,0,1,0.000000000000000,0.000000000000000,0.000000000000000,0.000000000000000,'2008-01-01',15,0,0,0,NULL,100,0,0.000000000000000,0,6,1,0,-1,-1,0,0,0,0,1,0,0,'UTC',0,NULL,0,0,-1,'global',-1,-1,0,0,0.0000,0.0000,'',NULL,NULL,NULL,0.000000000000000,0.000000000000000,'monthly',15,0,0,'',-1,-1,-1,-1,0,0,1,'','no',NULL);

