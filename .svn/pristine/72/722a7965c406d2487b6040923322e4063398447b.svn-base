# Helper for Emails
module EmailsHelper
  def show_edit_icon(email)
    email.owner_id == corrected_user_id
  end

  def show_delete_icon(email)
    show_edit_icon(email) && (email.template == 0)
  end
end
