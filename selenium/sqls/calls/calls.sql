INSERT INTO `routing_groups` (`id`, `name`, `comment`) VALUES
(1, 'main_routing_group', ''),
(2, 'geras_rg', ''),
(3, 'test', '');


INSERT INTO `rgroup_dpeers` (`id`, `routing_group_id`, `dial_peer_id`, `dial_peer_priority`) VALUES
(1, 1, 1, 1),
(2, 2, 2, 1),
(3, 1, 3, 1),
(4, 3, 4, 1);

#devices
INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`, `cps_call_limit`, `cps_period`, `timerb`, `callerid_number_pool_id`, `op`, `op_active`, `op_tech_prefix`, `op_routing_algorithm`, `op_routing_group_id`, `op_tariff_id`, `op_capacity`, `op_src_regexp`, `op_src_deny_regexp`, `tp`, `tp_active`, `tp_tech_prefix`, `tp_tariff_id`, `tp_capacity`, `tp_src_regexp`, `tp_src_deny_regexp`, `custom_sip_header`, `defaultuser`, `useragent`, `type`, `md5secret`, `remotesecret`, `directmedia`, `useclientcode`, `setvar`, `amaflags`, `callcounter`, `busylevel`, `allowoverlap`, `allowsubscribe`, `maxcallbitrate`, `rfc2833compensate`, `session-timers`, `session-expires`, `session-minse`, `session-refresher`, `t38pt_usertpsource`, `regexten`, `defaultip`, `rtptimeout`, `rtpholdtimeout`, `outboundproxy`, `callbackextension`, `timert1`, `qualifyfreq`, `constantssrc`, `contactpermit`, `contactdeny`, `usereqphone`, `textsupport`, `faxdetect`, `buggymwi`, `auth`, `fullname`, `trunkname`, `cid_number`, `callingpres`, `mohinterpret`, `mohsuggest`, `parkinglot`, `hasvoicemail`, `vmexten`, `autoframing`, `rtpkeepalive`, `call-limit`, `g726nonstandard`, `ignoresdpversion`, `allowtransfer`, `dynamic`) VALUES (8,'ipauthtyQcMhLb','192.168.0.108','','m2','192.168.0.108',5060,0,8,'','1002',0,'','SIP',6,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','no','no',1,'mano laptopas',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',2,0,'','no','en',0,NULL,0,'Unmonitored',0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,1,'','weight',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'x-M2-DEVICE: 8'),(9,'ipauthm785kTxV','192.168.0.242','','m2','192.168.0.242',5060,0,9,'','1003',0,'','SIP',7,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','no','no',1,'Mano provideris',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',2,0,'','no','en',0,NULL,0,'Unmonitored',0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'.*','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(11,'
ipauthCcvBaRAn','192.168.0.145','','m2','192.168.0.145',5060,0,11,'','1004',0,'','SIP',8,0,1,0,0,'no','all','alaw;ulaw;gsm;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','no','no',1,'Mano device',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,'Unmonitored',0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,1,'123#','lcr',2,13,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,''),(12,'ipauthu1xR9GLs','192.168.0.73','','m2','192.168.0.73',5061,0,12,'','1005',0,'','SIP',6,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port','no','no',1,'x5 device',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5061,0,0,NULL,0,1,1,'','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,''),(13,'ipauthWg3cWyYw','192.168.0.74','','m2','192.168.0.74',5060,0,13,'','1006',0,'','SIP',7,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port,invite','no','no',1,'dima',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'370123456','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(14,'ipauthXh4LF2kh','192.168.0.146','','m2','192.168.0.146',5060,0,14,'','1007',0,'','SIP',7,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no',
'no','port,invite','no','no',1,'ervinas',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'.*','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(15,'ipauthGVU93wjS','192.168.0.179','','m2','192.168.0.179',5061,0,15,'','1008',0,'','SIP',7,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port,invite','no','no',1,'zoiper',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5061,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'.*','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(16,'ipauthu2Xn9HjM','192.168.0.74','','mor_local','192.168.0.74',5060,0,16,'\"ricardas\" <370112233>','1009',0,'','SIP',7,0,1,0,0,'no','all','g729;alaw;ulaw','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port,invite','no','no',1,'geras',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',2,0,'','no','en',0,NULL,0,'Unmonitored',0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'.*','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'x-M2-PROV: 16'),(17,'ipauthgTzNZW84','192.168.0.255','','m2','192.168.0.255',5061,0,17,'','1010',0,'','SIP',7,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port,invite','no','no',1,'fake',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5061,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',1,1,'',13,500,'.*','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(18,'ipauthCjTsVBDf','192.168.0.213','','m2','192.168.0.213',5060,0,18,'','1011',0,'','SIP',6,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','no',NULL,'no',0,'rfc2833',NULL,NULL,NULL,NULL,'no','no','port,invite','no','no',1,'x3 device',0,0,'',0,0,0,0,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,1,'123#','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(19,'mor_server_2','','','m2','192.168.0.76',5060,0,19,'','mor_server_2',0,'mor_server_2','SIP',0,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','no','no',NULL,'no',NULL,'rfc2833',NULL,NULL,'mor_server_2',NULL,'no','no','no','never','no',1,'DO NOT EDIT',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,NULL,0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,NULL,0,'udp','no','no',0,0,
'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(20,'mor_server_1','127.0.0.1','','m2','127.0.0.1',5060,0,20,'','mor_server_1',0,'mor_server_1','SIP',0,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','no','no',NULL,'no',NULL,'rfc2833',NULL,NULL,'mor_server_1',NULL,'no','no','no','never','no',1,'DO NOT EDIT',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,0,'yes','yes',0.000000000000000,0,0,0,NULL,0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,NULL,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(21,'ipauthN3CkdVDz','192.168.0.167','','m2','192.168.0.167',5060,0,21,'','10002',0,'','SIP',8,0,0,0,0,'','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','','no',NULL,'no',0,'inband',NULL,NULL,NULL,NULL,'','','port,invite','','',1,'Mano device 2',0,0,'',0,0,0,0,'',NULL,0,'no',10,0,NULL,0,NULL,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,0,'00001','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,''),(22,'ipauthFWFphMaf','192.168.0.167','','m2','192.168.0.167',5060,0,22,'','10003',0,'','SIP',8,0,0,0,0,'','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','','no',NULL,'no',0,'inband',NULL,NULL,NULL,NULL,'','','port,invite','','',1,'asdasd',0,0,'',0,0,0,0,'',NULL,0,'no',10,0,NULL,0,NULL,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,0,'99','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,''),(23,'ipauthhXtNpE9d','192.168.0.167','','mor_local','192.168.0.167',5060,0,23,'','10004',0,'','SIP',8,0,0,0,0,'','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','','no',NULL,'no',0,'inband',NULL,NULL,NULL,NULL,'','','port,invite','','',1,'asdfasdf',0,0,'',0,0,0,0,'',NULL,0,'no',10,0,NULL,0,NULL,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,1,'','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,''),(24,'ipauthnJ5Fkkfz','111.111.111.111','','mor_local','111.111.111.111',5060,0,24,'','10005',0,'','SIP',9,0,0,0,0,'','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','','no',NULL,'no',0,'inband',NULL,NULL,NULL,NULL,'','','port,invite','','',1,'sdfsdf',0,0,'',0,0,0,0,'',NULL,0,'no',10,0,NULL,0,NULL,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,0,0,'','lcr',0,0,500,'.*','',1,1,'',14,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
NULL,NULL,NULL,NULL,NULL,NULL,''),(25,'ipauthHMmkPenB','192.168.0.150','','m2','192.168.0.150',5060,0,25,'','10006',0,'','SIP',9,0,0,0,0,'','all','g729;alaw','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','','no',NULL,'no',0,'inband',NULL,NULL,NULL,NULL,'','','port,invite','','',1,'m2',0,0,'',0,0,0,0,'',NULL,0,'no',10,0,NULL,0,NULL,0,'yes','yes',0.000000000000000,0,0,0,'',0,0,0,'',1,0,'','no','en',0,NULL,0,NULL,0,0,0,0,0,0,0,0,'udp','no','no',0,0,'no',5060,0,0,NULL,0,1,1,'','lcr',2,14,500,'.*','',0,0,'',0,500,'','',NULL,NULL,'friend',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'');

#tariffs
INSERT INTO `tariffs` (`id`, `name`,`purpose`,`owner_id`,`currency`) VALUES (13,'terminator_tariff','provider',0,'USD',1),(14,'originator_tariff','user_wholesale',0,'USD');

#rates
INSERT INTO `rates` (`id`, `tariff_id`, `prefix`, `name`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`) VALUES (822,13,'370','Lithuania proper',5780,NULL,0.000000000000000,NULL),(823,14,'370','Lithuania proper',5780,NULL,0.000000000000000,NULL),(824,13,'3708','Lithuania freephone',5781,NULL,0.000000000000000,NULL),(825,14,'37068','Lithuania Mobile',12487,NULL,0.000000000000000,NULL);

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES (893,'00:00:00','23:59:59',0.300000000000000,0.000000000000000,822,1,0,''),(894,'00:00:00','23:59:59',0.900000000000000,0.000000000000000,823,1,0,''),(895,'00:00:00','23:59:59',0.350000000000000,0.000000000000000,824,1,0,''),(896,'00:00:00','23:59:59',0.220000000000000,0.000000000000000,825,1,0,'');

