INSERT INTO `providers`(`id`,`name`          ,`tech`,`login`,`password`,`server_ip`,`port`,`priority`,`quality`,`tariff_id`,`cut_a`,`cut_b`,`device_id`,`terminator_id`, `user_id`)
VALUES                 (  2 , 'provider_id_2','SIP' ,'pro2' ,'aredfkjh','0.2.0.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,         8 ,             1 ,        0 ),
                       (  3 , 'provider_id_3','SIP' ,'pro3' ,'trytbrsh','0.0.2.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,         9 ,             1 ,        0 ),
                       (  4 , 'provider_id_4','SIP' ,'pro4' ,'oikjuhhy','0.0.0.2'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,        10 ,             2 ,        0 ),
                       (  5 , 'provider_id_5','SIP' ,'pro5' ,'iuhynbtr','0.4.0.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,        11 ,             2 ,        0 ),
                       (  6 , 'provider_id_6','SIP' ,'pro6' ,'jmnfdtet','5.0.0.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,        12 ,             3 ,        0 ),
                       (  7 , 'provider_id_7','SIP' ,'pro7' ,'iuhyyutr','0.6.0.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,        13 ,             3 ,        0 ),
                       (  8 , 'provider_id_8','SIP' ,'pro8' ,'jmnyutet','0.0.7.0'  ,'5060',        1 ,       1 ,         1 ,     0 ,     0 ,        14 ,             3 ,        0 );
INSERT INTO `calls` 
(`id`, `calldate`          , `clid`               , `src`       , `dst`       , `channel`, `duration`, `billsec`, `disposition`, `accountcode`, `uniqueid`   , `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`,`real_duration`, `real_billsec`,`provider_id`,`prefix`)
VALUES
# outgoing 2009-01-01
(1119 ,'2009-01-01 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,10         ,20        ,'ANSWERED'    ,'2'           ,'1232113370.3',5               ,0               ,0           ,0           ,0         ,0               ,0             ,2            ,'370'),
(110  ,'2009-01-01 00:00:02','37046246362'        ,'37046246362','37063042438',''        ,20         ,30        ,'ANSWERED'    ,'2'           ,'1232113371.3',6               ,0               ,0           ,0           ,0         ,0               ,0             ,3            ,'370'),
(111  ,'2009-01-01 00:00:03','37046246362'        ,'37046246362','37063042438',''        ,30         ,40        ,'ANSWERED'    ,'2'           ,'1232113372.3',7               ,0               ,0           ,0           ,0         ,0               ,0             ,4            ,'370'),
(112  ,'2009-01-01 00:00:04','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113373.3',2               ,0               ,0           ,0           ,0         ,0               ,0             ,5            ,'370'),
# incoming 2009-01-02
# call to admins device
(113  ,'2009-01-02 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,10         ,20        ,'ANSWERED'    ,'2'           ,'1232113374.3',1               ,5               ,0           ,1           ,0         ,0               ,0             ,6            ,'370'),
# call to users device
(114  ,'2009-01-02 00:00:02','37046246362'        ,'37046246362','37063042438',''        ,20         ,30        ,'ANSWERED'    ,'2'           ,'1232113375.3',1               ,4               ,0           ,1           ,0         ,0               ,0             ,7            ,'370'),
# call to resellers device
(115  ,'2009-01-02 00:00:03','37046246362'        ,'37046246362','37063042438',''        ,30         ,40        ,'ANSWERED'    ,'2'           ,'1232113376.3',1               ,6               ,0           ,1           ,0         ,0               ,0             ,8            ,'370'),
# call to resellers users device
(116  ,'2009-01-02 00:00:04','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',1               ,7               ,0           ,1           ,0         ,0               ,0             ,2            ,'370'),
# call to admins device
(117  ,'2008-01-01 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,10         ,20        ,'ANSWERED'    ,'2'           ,'1232113374.3',5               ,0               ,0           ,0           ,0         ,0               ,0             ,3            ,'370'),
# call to users device
(118  ,'2008-01-01 00:00:02','37046246362'        ,'37046246362','35563042438',''        ,20         ,30        ,'ANSWERED'    ,'2'           ,'1232113375.3',4               ,0               ,0           ,0           ,0         ,0               ,0             ,4            ,'355'),
# call to resellers device
(119  ,'2008-01-01 00:00:03','37046246362'        ,'37046246362','37063042438',''        ,30         ,40        ,'ANSWERED'    ,'2'           ,'1232113376.3',6               ,0               ,0           ,0           ,0         ,0               ,0             ,5            ,'370'),
# call to resellers users device
(120  ,'2008-01-01 00:00:04','37046246362'        ,'37046246362','9363042438',''         ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',7               ,0               ,0           ,0           ,0         ,0               ,0             ,6            ,'93'),
# incoming 2007-01-02
# call to users device for clid test
(121  ,'2007-01-02 00:00:02','"Test"<37046246362>','37046246362','37063042438',''        ,20         ,30        ,'ANSWERED'    ,'2'           ,'1232113375.3',1               ,4               ,0           ,1           ,0         ,0               ,0             ,7            ,'370'),
(122  ,'2010-02-18 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'BUSY'        ,'2'           ,'1232113377.3',2               ,0               ,0           ,0           ,0         ,0               ,0             ,8            ,'370'),
(123  ,'2008-01-01 00:00:04','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',2               ,0               ,0           ,0           ,0         ,0               ,0             ,2            ,'370'),
(124  ,'2010-02-18 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'BUSY'        ,'2'           ,'1232113377.3',7               ,0               ,0           ,0           ,0         ,0               ,88            ,3            ,'370'),
(125  ,'2010-02-18 00:00:01','37046246362'        ,'37046246362','37063042438',''        ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',7               ,0               ,0           ,0           ,0         ,0               ,0             ,4            ,'370'),
(126  ,'2010-03-17 00:00:01','37046246362'        ,'37046246362','35563042438',''        ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',7               ,0               ,0           ,0           ,0         ,0               ,0             ,5            ,'355'),
# cards calls
(127  ,'2010-03-17 00:00:01','37046246362'        ,'37046246362','9363042438',''         ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113377.3',7               ,0               ,0           ,0           ,22        ,0               ,0             ,6            ,'93'),
# dst whit #
(128  ,'2010-06-22 00:00:01',''                   ,'101'        ,'123#123'    ,''        ,20         ,30        ,'ANSWERED'    ,'2'           ,'1232113371.3',6               ,0               ,0           ,0           ,0         ,0               ,0             ,7            ,'370');

