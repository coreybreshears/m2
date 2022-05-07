# -*- encoding : utf-8 -*-
class CronAction < ActiveRecord::Base
  belongs_to :cron_setting

  before_destroy :cron_before_destroy

  attr_protected

  def cron_before_destroy
    self.create_new
  end

  def create_new
    time = self.next_run_time
    if time < cron_setting.valid_till and cron_setting.periodic_type != 0 or cron_setting.repeat_forever == 1
      CronAction.create(cron_setting_id: cron_setting.id, run_at: time)
    end
  end

  # we should chop off someone's hands for coding like that..
  # but there's explanation what periodic_type magic numbers mean:
  #   0 - runs only once(how ilogical it is to ask about NEXT RUN if action can be run only once??!)
  #   1 - runs once every year
  #   2 - runs once every month
  #   3 - runs once every week
  #   4 - runs every work day
  #   5 - runs every free day
  #   6 - runs once every day

  #  Note that this method will give you an answer no matter whether it should be run next time or not,
  #  because cron job can have it's time limit.

  def next_run_time
    time = run_at.to_time
    case cron_setting.periodic_type
      when 0
        time = time.to_s.to_time
      when 1
        time = time.to_s.to_time + 1.year
      when 2
        time = time.to_s.to_time + 1.month
      when 3
        time = time.to_s.to_time + 1.week
      when 4
        z = time.to_s.to_time + 1.day
        if weekend? z
          time = next_monday(time.to_s.to_time)
        else
          time = time.to_s.to_time + 1.day
        end
      when 5
        z = time.to_s.to_time + 1.day
        unless weekend? z
          time = next_saturday(time.to_s.to_time)
        else
          time = time.to_s.to_time + 1.day
        end
      when 6
        time = time.to_s.to_time + 1.day
    end
    time
  end

  # Check whether given date is weekend or not

  # *Params*
  #     date - datetime or time instance

  # *Returns*
  #     true if given date is weekday else returns false

  def weekend?(date)
    [6, 0].include? date.wday
  end

  # We need to get date of next monday
  def next_monday(date)
    date += ((1 - date.wday) % 7).days
  end

  # We need to get date of next saturday, that is closest day of upcoming weekend
  def next_saturday(date)
    date += ((6 - date.wday) % 7).days
  end

  def CronAction.do_jobs
    actions = CronAction.includes(:cron_setting).where(['run_at < ? AND failed_at IS NULL', Time.now().to_s(:db)]).all
    MorLog.my_debug("Cron Action Jobs, found : (#{actions.size.to_i})", 1) if actions
    for action in actions
      if action.cron_setting
        MorLog.my_debug("**** Action : #{action.id} ****")
        case action.cron_setting.action
          when 'change_tariff'
            MorLog.my_debug("---- Change tariff into : #{action.cron_setting.to_target_id}")
            if action.cron_setting.target_id == -1
              sql = "UPDATE users SET tariff_id = #{action.cron_setting.to_target_id} WHERE owner_id = #{action.cron_setting.user_id}"
            else
              sql = "UPDATE users SET tariff_id = #{action.cron_setting.to_target_id} WHERE id = #{action.cron_setting.target_id} AND owner_id = #{action.cron_setting.user_id}"
            end
            # MorLog.my_debug(sql)
            begin
              ActiveRecord::Base.connection.update(sql)
              Action.add_action_hash(action.cron_setting.user_id, {action: 'CronAction_run_successful', data: 'CronAction successful change tariff', target_id: action.cron_setting.target_id, target_type: 'User', data3: action.cron_setting_id, data2: action.cron_setting.to_target_id})
              action.destroy
              MorLog.my_debug('Cron Actions completed', 1)
            rescue => e
              action.failed_at = Time.now
              action.last_error = e.class.to_s + ' \n ' + e.message.to_s + ' \n ' + e.try(:backtrace).to_s
              action.attempts = action.attempts.to_i + 1
              action.save
              action.create_new
              Action.add_action_hash(action.cron_setting.user_id, {action: 'error', data: 'CronAction dont run', data2: action.cron_setting_id, data3: action.cron_setting.to_target_id, data4: e.message.to_s + ' ' + e.class.to_s, target_id: action.cron_setting.target_id, target_type: 'User'})
            end
        end
      else
        action.failed_at = Time.now
        action.last_error = "CronAction setting dont found : #{action.cron_setting_id}"
        action.attempts = action.attempts.to_i + 1
        action.save
        Action.add_action_second(-1, 'error', 'CronAction setting dont found', action.id)
      end
    end
  end
end
