INSERT INTO `alerts` (`id`, `status`, `alert_type`, `alert_count_type`, `check_type`, `check_data`, `value_at_alert`, `alert_if_less`, `alert_if_more`, `alert_raised_at`, `value_at_clear`, `clear_if_less`, `clear_if_more`, `alert_cleared_at`, `ignore_if_calls_less`, `ignore_if_calls_more`, `action_alert_email`, `action_alert_sms`, `action_alert_disable_object`, `action_alert_change_routing_group_id`, `action_clear_email`, `action_clear_sms`, `action_clear_enable_object`, `action_clear_restore_original_dial_peer`, `action_clear_change_routing_group_id`, `before_alert_original_routing_group_id`, `alert_groups_id`, `comment`, `count_period`, `disable_clear`, `owner_id`, `clear_after`, `enable_tp_in_dial_peer`, `disable_tp_in_dial_peer`, `clear_on_date`, `notify_to_user`, `hgc`, `alert_when_more_than`, `clear_when_less_than`, `name`) VALUES
(1, 'enabled', 'asr', 'ABS', 'user', 'all', NULL, 10.00, 0.00, NULL, NULL, 0.00, 20.00, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 60, 0, 0, 0, 0, 0, NULL, 0, 0, 0, 0, 'alertas');

INSERT INTO `alert_contacts` (`id`, `name`, `status`, `timezone`, `email`, `max_emails_per_hour`, `emails_this_hour`, `max_emails_per_day`, `emails_this_day`, `phone_number`, `max_sms_per_hour`, `sms_this_hour`, `max_sms_per_day`, `sms_this_day`, `comment`) VALUES
(1, 'Contaktas', 'enabled', 2, 'lyja@leitus.com', 0, 0, 0, 0, NULL, 0, 0, 0, 0, NULL);

INSERT INTO `alert_groups` (`id`, `name`, `status`, `email_schedule_id`, `max_emails_per_month`, `emails_this_month`, `sms_schedule_id`, `max_sms_per_month`, `sms_this_month`, `comment`) VALUES
(1, 'Groupsas', 'enabled', 1, 0, 0, 0, 0, 0, NULL);

INSERT INTO `alert_schedules` (`id`, `name`, `status`, `comment`) VALUES
(1, 'Schedulas', 'enabled', NULL);

