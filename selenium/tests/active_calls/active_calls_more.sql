UPDATE `activecalls` SET `start_time` = NOW();
UPDATE `activecalls` SET `dst_device_id` = 4, `provider_id` = 2 WHERE `src_device_id` = 7;
UPDATE `activecalls` SET `dst_device_id` = 7, `provider_id` = 5, `user_id` = 2 WHERE `src_device_id` != 7;

INSERT INTO `activecalls`
 (`id`,`server_id`, `uniqueid`, `start_time`, `answer_time`, `transfer_time`, `src`, `dst`, `src_device_id`, `dst_device_id`, `channel`, `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`, `active`) VALUES
 (100, 1, '1249298495.111727',DATE_SUB(NOW(), INTERVAL 10 SECOND),DATE_SUB(NOW(), INTERVAL 5 SECOND), NULL,'37060011221','123123' ,2, 6, 'SIP/10.219.62.200-c40daf10' ,'', '1231', 5, 11, 2, 0, '37060011230',1),
 (110, 1, '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND), NULL,'37060011225','37060011242',2, 6, 'SIP/10.219.62.200-c40daf10' ,'', '370' , 5, 15, 2, 0, '37060011242',1),
 (102, 1, '1249298495.111727',DATE_SUB(NOW(), INTERVAL 90 SECOND),DATE_SUB(NOW(), INTERVAL 70 SECOND), NULL,'37060011238','37060011226',4, 6, 'SIP/10.219.62.200-c40daf10' ,'', '370' , 5, 28, 2, 0, '37060011226',1),
 (103, 1, '1249298495.111727',DATE_SUB(NOW(), INTERVAL 130 SECOND),DATE_SUB(NOW(), INTERVAL 100 SECOND), NULL,'37060011234','123123' ,6, 2, 'SIP/10.219.62.200-c40daf10' ,'', '1231', 2, 24, 5, 3, '37060011239',1),
 (140, 1, '1249298495.111727',DATE_SUB(NOW(), INTERVAL 170 SECOND),DATE_SUB(NOW(), INTERVAL 140 SECOND), NULL,'37060011233','37060011223',6, 2, 'SIP/10.219.62.200-c40daf10' ,'', '370' , 2, 23, 5, 3, '37060011223',1);

INSERT INTO `activecalls`
 (`id`, `server_id`, `uniqueid`, `start_time` , `answer_time`, `transfer_time` , `src`, `dst`, `src_device_id`, `dst_device_id`, `channel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`, `active`) VALUES
 (5, 1, '1249298495.111727',NOW()+3 , NOW(), NULL, '306984327347','63727007887',7, 4, 'SIP/10.219.62.200-c40daf10', '63', 2, 1, 5, 3, '63727007887',1),
 (11, 2, '1249298495.111727','2010-15-50 03:30:11', NOW()+2, NULL, '306984327347','63727007887',7, 5, 'SIP/10.219.62.200-c40daf10',NULL, 2, 1, 5, 3, '63727007886',1);

UPDATE `devices` SET `tp` = 1, `tp_active` = 1, `tp_tariff_id` = 1 WHERE id IN (2, 4, 5, 6, 7);
