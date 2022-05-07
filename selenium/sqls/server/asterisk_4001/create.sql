INSERT INTO `servers` (`id`, `server_ip`, `stats_url`, `server_type`, `active`, `comment`, `hostname`, `maxcalllimit`, `ami_port`, `ami_secret`, `ami_username`, `port`, `ssh_username`, `ssh_secret`, `ssh_port`, `gateway_active`, `version`, `uptime`) VALUES
(4001, '127.0.0.1', NULL, 'asterisk', 1, 'admins', '127.0.0.1', 500, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '');

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`, `cps_call_limit`, `cps_period`, `defaultuser`, `useragent`, `type`, `md5secret`, `remotesecret`, `directmedia`, `useclientcode`, `setvar`, `amaflags`, `callcounter`, `busylevel`, `allowoverlap`, `allowsubscribe`, `maxcallbitrate`, `rfc2833compensate`, `session-timers`, `session-expires`, `session-minse`, `session-refresher`, `t38pt_usertpsource`, `regexten`, `defaultip`, `rtptimeout`, `rtpholdtimeout`, `outboundproxy`, `callbackextension`, `timert1`, `timerb`, `qualifyfreq`, `constantssrc`, `contactpermit`, `contactdeny`, `usereqphone`, `textsupport`, `faxdetect`, `buggymwi`, `auth`, `fullname`, `trunkname`, `cid_number`, `callingpres`, `mohinterpret`, `mohsuggest`, `parkinglot`, `hasvoicemail`, `vmexten`, `autoframing`, `rtpkeepalive`, `call-limit`, `g726nonstandard`, `ignoresdpversion`, `allowtransfer`, `dynamic`) VALUES
(2041, 'mor_server_15', '127.0.0.1', '', 'mor_direct', '127.0.0.1', 5060, 0, 2041, NULL, 'mor_server_15', 0, 'mor_server_15', 'SIP', 0, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'no', NULL, 'no', NULL, 'rfc2833', NULL, NULL, 'mor_server_15', NULL, 'no', 'no', 'no', 'never', 'no', 1, 'DO NOT EDIT', 0, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0, 6400, NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO `devicecodecs` (`device_id`, `codec_id`, `priority`) VALUES
(2041, 1, 0),
(2041, 5, 0);
