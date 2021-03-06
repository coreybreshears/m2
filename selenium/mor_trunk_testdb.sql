#ALTER TABLE invoices ADD number_type TINYINT default 1 COMMENT 'invoice number format type';

TRUNCATE `addresses`;
INSERT INTO `addresses` (`id`, `direction_id`, `email`) VALUES (1,1,NULL),(2,123,'test_reseller@email.test'),(3,1,NULL),(4,1,NULL);

TRUNCATE `calls`;
ALTER TABLE `calls` ADD pdd DECIMAL(30,15) DEFAULT 0, ADD src_user_id INT DEFAULT 0, ADD terminated_by ENUM('unknown', 'originator', 'terminator', 'system') DEFAULT NULL, ADD answer_time TIMESTAMP NULL DEFAULT NULL, ADD end_time TIMESTAMP NULL DEFAULT NULL, DROP INDEX src_device_id, DROP INDEX dst_device_id, DROP INDEX src, DROP INDEX provider_id, DROP INDEX disposition, DROP INDEX hgcause, DROP INDEX resellerid, DROP INDEX calldate, ADD INDEX src_device_id_index (src_device_id), ADD INDEX dst_device_id_index (dst_device_id), ADD INDEX server_id_index (server_id), ADD INDEX src_index (src(6)), ADD INDEX dst_index (dst(6)), ADD INDEX localized_dst_index (localized_dst(6)), ADD INDEX prefix_index (prefix(6)), ADD INDEX provider_id_index (provider_id), ADD INDEX disposition_index (disposition), ADD INDEX hangupcause_index (hangupcause), ADD INDEX uniqueid_index (uniqueid(6)), ADD INDEX calldate_index (calldate), ADD INDEX src_user_id_index (src_user_id);
ALTER TABLE calls DROP COLUMN accountcode;
ALTER TABLE calls DROP COLUMN did_price;
ALTER TABLE calls DROP COLUMN card_id;
ALTER TABLE calls DROP COLUMN reseller_id;
ALTER TABLE calls DROP COLUMN reseller_rate;
ALTER TABLE calls DROP COLUMN reseller_billsec;
ALTER TABLE calls DROP COLUMN reseller_price;
ALTER TABLE calls DROP COLUMN partner_id;
ALTER TABLE calls DROP COLUMN partner_rate;
ALTER TABLE calls DROP COLUMN partner_billsec;
ALTER TABLE calls DROP COLUMN partner_price;
ALTER TABLE calls DROP COLUMN callertype;
ALTER TABLE calls DROP COLUMN did_inc_price;
ALTER TABLE calls DROP COLUMN did_prov_price;
ALTER TABLE calls DROP COLUMN did_provider_id;
ALTER TABLE calls DROP COLUMN did_id;
ALTER TABLE calls DROP COLUMN did_billsec;
ALTER TABLE calls DROP COLUMN processed;
ALTER TABLE calls MODIFY COLUMN uniqueid VARCHAR(200);
INSERT INTO `calls`
(`id`, `calldate`          , `clid`               , `src`       , `dst`       ,`channel`, `duration`, `billsec`, `disposition`,  `uniqueid`  , `src_device_id`, `dst_device_id`,    `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`,        `prefix`, `server_id`, `hangupcause`,    `localized_dst`,   `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`)
VALUES
# outgoing 2009-01-01
(9   ,'2009-01-01 00:00:01',''                    ,'101'        ,'123123'     ,''  ,10         ,20        ,'ANSWERED'                         ,'1232113370.3'          ,5               ,0                                              ,1             ,0               ,0                  ,1                ,0         ,0           ,1              ,2                                                                                                                                    ,'1231'   ,1           ,16                                                 ,'123123'                                 ,''              ,''              ,0               ,0              ),
(10  ,'2009-01-01 00:00:02',''                    ,'101'        ,'123123'     ,''  ,20         ,30        ,'ANSWERED'                         ,'1232113371.3'          ,6               ,0                                              ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,3                                                                                                                                    ,'1231'   ,1           ,16                                                 ,'123123'                                 ,''              ,''              ,0               ,0              ),
(11  ,'2009-01-01 00:00:03',''                    ,'101'        ,'123123'     ,''  ,30         ,40        ,'ANSWERED'                         ,'1232113372.3'          ,7               ,0                                              ,1             ,0               ,0                  ,1                ,3         ,0           ,1              ,4                                                                                                                                    ,'1231'   ,1           ,16                                                 ,'123123'                                 ,''              ,''              ,0               ,0              ),
(12  ,'2009-01-01 00:00:04',''                    ,'101'        ,'123123'     ,''  ,40         ,50        ,'ANSWERED'                         ,'1232113373.3'          ,2               ,0                                              ,1             ,0               ,0                  ,1                ,5         ,0           ,1              ,5                                                                                                                                    ,'1231'   ,1           ,16                                                 ,'123123'                                 ,''              ,''              ,0               ,0              ),
# incoming 2009-01-02
# call to admins device
(13  ,'2009-01-02 00:00:01','37046246362'         ,'37046246362','37063042438','' ,10         ,20        ,'ANSWERED'                         ,'1232113374.3'          ,1               ,5                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,2                                                                                                                                    ,'3706'   ,1           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to users device
(14  ,'2009-01-02 00:00:02','37046246362'         ,'37046246362','37063042438','' ,20         ,30        ,'ANSWERED'                         ,'1232113375.3'          ,1               ,4                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,3                                                                                                                                    ,'3706'   ,1           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to resellers device
(15  ,'2009-01-02 00:00:03','37046246362'         ,'37046246362','37063042438','' ,30         ,40        ,'ANSWERED'                         ,'1232113376.3'          ,1               ,6                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,4                                                                                                                                    ,'3706'   ,1           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to resellers users device
(16  ,'2009-01-02 00:00:04','37046246362'         ,'37046246362','37063042438','' ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,1               ,7                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,1           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,99              ),
# incoming 2008-01-01 by did_inc_price
# call to admins device
(17  ,'2008-01-01 00:00:01','37046246362'         ,'37046246362','37063042438','' ,10         ,20        ,'ANSWERED'                         ,'1232113374.3'          ,5               ,0                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,2                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to users device
(18  ,'2008-01-01 00:00:02','37046246362'         ,'37046246362','37063042438','' ,20         ,30        ,'ANSWERED'                         ,'1232113375.3'          ,4               ,0                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,3                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to resellers device
(19  ,'2008-01-01 00:00:03','37046246362'         ,'37046246362','37063042438','' ,30         ,40        ,'ANSWERED'                         ,'1232113376.3'          ,6               ,0                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,4                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# call to resellers users device
(20  ,'2008-01-01 00:00:04','37046246362'         ,'37046246362','37063042438','' ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,7               ,0                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# incoming 2007-01-02
# call to users device for clid test
(21  ,'2007-01-02 00:00:02','"Test" <37046246362>','37046246362','37063042438','',20         ,30        ,'ANSWERED'                         ,'1232113375.3'          ,1               ,4                                              ,1             ,0               ,0                  ,1                ,-1        ,0           ,1              ,3                                                                                                                                    ,'3706'   ,1           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
(22  ,'2010-02-18 00:00:01','37046246362'         ,'37046246362','37063042438','' ,40         ,50        ,'BUSY'                             ,'1232113377.3'          ,2               ,0                                              ,1             ,0               ,0                  ,1                , 2        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
(23  ,'2008-01-01 00:00:04','37046246362'         ,'37046246362','37063042438',''   ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,2               ,0                                              ,1             ,0               ,0                  ,1                , 2        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
(24  ,'2010-02-18 00:00:01','37046246362'         ,'37046246362','37063042438',''  ,40         ,50        ,'BUSY'                             ,'1232113377.3'          ,7               ,0                                              ,1             ,0               ,0                  ,1                , 5        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,88              ),
(25  ,'2010-02-18 00:00:01','37046246362'         ,'37046246362','37063042438',''  ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,7               ,0                                              ,1             ,0               ,0                  ,1                , 5        ,0           ,1              ,5                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
(26  ,'2010-03-17 00:00:01','37046246362'         ,'37046246362','37063042438','' ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,7               ,0                                              ,1             ,0               ,0                  ,5                , 5        ,0           ,1              ,2                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# cards calls
(27  ,'2010-03-17 00:00:01','37046246362'         ,'37046246362','37063042438','' ,40         ,50        ,'ANSWERED'                         ,'1232113377.3'          ,7               ,0                                              ,1             ,0               ,0                  ,5                ,-1        ,0           ,1              ,2                                                                                                                                    ,'3706'   ,0           ,16                                               ,'37063042438'                            ,''              ,''              ,0               ,0              ),
# dst whit #
(28  ,'2010-06-22 00:00:01',''                    ,'101'        ,'123#123'     ,''  ,20         ,30        ,'ANSWERED'                         ,'1232113371.3'          ,6               ,0                                              ,1             ,0               ,0                  ,1                ,2         ,0           ,1              ,3                                                                                                                                    ,'1231'   ,1           ,16                                                 ,'123#123'                                 ,''              ,''              ,0               ,0             );
update `calls` set real_billsec=1;
UPDATE `calls` SET `real_billsec` = '0' WHERE `id` =14;
UPDATE `calls` SET `user_price` = '0' WHERE `id` =22;
UPDATE `calls` SET `duration` = '0',`billsec` = '0',`real_billsec` = '0' WHERE `id` =22 ;
TRUNCATE `devicegroups`;
INSERT INTO `devicegroups` (`id`, `user_id`, `address_id`, `name`, `added`, `primary`) VALUES (1,3,2,'primary','2009-03-31 11:38:55',1),(2,4,3,'primary','2009-03-31 11:39:32',1),(3,5,4,'primary','2009-03-31 11:53:07',1);

DELETE FROM `devices`;

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`) VALUES
# provider
(1, 'prov1','22.33.44.55','unwuqmkw','mor','22.33.44.55',4569,0,1,'','prov_test',0,'test','SIP',-1,0,1,0,0,'no','all','alaw;ulaw;g729;gsm','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','no','no','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# devices for test user with id = 2
(2,'101','127.0.1.1','','mor_local','127.0.1.1',5060,1175892667,2,'\"101\" <101>','101',0,'','SIP',2,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','500','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device #1',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(3,'102','127.0.1.6','','mor_local','127.0.1.6',5060,1175892667,3,'\"102\" <102>','102',0,'','SIP',2,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','500','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test FAX device',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
(4,'1002','127.0.1.2','','mor_local','127.0.1.2',5060,0,4,NULL,'1002',0,'','SIP',2,0,1,0,0,'no','all','alaw;g729','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','1000',NULL,'no',NULL,'rfc2833',0,0,'','','no','no','','no','no',1,'',0,0,'211194',0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for admin
(5,'103','127.0.1.3','','mor_local','127.0.1.3',5060,1175892667,2,'\"103\" <103>','103',0,'','SIP',2,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','500','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Admin',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for reseller
(6,'104','127.0.1.4','','mor_local','127.0.1.4',5060,1175892667,2,'\"104\" <104>','104',0,'','SIP',5,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','500','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Reseller',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL),
# device for resellers user
(7,'105','127.0.1.5','','mor_local','127.0.1.5',5060,1175892667,2,'\"105\" <105>','105',0,'','SIP',5,0,1,0,0,'no','all','all','0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes','500','','no',NULL,'rfc2833',NULL,NULL,NULL,NULL,'no','no','no','never','no',1,'Test Device for Resellers User',0,0,NULL,0,0,60,60,'no',NULL,0,'no',60,0,NULL,0,0,'yes','yes',0,0,0,0,NULL);

TRUNCATE `extlines`;
INSERT INTO `extlines` (`id`, `context`, `exten`, `priority`, `app`, `appdata`, `device_id`) VALUES (1,'mor','556',1,'ChanSpy','IAX2|q',0),(15,'mor_local','101',1,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?2:4',1),(16,'mor_local','101',2,'Set','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',1),(17,'mor_local','101',3,'Goto','101|5',1),(18,'mor_local','101',4,'Set','CALLED_TO=${EXTEN}',1),(19,'mor_local','101',5,'NoOp','MOR starts',1),(20,'mor_local','101',6,'GotoIf','$[${LEN(${CALLERID(NAME)})} > 0]?9:7',1),(21,'mor_local','101',7,'GotoIf','$[${LEN(${mor_cid_name})} > 0]?8:9',1),(22,'mor_local','101',8,'Set','CALLERID(NAME)=${mor_cid_name}',1),(23,'mor_local','101',9,'Dial','IAX2/101',1),(24,'mor_local','101',10,'GotoIf','$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]?301',1),(25,'mor_local','101',11,'Hangup','',1),(26,'mor_local','101',209,'Background','busy',1),(27,'mor_local','101',210,'Busy','10',1),(28,'mor_local','101',211,'Hangup','',1),(29,'mor_local','101',301,'Ringing','',1),(30,'mor_local','101',302,'Wait','120',1),(31,'mor_local','101',303,'Hangup','',1),(36,'mor','BUSY',1,'Busy','10',0),(37,'mor','BUSY',2,'Hangup','',0),(40,'mor','FAILED',1,'Congestion','4',0),(41,'mor','FAILED',2,'Hangup','',0),(42,'mor_local','*89',1,'VoiceMailMain','',0),(43,'mor_local','*89',2,'Hangup','',0),(44,'mor','fax',1,'Goto','mor_fax2email|123|1',0),(45,'mor_local','102',1,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?2:4',2),(46,'mor_local','102',2,'NoOp','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',2),(47,'mor_local','102',3,'Goto','102|5',2),(48,'mor_local','102',4,'Set','CALLED_TO=${EXTEN}',2),(49,'mor_local','102',5,'Set','MOR_FAX_ID=2',2),(50,'mor_local','102',6,'Set','FAXSENDER=${CALLERID(number)}',2),(51,'mor_local','102',7,'Goto','mor_fax2email|${EXTEN}|1',2),(52,'mor_local','102',401,'NoOp','NO ANSWER',2),(53,'mor_local','102',402,'Hangup','',2),(54,'mor_local','102',201,'NoOp','BUSY',2),(55,'mor_local','102',202,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?203:BUSY|1',2),(56,'mor_local','102',203,'Busy','1',2),(57,'mor_local','102',301,'NoOp','FAILED',2),(58,'mor_local','102',302,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?303:FAILED|1',2),(59,'mor_local','102',303,'Congestion','1',2),(60,'mor_local','*97',1,'AGI','mor_acc2user',0),(61,'mor_local','*97',2,'VoiceMailMain','s${MOR_EXT}',0),(62,'mor_local','*97',3,'Hangup','',0),(63,'mor','fax',1,'Goto','mor_fax2email|123|1',0),(64,'mor_local','_X.',1,'Goto','mor|${EXTEN}|1',0),(65,'mor_local','_*X.',1,'Goto','mor|${EXTEN}|1',0),(74,'mor_voicemail','_X.',1,'VoiceMail','${EXTEN}|${MOR_VM}',0),(75,'mor_voicemail','_X.',2,'Hangup','',0),(76,'mor','HANGUP',1,'Hangup','',0),(77,'mor','HANGUP_NOW',1,'Hangup','',0),(78,'mor','_X.',1,'NoOp','MOR starts',0),(79,'mor','_X.',2,'Set','TIMEOUT(response)=20',0),(80,'mor','_X.',3,'Set','TIMEOUT(digit)=10',0),(81,'mor','_X.',4,'mor','${EXTEN}',0),(82,'mor','_X.',5,'GotoIf','$[\"${MOR_CARD_USED}\" != \"\"]?mor_callingcard|s|1',0),(83,'mor','_X.',6,'GotoIf','$[\"${MOR_TRUNK}\" = \"1\"]?HANGUP_NOW|1',0),(84,'mor','_X.',7,'GotoIf','$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"] | $[\"${DIALSTATUS}\" = \"CONGESTION\"]]?FAILED|1',0),(85,'mor','_X.',8,'GotoIf','$[\"${DIALSTATUS}\" = \"BUSY\"]?BUSY|1:HANGUP|1',0),(86,'mor_local','1002',1,'NoOp','${MOR_MAKE_BUSY}',4),(87,'mor_local','1002',2,'GotoIf','$[\"${MOR_MAKE_BUSY}\" = \"1\"]?201',4),(88,'mor_local','1002',3,'GotoIf','$[${LEN(${CALLED_TO})} > 0]?4:6',4),(89,'mor_local','1002',4,'NoOp','CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}',4),(90,'mor_local','1002',5,'Goto','1002|7',4),(91,'mor_local','1002',6,'Set','CALLED_TO=${EXTEN}',4),(92,'mor_local','1002',7,'NoOp','MOR starts',4),(93,'mor_local','1002',8,'GotoIf','$[${LEN(${CALLERID(NAME)})} > 0]?11:9',4),(94,'mor_local','1002',9,'GotoIf','$[${LEN(${mor_cid_name})} > 0]?10:11',4),(95,'mor_local','1002',10,'Set','CALLERID(NAME)=${mor_cid_name}',4),(96,'mor_local','1002',11,'Dial','IAX2/1002|60',4),(97,'mor_local','1002',12,'GotoIf','$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?301',4),(98,'mor_local','1002',13,'GotoIf','$[\"${DIALSTATUS}\" = \"BUSY\"]?201',4),(99,'mor_local','1002',14,'GotoIf','$[\"${DIALSTATUS}\" = \"NOANSWER\"]?401',4),(100,'mor_local','1002',15,'Hangup','',4),(101,'mor_local','1002',401,'NoOp','NO ANSWER',4),(102,'mor_local','1002',402,'Hangup','',4),(103,'mor_local','1002',201,'NoOp','BUSY',4),(104,'mor_local','1002',202,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?203:mor|BUSY|1',4),(105,'mor_local','1002',203,'Busy','10',4),(106,'mor_local','1002',301,'NoOp','FAILED',4),(107,'mor_local','1002',302,'GotoIf','${LEN(${MOR_CALL_FROM_DID}) = 1}?303:mor|FAILED|1',4),(108,'mor_local','1002',303,'Congestion','4',4);

;TRUNCATE `tariffs`;
;INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES (1,'Test Tariff','provider',0,'USD'),(2,'Test Tariff for Users','user_wholesale',0,'USD'),(3,'tariff','user',3,'USD'),(4,'Test Tariff + 0.1','user',0,'USD');
INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES (5,'Test Tariff bad currency','provider',0,'AAA');

TRUNCATE `users`;
INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`) VALUES
(0,'admin','6c7ca345f63f835cb353ff15bd6c5e052ec08e7a','admin',1,'System','Admin',3,0,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,'','','2007-03-26','',1,'',18,1,'',0,0,0,'2000-01-01 00:00:00','hfttv7bcqt'          ,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(2,'user_admin','8213544f82d739dbc044b7e3f6ed343b3bc7e543','user',0,'Test User','#1',3,1,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,NULL,NULL,NULL,NULL,NULL,NULL,18,NULL,NULL,0,0,0,'2000-01-01 00:00:00',NULL             ,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(3,'reseller','91dec0f4d00fadb39bf733c5418e9af2151624c6','reseller',0,'Test','Reseller',3,0,0,0,1,1,0,4,0,NULL,0,0,1,0,-1,'','0000000001','2009-03-31','',123,'',19,2,'',0,0,0,'2000-01-01 00:00:00','qg2audn8qa'        ,NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,1,1,0),
(4,'accountant','ed05464507ccc00676ed0b32267ad4ece385c119','accountant',0,'Test','Accountant',3,0,0,0,1,1,0,2,0,NULL,0,0,1,0,-1,'','0000000002','2009-03-31','',123,'',0,3,'',0,0,0,'2000-01-01 00:00:00',NULL           ,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,2,1,0),
(5,'user_reseller','6a9f8db8df3143d212fe44572d51576c66b0dca7','user',0,'User','Resellers',3,0,0,0,1,1,0,3,0,NULL,0,0,1,0,-1,'','0000000003','2009-03-31','',1,'',19,4,'',3,0,0,'2000-01-01 00:00:00',NULL                ,NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,3,1,0);
UPDATE users SET id = 0 WHERE username = 'admin';

TRUNCATE `activecalls`;
INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`, `active`) VALUES
  (1,    2,           '1249296551.111095',NOW(),        NULL,          NULL,            '306984327343','63727007889',5,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       0,         0,          '63727007889', 1),
  (2,    1,           '1249298495.111725',NOW()+INTERVAL 1 SECOND,      NULL,          NULL,            '306984327344','63727007885',5,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       0,         0,          '63727007885', 1),
  (3,    1,           '1249298495.111726',NOW()+INTERVAL 2 SECOND,      NULL,          NULL,            '306984327345','63727007886',2,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       2,         0,          '63727007886', 1),
  (4,    1,           '1249298495.111727',NOW()+INTERVAL 3 SECOND,      NULL,          NULL,            '306984327347','63727007887',7,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     2,              0,       5,         3,          '63727007887', 1);

# Email configuration
UPDATE conflines SET value = "randomserver" WHERE NAME = "Email_Smtp_Server";
UPDATE conflines SET value = "kolmitest998" WHERE NAME = "Email_Login";
UPDATE conflines SET value = "ocean9" WHERE NAME = "Email_Password";
UPDATE conflines SET value = "0" WHERE NAME = "Email_Sending_Enabled";

TRUNCATE `actions`;
INSERT INTO `actions`
(`id`, `user_id`, `date`,               `action`,   `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(1,    0,         '2010-01-01 00:00:01','test_time','',     '',      0,           'user',        0,           NULL,    NULL),
(2,    0,         '2010-01-01 23:59:58','test_time','',     '',      0,           'user',        0,           NULL,    NULL);

# test-production identification
INSERT INTO conflines(name,value) VALUES("test_production_environment", "true");

DELETE FROM `emails` WHERE name = 'calling_cards_data_to_paypal';
INSERT INTO `emails` VALUES (6,'calling_cards_data_to_paypal','Calling Card purchase','2009-04-21 11:42:50','<%= cc_purchase_details %>',1,'html',0,0,0,'');


UPDATE users SET blocked = 0 WHERE id = 2;

INSERT INTO `conflines` (name, value, owner_id) VALUES ('System_time_zone_ofset', '0', '0');
INSERT INTO `conflines` (name, value, owner_id) VALUES ('Invoice_Number_Type', '1', 3);

update servers set active=0;
UPDATE `mor`.`servers` SET `gui` = '1',`db` = '1',`core` = '1' WHERE `servers`.`id` =1 LIMIT 1 ;
UPDATE servers SET server_type = 'freeswitch' WHERE server_type = 'asterisk';

#sync data
UPDATE calls JOIN devices ON calls.dst_device_id = devices.id SET calls.dst_user_id = devices.user_id;

Update users set time_zone = 'Vilnius';
#INSERT INTO conflines (name, value) SELECT 'AD_sounds_path', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'AD_sounds_path');
UPDATE `conflines` SET `value` = '192.168.1.8' WHERE `name` ='Asterisk_Server_IP';
INSERT INTO conflines (name, value) SELECT 'CC_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'CC_Active');
INSERT INTO conflines (name, value) SELECT 'RS_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'RS_Active');
INSERT INTO conflines (name, value) SELECT 'RSPRO_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'RSPRO_Active');
INSERT INTO conflines (name, value) SELECT 'SMS_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'SMS_Active');
INSERT INTO conflines (name, value) SELECT 'REC_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'REC_Active');
INSERT INTO conflines (name, value) SELECT 'PG_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'PG_Active');
INSERT INTO conflines (name, value) SELECT 'MA_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'MA_Active');
INSERT INTO conflines (name, value) SELECT 'CS_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'CS_Active');
INSERT INTO conflines (name, value) SELECT 'CC_Single_Login', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'CC_Single_Login');
INSERT INTO conflines (name, value) SELECT 'PROVB_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'PROVB_Active');
INSERT INTO conflines (name, value) SELECT 'AST_18', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'AST_18');
INSERT INTO conflines (name, value) SELECT 'WP_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'WP_Active');
INSERT INTO conflines (name, value) SELECT 'PBX_Active', '1' FROM dual WHERE NOT EXISTS (SELECT * FROM conflines where name = 'PBX_Active');
INSERT INTO conflines (name, value) VALUES ('Default_device_server', '1');

# x5_functionality_1 yra CD: Distributor with PIN touch
insert into conflines (name, value) VALUES ('x5_functionality_1', '1');
#x5_functionality_9 yra reratinimas per c scripta
insert into conflines (name, value) VALUES ('x5_functionality_9', '1');

# komanda skirta admino ir reselerio devaisams uzblokuoti, padarant devaisu ip 0.0.0.0
UPDATE devices SET ipaddr='0.0.0.0', name=CONCAT('ipauth', SUBSTR(md5(RAND()), 1, 10)) WHERE user_id IN (SELECT id FROM users WHERE usertype = 'reseller' OR usertype='admin') AND name NOT LIKE 'ipauth%' AND name NOT LIKE 'mor_server%';

DELETE FROM conflines WHERE name LIKE 'Cell_m2_invoice%';
INSERT INTO conflines (name, value) VALUES
('Cell_m2_invoice_number', 'D2'),
('Cell_m2_invoice_issue_date', 'H2'),
('Cell_m2_invoice_period_start', 'E6'),
('Cell_m2_invoice_period_end', 'H6'),
('Cell_m2_invoice_client_name', 'G5'),
('Cell_m2_invoice_due_date', 'H5'),
('Cell_m2_invoice_client_details1', 'G6'),
('Cell_m2_invoice_client_details2', 'G7'),
('Cell_m2_invoice_client_details3', 'G8'),
('Cell_m2_invoice_client_details4', 'G9'),
('Cell_m2_invoice_client_details5', 'G10'),
('Cell_m2_invoice_client_details6', 'G11'),
('Cell_m2_invoice_lines_destination', 'B13'),
('Cell_m2_invoice_lines_name', 'C13'),
('Cell_m2_invoice_lines_calls', 'F13'),
('Cell_m2_invoice_lines_nice_total_time', 'H13'),
('Cell_m2_invoice_lines_nice_price', 'I13'),
('Cell_m2_invoice_lines_destination_number', 'A13'),
('Cell_m2_invoice_nice_total_amount', 'A4'),
('Cell_m2_invoice_nice_total_amount_with_tax', 'A5'),
('Cell_m2_invoice_exchange_rate', 'A3'),
('Cell_m2_invoice_comment', 'A2'),
('Cell_m2_invoice_timezone', 'A1');

INSERT INTO conflines (name, value) VALUES ('ES_IP', '192.168.0.34');

#update devices
INSERT IGNORE INTO `routing_groups` (`id`,`comment`, `name`) VALUES (12001,'', 'Test RG');
update devices set op= 1, op_routing_group_id = 12001, op_tariff_id=2 where user_id>0;
update devices set tp= 1, tp_tariff_id=1 where user_id<0;


#update users
update users set lcr_id=0;

INSERT INTO conflines (id,name, value) VALUES (150000,'TEST_DB_Update_From_Script', 1);
