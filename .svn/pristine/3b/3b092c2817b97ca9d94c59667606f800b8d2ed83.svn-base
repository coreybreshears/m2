# Send SMS request to CRM, CRM sends request to SMS soft
class SmsSender
  require 'net/http'
  include ActiveModel::Validations

  attr_accessor :src_user, :dst_user, :number_from, :number_to, :message, :response_crash, :response
  validate :all_param_valid

  def initialize(src_user_id:, dst_user_id: nil, from: default_from_number, to: nil, message: '')
    self.src_user = User.where(id: src_user_id).first
    self.dst_user = User.where(id: dst_user_id).first if dst_user_id

    self.number_to = if to.present?
                       to.to_s.strip
                     elsif self.dst_user.present?
                       (self.dst_user.is_manager? ? dst_user.phone : dst_user.address.try(:mob_phone)).to_s.match(/\d+/).to_s
                     else
                       ''
                     end

    self.number_from = from.to_s.strip
    self.message = message.to_s.strip

    self
  end

  def apply_template_for_message(template_name:, additional_variables: {})
    variables = Email.email_variables(src_user, nil, additional_variables)
    template = Email.where(name: template_name, owner_id: src_user.is_user? ? src_user.owner_id : src_user.id).first
    self.message = EmailsController::nice_email_sent(template, variables)
  end

  def deliver_via_get
    encoded_uri = URI.encode("#{crm_url}?from=#{number_from}&to=#{number_to}&msg=#{message}")
    begin
      self.response = Net::HTTP.get_response(URI.parse(encoded_uri))
      !(self.response_crash = false)
    rescue => error
      self.response = error
      !(self.response_crash = true)
    end
  end

  def deliver_via_post
    begin
      url = URI.parse(crm_url)
      req = Net::HTTP::Post.new(url)
      req.form_data = {from: number_from, to: number_to, msg: message}
      response = {}
      Net::HTTP.start(url.hostname, url.port, use_ssl: (url.scheme == 'https'), read_timeout: 600) do |http|
        response = JSON.parse(http.request(req).body)
      end
      self.response = response
      !(self.response_crash = false)
    rescue => error
      self.response = error
      !(self.response_crash = true)
    end
  end

  def all_param_valid
    if src_user.blank?
      errors.add(:src_user_missing, 'Source User was not found')
    end

    if number_to.blank?
      errors.add(:number_to_blank, 'Destination Number is empty')
    end
  end

  def persisted?
    false
  end

  private

  def default_from_number
    '37063042439'
  end

  def crm_url
    'https://support.ocean-tel.uk/api/sms_send'
  end
end
