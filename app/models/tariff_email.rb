# Tariff Import v2 Tariff Inbox
class TariffEmail < ActiveRecord::Base
  attr_protected
  has_many :tariff_attachments, dependent: :delete_all

  scope :inbox_emails, -> { where(folder: 'inbox') }
  scope :completed_emails, -> { where(folder: 'complete') }
  scope :junk_emails, -> { where(folder: 'junk') }

  def delete_email
    (folder == 'junk') ? delete : update_column(:folder, 'junk')
  end

  def self.bulk_move_to_junk(emails_ids)
    where(id: emails_ids).update_all(folder: 'junk')
  end

  def self.bulk_delete(emails_ids)
    where(id: emails_ids).delete_all
  end

  def self.data_for_list(params)
    query = filter_emails(params)

    emails = {
      inbox: inbox_emails.where(query).order(received: :desc),
      completed: completed_emails.where(query).order(received: :desc),
      junk: junk_emails.where(query).order(received: :desc)
    }
  end

  def self.pagination(params, total, session)
     fpage, total_pages, options = Application.pages_validator(session, params, total)
     { fpage: fpage, total_pages: total_pages, options: options }
  end

  def self.move_to_completed
    emails = ActiveRecord::Base.connection.exec_query("
      SELECT tariff_emails.id FROM tariff_emails
      INNER JOIN tariff_attachments ON tariff_emails.id = tariff_attachments.tariff_email_id
      LEFT JOIN tariff_jobs ON tariff_attachments.id = tariff_jobs.tariff_attachment_id
      WHERE tariff_emails.folder = 'inbox'
      GROUP BY tariff_emails.id
      HAVING COUNT(tariff_jobs.id) = COUNT(IF(tariff_jobs.status IN ('#{TariffJob.completed_statuses.split.join("','")}'), 1 , NULL)) AND COUNT(tariff_jobs.id) >= COUNT(tariff_attachments.id)
    ").rows
    where(id: emails).update_all(folder: 'complete') if emails.present?
  end

  private

  def self.filter_emails(params)
    query = []
    inbox = params[:inbox]
    if inbox[:from].present?
      query << "from_name LIKE #{ActiveRecord::Base::sanitize("%#{inbox[:from]}%")}"
    end

    if inbox[:subject].present?
      query << "subject LIKE #{ActiveRecord::Base::sanitize("%#{inbox[:subject]}%")}"
    end

    if inbox[:message].present?
      query << "message_plain LIKE #{ActiveRecord::Base::sanitize("%#{inbox[:message]}%")}"
    end
    query.join(' AND ')
  end
end