#calls
INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) VALUES
(382, '2014-06-26 12:04:35', '"37064640097" <37064640097>', '37064640097', '37064641122', '', '', '', '', '', 3, 1, 'ANSWERED', 0, '25', 'e510439c-fd10-11e3-bf7c-97f2d457', '', 25, 16, 0, 0, NULL, 7, 0.3, 1, 0.005, 9, 0.9, 1, 0.015, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '370', 1, 16, 'Local', 0, 0, '37064641122', 0, NULL, '192.168.0.150', '192.168.0.221', 2.234287, 0.9862, 0, 7);
INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) VALUES
(409, '2014-06-27 18:14:31', '"37064640097" <37064640097>', '37064640097', '37064640097', '', '', '', '', '', 11, 10, 'ANSWERED', 0, '8', 'bd72840a-fe0d-11e3-99fb-6d4d5a8b', '', 8, 16, 0, 0, NULL, 7, 0.3, 10, 0.05, 6, 0.9, 10, 0.15, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '370', 1, 16, 'Local', 0, 0, '37064640097', 0, NULL, '192.168.0.108', '192.168.0.74', 10.883024, 10, 0, 7);

INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`, `hide_destination_end`, `warning_email_hour`, `warning_balance_call`, `warning_balance_sound_file_id`, `own_providers`, `ignore_global_monitorings`, `currency_id`, `quickforwards_rule_id`, `spy_device_id`, `time_zone`, `minimal_charge`, `minimal_charge_start_at`, `webphone_allow_use`, `webphone_device_id`, `responsible_accountant_id`, `blacklist_enabled`, `blacklist_lcr`, `routing_threshold`, `pbx_pool_id`, `hide_non_answered_calls`, `balance_min`, `balance_max`, `main_email`, `noc_email`, `billing_email`, `rates_email`, `warning_email_balance_admin`, `warning_email_balance_manager`, `billing_period`, `invoice_grace_period`, `warning_email_sent_admin`, `warning_email_sent_manager`, `comment`, `routing_threshold_2`, `blacklist_lcr_2`, `routing_threshold_3`, `blacklist_lcr_3`, `warning_balance_increases`, `ignore_global_alerts`) VALUES
(6, 'Ricardas', 'f7c3bc1d808e04732adf679965ccc34ca7ae3441', 'user', 0, '', '', 3.000000000000000, 0, 39.806031333333333, 0.000000000000000, 0, 1, 0, 0, 0.000000000000000, '0000-00-00 00:00:00', 0, 0, 1, 8, 0.000000000000000, '', '0000000001', '2014-05-09', '', 123, '', 0.000000000000000, 5, '', 0, 0, 0, '2000-01-01 00:00:00', 'ytj4kanp8h', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2014-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 2, 0, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, 0, 0, 0, 0.0000, 200.0000, '', '', '', '', 0.000000000000000, 0.000000000000000, 'monthly', 15, 0, 0, '', 0, -1, 0, -1, 0, 0),
(7, 'Provider', 'f7c3bc1d808e04732adf679965ccc34ca7ae3441', 'user', 0, '', '', 3.000000000000000, 0, 108.976171000000000, 0.000000000000000, 0, 1, 0, 0, 0.000000000000000, '0000-00-00 00:00:00', 0, 0, 1, 9, 0.000000000000000, '', '0000000002', '2014-05-09', '', 123, '', 0.000000000000000, 6, '', 0, 0, 0, '2000-01-01 00:00:00', 'dx492195ye', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 3, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, 0, 0, 0, 0.0000, 200.0000, '', '', '', '', 0.000000000000000, 0.000000000000000, 'monthly', 15, 0, 0, '', 0, -1, 0, -1, 0, 1),
(8, 'Ricardas_2', 'f7c3bc1d808e04732adf679965ccc34ca7ae3441', 'user', 0, '', '', 3.000000000000000, 0, 87.630000000000000, 0.000000000000000, 0, 1, 0, 0, 0.000000000000000, '0000-00-00 00:00:00', 0, 0, 1, 11, 0.000000000000000, '', '0000000003', '2014-05-09', '', 123, '', 0.000000000000000, 7, '', 0, 0, 0, '2000-01-01 00:00:00', 'xgr1522wv7', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2014-01-01', 15, 0, 0, 0, '', 104, 0, 0.000000000000000, 0, 4, 0, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, 0, 0, 0, 0.0000, 0.0000, '', '', '', '', 0.000000000000000, 0.000000000000000, 'monthly', 15, 0, 0, '', 0, -1, 0, -1, 0, 0),
(9, 'dummy', 'f7c3bc1d808e04732adf679965ccc34ca7ae3441', 'user', 0, '', '', 3.000000000000000, 0, 99.790000000000000, 0.000000000000000, 0, 1, 0, 0, 0.000000000000000, '0000-00-00 00:00:00', 0, 0, 1, 24, 0.000000000000000, '', '0000000004', '2014-06-23', '', 1, '', 0.000000000000000, 8, '', 0, 0, 0, '2000-01-01 00:00:00', '7m24fydrdm', NULL, 1, 0, NULL, NULL, 0, 0, 0, 1, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, '2008-01-01', 15, 0, 0, 0, NULL, 0, 0, 0.000000000000000, 0, 5, 1, 0, -1, -1, 0, 0, 0, 0, 1, 0, 0, 'UTC', 0, NULL, 0, 0, -1, 'global', -1, 0, 0, 0, 0.0000, 0.0000, '', '', '', '', 0.000000000000000, 0.000000000000000, 'monthly', 15, 0, 0, '', 0, -1, 0, -1, 0, 0);
