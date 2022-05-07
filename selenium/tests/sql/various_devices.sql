#Devices
INSERT INTO `devices` 
(`id`, `name`, `host`  , `secret`, `context` , `ipaddr`, `port`     , `regseconds`, `accountcode` , `callerid`    , `extension`, `voicemail_active`, `username`    , `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`         , `deny`          , `permit`    , `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`     , `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `op`, `op_active`, `tp`, `tp_active`, `op_routing_group_id`, `op_tariff_id`, `tp_tariff_id`)
VALUES                
(10  ,'110'  ,'host_110','1101dfgh','mor_local','0.0.0.1',0           ,1175892667   ,10             ,'\"110\" <110>','110'       ,0                  ,'admin'        ,'SIP'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'bsd45'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(11  ,'111'  ,'host_111','1111dfgh','mor_local','0.0.1.0',0           ,1175892667   ,11             ,'\"111\" <111>','111'       ,0                  ,'admin'        ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(12  ,'112'  ,'host_112','1121dfgh','mor_local','0.1.0.0',0           ,1175892667   ,12             ,'\"112\" <112>','112'       ,0                  ,'admin'        ,'SIP'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(13  ,'113'  ,'host_113','1131dfgh','mor_local','1.0.0.0',0           ,1175892667   ,13             ,'\"113\" <113>','113'       ,0                  ,'admin'        ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(14  ,'114'  ,'host_114','1141dfgh','mor_local','0.0.0.2',0           ,1175892667   ,14             ,'\"114\" <114>','114'       ,0                  ,'admin'        ,'SIP'     ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1dfg5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(15  ,'115'  ,'host_115','1151dfgh','mor_local','0.0.2.0',0           ,1175892667   ,15             ,'\"115\" <115>','115'       ,0                  ,'admin'        ,'SIP'       ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(16  ,'116'  ,'host_116','1161dfgh','mor_local','0.2.0.0',0           ,1175892667   ,16             ,'\"116\" <116>','116'       ,0                  ,'admin'        ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(17  ,'117'  ,'host_117','1171dfgh','mor_local','2.0.0.0',0           ,1175892667   ,17             ,'\"117\" <117>','117'       ,0                  ,'101'          ,'IAX2'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'43345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 0, 0, 12001, 2, 2),
(18  ,'118'  ,'host_118','1181dfgh','mor_local','0.0.0.3',0           ,1175892667   ,18             ,'\"118\" <118>','118'       ,0                  ,'101'          ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(19  ,'119'  ,'host_119','1191dfgh','mor_local','0.0.3.0',0           ,1175892667   ,19             ,'\"119\" <119>','119'       ,0                  ,'101'          ,'H323'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,''              ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 0, 0, 1, 1, 12001, 2, 2),
(20  ,'120'  ,'host_120','1201dfgh','mor_local','0.3.0.0',0           ,1175892667   ,20             ,'\"120\" <120>','120'       ,0                  ,'101'          ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(21  ,'121'  ,'host_121','1211dfgh','mor_local','3.0.0.0',0           ,1175892667   ,21             ,'\"121\" <121>','121'       ,0                  ,'101'          ,'Virtual'     ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1dfv5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(22  ,'122'  ,'host_122','1221dfgh','mor_local','0.0.0.4',0           ,1175892667   ,22             ,'\"122\" <122>','122'       ,0                  ,'101'          ,'SIP'       ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(23  ,'123'  ,'host_123','1231dfgh','mor_local','0.0.4.0',0           ,1175892667   ,23             ,'\"123\" <123>','123'       ,0                  ,'101'          ,'FAX'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'d2345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(24  ,'124'  ,'host_124','1241dfgh','mor_local','0.4.0.0',0           ,1175892667   ,24             ,'\"124\" <124>','124'       ,0                  ,'reseller'     ,'IAX2'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1df5'          ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 0, 1, 0, 12001, 2, 2),
(25  ,'125'  ,'host_125','1251dfgh','mor_local','4.0.0.0',0           ,1175892667   ,25             ,'\"125\" <125>','125'       ,0                  ,'reseller'     ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 0, 0, 12001, 2, 2),
(26  ,'126'  ,'host_126','1261dfgh','mor_local','0.0.0.5',0           ,1175892667   ,26             ,'\"126\" <126>','126'       ,0                  ,'reseller'     ,'H323'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(27  ,'127'  ,'host_127','1271dfgh','mor_local','0.0.5.0',0           ,1175892667   ,27             ,'\"127\" <127>','127'       ,0                  ,'reseller'     ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12345'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 0, 0, 1, 1, 12001, 2, 2),
(28  ,'128'  ,'host_128','1281dfgh','mor_local','0.5.0.0',0           ,1175892667   ,28             ,'\"128\" <128>','128'       ,0                  ,'reseller'     ,'Virtual'     ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 0, 0, 12001, 2, 2),
(29  ,'129'  ,'host_129','1291dfgh','mor_local','5.0.0.0',0           ,1175892667   ,29             ,'\"129\" <129>','129'       ,0                  ,'reseller'     ,'SIP'       ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'dfg45'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(30  ,'130'  ,'host_130','1301dfgh','mor_local','0.0.0.6',0           ,1175892667   ,30             ,'\"130\" <130>','130'       ,0                  ,'reseller'     ,'FAX'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(31  ,'131'  ,'host_131','1311dfgh','mor_local','0.0.6.0',0           ,1175892667   ,31             ,'\"131\" <131>','131'       ,0                  ,'accountant'   ,'IAX2'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1il5'          ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 0, 0, 1, 1, 12001, 2, 2),
(32  ,'132'  ,'host_132','1321dfgh','mor_local','0.6.0.0',0           ,1175892667   ,32             ,'\"132\" <132>','132'       ,0                  ,'accountant'   ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,''              ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(33  ,'133'  ,'host_133','1331dfgh','mor_local','6.0.0.0',0           ,1175892667   ,33             ,'\"133\" <133>','133'       ,0                  ,'accountant'   ,'H323'        ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1qwe5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 0, 0, 12001, 2, 2),
(34  ,'134'  ,'host_134','1341dfgh','mor_local','0.0.0.7',0           ,1175892667   ,34             ,'\"134\" <134>','134'       ,0                  ,'accountant'   ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12hkv'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(35  ,'135'  ,'host_135','1351dfgh','mor_local','0.0.7.0',0           ,1175892667   ,35             ,'\"135\" <135>','135'       ,0                  ,'accountant'   ,'SIP'     ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1aji'          ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(36  ,'136'  ,'host_136','1361dfgh','mor_local','0.7.0.0',0           ,1175892667   ,36             ,'\"136\" <136>','136'       ,0                  ,'accountant'   ,'SIP'       ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12wqrty'       ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(37  ,'137'  ,'host_137','1371dfgh','mor_local','7.0.0.0',0           ,1175892667   ,37             ,'\"137\" <137>','137'       ,0                  ,'109'          ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1212d5'        ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 0, 1, 0, 12001, 2, 2),
(38  ,'138'  ,'host_138','1381dfgh','mor_local','0.0.0.8',0           ,1175892667   ,38             ,'\"138\" <138>','138'       ,0                  ,'user_reseller','IAX2'        ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'98y45'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(39  ,'139'  ,'host_139','1391dfgh','mor_local','0.0.8.0',0           ,1175892667   ,39             ,'\"139\" <139>','139'       ,0                  ,'user_reseller','SIP'         ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'12dfg'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 0, 0, 1, 1, 12001, 2, 2),
(40  ,'140'  ,'host_140','1401dfgh','mor_local','0.8.0.0',0           ,1175892667   ,40             ,'\"140\" <140>','140'       ,0                  ,'user_reseller','H323'        ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1wr45'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(41  ,'141'  ,'host_141','1411dfgh','mor_local','8.0.0.0',0           ,1175892667   ,41             ,'\"141\" <141>','141'       ,0                  ,'user_reseller','ZAP'         ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'kgtr5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 0, 1, 0, 12001, 2, 2),
(42  ,'142'  ,'host_142','1421dfgh','mor_local','0.0.0.9',0           ,1175892667   ,42             ,'\"142\" <142>','142'       ,0                  ,'user_reseller','Virtual'     ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(43  ,'143'  ,'host_143','1431dfgh','mor_local','0.0.8.9',0           ,1175892667   ,43             ,'\"143\" <143>','143'       ,0                  ,'user_reseller','SIP'       ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1rgf5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(44  ,'144'  ,'host_144','1441dfgh','mor_local','0.9.0.0',0           ,1175892667   ,44             ,'\"144\" <144>','144'       ,0                  ,'user_reseller','FAX'         ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(45  ,'145'  ,'host_145','1451dfgh','mor_local','0.0.9.0',0           ,1175892667   ,45             ,'\"145\" <145>','145'       ,0                  ,'admin'        ,'SIP'         ,0         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(46  ,'146'  ,'host_146','146','mor_local','9.0.0.0',0           ,1175892667   ,46             ,'\"146\" <146>','146'       ,0                  ,'101'          ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'1jet45'        ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(47  ,'147'  ,'host_147','1471dfgh','mor_local','0.2.0.2',0           ,1175892667   ,47             ,'\"147\" <147>','147'       ,0                  ,'reseller'     ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(48  ,'148'  ,'host_148','1481dfgh','mor_local','0.0.3.2',0           ,1175892667   ,48             ,'\"148\" <148>','148'       ,0                  ,'accountant'   ,'SIP'         ,2         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,'167g5'         ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 1, 1, 1, 1, 12001, 2, 2),
(49  ,'149'  ,'host_149','1491dfgh','mor_local','0.5.0.1',0           ,1175892667   ,49             ,'\"149\" <149>','149'       ,0                  ,'user_reseller','SIP'         ,5         ,0                ,1                  ,0            ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500'      ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'         ,'no'             ,1              ,''            ,0             ,0           ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL, 0, 0, 0, 0, '', 0, 0);


update devices set device_type='SIP';
update devices set op= 1 and op_routing_group_id=12001 where user_id>0;
update devices set tp= 1 where user_id<0;

INSERT INTO `server_devices` (`device_id`, `server_id`) VALUES
(10, 1),
(11, 1),
(12, 1),
(13, 1),
(14, 1),
(15, 1),
(16, 1),
(17, 1),
(18, 1),
(19, 1),
(20, 1),
(21, 1),
(22, 1),
(23, 1),
(24, 1),
(25, 1),
(26, 1),
(27, 1),
(28, 1),
(29, 1),
(30, 1),
(31, 1),
(32, 1),
(33, 1),
(34, 1),
(35, 1);