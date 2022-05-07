# M2 Managers (Administrator's helpers)
class Manager < ActiveRecord::Base
  self.table_name = 'users'
  default_scope { where(usertype: :manager) }

  belongs_to :manager_group
  has_many :owned_tariffs, class_name: 'Tariff', foreign_key: :owner_id

  attr_protected

  before_validation :remove_whitespaces
  validates :username,
            uniqueness: {message: _('Username_has_already_been_taken')},
            presence: {message: _('Username_cannot_be_blank')},
            length: {
              minimum: Application.minimum_username,
              too_short: _('Username_must_be_longer', Application.minimum_username - 1),
              if: -> { username.present? }
            }
  validates :password,
            length: {
              minimum: Application.minimum_password,
              too_short: _('Password_must_be_longer', Application.minimum_password - 1),
              on: :create
            },
            format: {
              with: /(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+/,
              message: _('Password_must_be_strong'),
              on: :create,
              if: -> { password.to_s.length >= Application.minimum_password && User.use_strong_password? }
            }
  validates :password,
            length: {
              minimum: Application.minimum_password,
              too_short: _('Password_must_be_longer', Application.minimum_password - 1),
              on: :update,
              if: -> { password.present? }
            },
            format: {
              with: /(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+/,
              message: _('Password_must_be_strong'),
              on: :update,
              if: -> { password.to_s.length >= Application.minimum_password && User.use_strong_password? }
            }
  validates :first_name,
            presence: {message: _('Name_cannot_be_blank')}
  validate :validate_manager_emails

  before_save :encrypt_password
  before_destroy :restrict_delete_responsible_manager

  def self.find_managers(options)
    managers = select("users.id AS id, users.username AS username, users.first_name AS first_name,
                      #{SqlExport.nice_user_sql}, users.comment AS comment, manager_groups.id AS group_id,
                      manager_groups.name AS group_name")
               .joins('LEFT JOIN manager_groups ON users.manager_group_id = manager_groups.id')

    order_by = options[:order_by]
    order_desc = options[:order_desc]
    if managers.column_names.insert(-1, 'nice_user', 'group_name').include?(order_by)
      managers = managers.order("#{order_by} #{order_desc.to_i == 1 ? 'desc' : 'asc'}")
    end
    managers
  end

  private

  def remove_whitespaces
    [:first_name, :username, :phone, :main_email, :comment].each { |value| self[value].to_s.strip! }
  end

  def encrypt_password
    if password.present?
      self.password = Digest::SHA1.hexdigest(password)
      self.password_changed_at = Time.zone.now.to_i if Confline.get_value('logout_on_password_change').to_i == 1
    else
      self.password = Manager.where(id: id).first.try(:password).to_s
    end
  end

  def is_responsible_accountant?
    User.where(responsible_accountant_id: id).first
  end

  def restrict_delete_responsible_manager
    return unless is_responsible_accountant?
    errors.add(:min_balance, _('Manager_is_used_as_Responsible_Manager'))
    false
  end

  def validate_manager_emails
    return if main_email.blank?
    return if Email.address_validation(main_email)
    errors.add(:manager, _('Please_enter_correct_email'))
    false
    # Email Unique Validation
    # not_self = "id != '#{self.id}'" unless id.nil?
    # main_email_all = User.where("#{not_self}").pluck(:main_email)
    # emails = main_email.split(';').reject(&:blank?)
    #
    # addressses = []
    #
    # main_email_all.each do |email|
    #   addressses << email.to_s.downcase.split(';').reject(&:blank?)
    # end if main_email_all.present?
    #
    # splitted_emails = addressses.flatten.collect(&:strip)
    #
    # emails.each do |mail|
    #   mail.gsub!(/\s+/, '')
    #   if splitted_emails.include?(mail.downcase)
    #      errors.add(:email, _('Email_space') + mail + _('Is_already_used'))
    #     return false
    #   end
    # end
  end
end
