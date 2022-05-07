# Two factor authentication model
class TwoFactorAuth < ActiveRecord::Base
  belongs_to :user
  attr_protected
  after_create :make_code_generation_action, :send_access_code_notification

  def self.create(user_id)
    two_factor = new
    two_factor.generated_code = generate_code.upcase
    two_factor.max_attempts = Confline.get_value('two_fa_attemps_allowed').to_i
    two_factor.created_at = Time.now
    two_factor.user_id = user_id
    two_factor.valid_until = Time.now + Confline.get_value('two_fa_time_allowed').to_i.minutes
    two_factor.save
  end

  def verify_code(code)
    status = code_valid?(code.upcase) && !code_expired?
    self.tried_attempts += 1

    save unless status
    destroy if status

    check_for_errors(code.upcase)

    status_msg = status ? 'successful' : 'failed'
    send_login_notification_to_admin("login #{status_msg}")
    send_login_notification_to_email("login #{status_msg}")
    Action.add_action_hash(0, action: "2FA login #{status_msg}", target_id: user_id,
                              data: "attempt: #{tried_attempts}", data2: "max attemtps: #{max_attempts}",
                              data3: "valid until: #{valid_until.to_s(:db)}", data4: "IP: #{login_ip}",
                              target_type: 'user'
                          )

    status
  end

  def login_ip=(ip)
    @login_ip = ip
  end

  def code_expired?
    Time.now > valid_until || tried_attempts >= max_attempts
  end

  def code_valid?(code)
    code == generated_code
  end

  def destroy_if_expired
    return self unless code_expired?
    destroy
    nil
  end

  private

  # generataes random number between 0-9 and a-z
  def self.generate_code
    rand(36**Confline.get_value('two_fa_code_length').to_i).to_s(36).upcase
  end

  def send_access_code_notification
    # send access code
    email_template = Email.where(id: Confline.get_value('two_fa_email_template').to_i, owner_id: 0).first
    email_sender = EmailSender.new
    email_sender.send_notification(email_template, user.main_email, user.id, { two_fa_code: generated_code })
  end

  def send_login_notification_to_admin(attempt_status)
    return if Confline.get_value('two_fa_send_notification_to_admin_on_login').to_i == 0
    return if (user.is_admin? && Confline.get_value('two_fa_send_notification_to_admin_on_admin_login').to_i === 0)
    return if (!user.is_admin? && Confline.get_value('two_fa_send_notification_to_admin_on_user_login').to_i === 0)
    email_sender = EmailSender.new
    email_template = Email.where(id: Confline.get_value('two_fa_admin_notification_email_template').to_i, owner_id: 0)
                          .first
    admin = User.where(id: 0).first
    options = options_for_login_notification(attempt_status)
    email_sender.send_notification(email_template, admin.main_email, user.id, options)
  end

  def send_login_notification_to_email(attempt_status)
    return if Confline.get_value('two_fa_send_notification_email_on_login').to_i == 0
    return if (user.is_admin? && Confline.get_value('two_fa_send_notification_on_admin_login').to_i === 0)
    return if (!user.is_admin? && Confline.get_value('two_fa_send_notification_on_user_login').to_i === 0)
    email_sender = EmailSender.new
    email_template = Email.where(id: Confline.get_value('two_fa_notification_email_template').to_i, owner_id: 0).first
    email = Confline.get_value('two_fa_notification_email_address').to_s
    options = options_for_login_notification(attempt_status)
    email_sender.send_notification(email_template, email, user.id, options)
  end

  def make_code_generation_action
    Action.add_action_hash(0, action: "2FA code generated", target_id: user_id, data: "max attemtps: #{max_attempts}",
                              data2: "valid until: #{valid_until.to_s(:db)}", target_type: 'user'
                          )
  end

  def options_for_login_notification(attempt_status)
    {
      two_fa_code_attempt: tried_attempts,
      two_fa_login_status: attempt_status,
      two_fa_login_ip: login_ip
    }
  end

  def login_ip
    @login_ip
  end

  def check_for_errors(code)
    self.errors.add(:code_expired, _('2FA_Code_expired')) if Time.now > valid_until
    self.errors.add(:attempts_exceeded, _('Number_of_Attempts_Exceeded')) if tried_attempts >= max_attempts
    self.errors.add(:invalid_code, _('Invalid_2FA_code')) if code != generated_code
  end
end
