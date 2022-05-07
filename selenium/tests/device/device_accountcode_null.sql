INSERT INTO `devices` (`id`, `name`, `host`  , `secret`, `context` , `ipaddr`, `port`     , `regseconds`, `accountcode` , `callerid`    , `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`         , `deny`          , `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`                  , `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`)
VALUES                (8   ,'108'  ,'dynamic','10887654'    ,'mor_local','0.22.0.0',02           ,1175892667   ,0              ,'\"108\" <108>','108'       ,0                  ,'108'      ,'IAX2'        ,2         ,0               ,1                ,0                  ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500' ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'    ,'no'             ,1              ,'Test Device for User'          ,0             ,0         ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL),
                      (9   ,'109'  ,'dynamic','10986754'    ,'mor_local','0.0.22.0',03           ,1175892667   ,0              ,'\"109\" <109>','109'       ,0                  ,'109'      ,'SIP'         ,4         ,0               ,1                ,0                  ,0            ,'no'     ,'all'      ,'all'      ,'0.0.0.0/0.0.0.0','0.0.0.0/0.0.0.0','yes'    ,'500' ,''        ,'no'          ,NULL          ,'rfc2833'        ,NULL       ,NULL        ,NULL          ,NULL       ,'no'         ,'no'        ,'no'       ,'never'    ,'no'             ,1              ,'Test Device for Accountant'    ,0             ,0         ,NULL            ,0     ,0              ,60          ,60                     ,'no'                 ,NULL          ,0           ,'no'  ,60             ,0         ,NULL                  ,0              ,0                       ,'yes'        ,'yes'       ,0               ,0         ,0            ,0                    ,NULL);

INSERT INTO `server_devices` (`id`, `device_id`, `server_id`) VALUES
(8, 8, 1);
