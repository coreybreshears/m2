# -*- encoding : utf-8 -*-
# Probably for internal QA testing
class ValidationController < ApplicationController
  def validate
    Action.create(date: Time.now.to_s(:db), action: 'system_validated')
    render(text: "Users:\n#{validate_users}\n\nDevices:\n#{validate_devices}")
  end

  private

  def validate_users
    users = User.includes([:address]).all
    @validated_users = 0
    @still_invalid = 0

    users.each do |user|
      next if user.save
      validate_user(user)
    end

    "  Total users: #{users.size}\n  Validated users: #{@validated_users}\n  Still invalid: #{@still_invalid}"
  end

  def validate_user(user)
    user_id = user.id
    my_debug("\nINVALID USER: #{user_id}")
    validate_user_emails(user, user_id)
    validate_user_check(user, user_id)
  end

  def validate_user_emails(user, user_id)
    unless user.address
      my_debug("FIXING USER: #{user_id} User has no address")
      user.create_address
    end

    User::M2_EMAILS.each do |m2_email|
      if user[m2_email].present? && !Email.address_validation(user[m2_email])
        Action.create(user_id: user_id, date: Time.now.to_s(:db),
                      action: 'user_validated', data: 'email_deleted', data2: user[m2_email])

        my_debug("FIXING USER: #{user_id} Wrong user[:#{m2_email}]: #{user[m2_email]}")
        user[m2_email] = ''
        user.save
      end
    end
  end

  def validate_user_check(user, user_id)
    if user.save
      my_debug("VALIDATED USER: #{user_id}")
      @validated_users += 1
    else
      Action.add_error(user_id, ("User_still_invalid.  #{user.errors.map { |key, value| value }.join(' ')}")[0..255])
      my_debug("NOT VALIDATED USER: #{user_id}")
      @still_invalid += 1
    end
  end

  def validate_devices
    devices = Device.all
    @still_invalid = 0

    devices.each do |device|
      next if device.save
      validate_device(device)
    end

    "  Total devices: #{devices.size}\n  Still invalid: #{@still_invalid}"
  end

  def validate_device(device)
    device_id = device.id
    my_debug("\nINVALID DEVICE: #{device_id}")

    if device.save
      my_debug("VALIDATED DEVICE: #{device_id}")
    else
      Action.create(
          date: Time.now.to_s(:db), target_id: device_id, target_type: 'device', action: 'error',
          data: "Device_still_invalid.  #{device.errors.map { |key, value| value }.join(' ')}"[0..255],
          processed: 0
      )
      my_debug("NOT VALIDATED DEVICE: #{device_id}")
      @still_invalid += 1
    end
  end
end
