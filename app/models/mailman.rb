# Mailman model
class Mailman < ActiveRecord::Base
  attr_protected

  def receive(email)
    page = Page.where(address: email.to.first).first
    page.emails.create(
      subject: email.subject,
      body: email.body
    )

    return unless email.has_attachments?

    email.attachments.each do |attachment|
      page.attachments.create({
        file: attachment,
        description: email.subject
      })
    end
  end
end
