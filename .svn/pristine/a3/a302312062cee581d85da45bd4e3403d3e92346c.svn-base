# Functions Helper
module FunctionsHelper
  def homepage_url
    Web_URL.to_s + Web_Dir + '/callc/login/' + current_user.get_hash
  end

  # Wrapper to create settings grouping.

  # *Params*

  # +name+ - ID for group. Every group must have unique ID in HTML page. Othevise
  # it would be impossible to create gruop.
  # +height+ - height of the box.
  # +width+ - width of the box.
  # +block+ - HTML code to be wraped inside block.

  # *Helpers*

  # It is designed to be used with other settings helpers.
  # * setting_group_boolean - true/false settings
  # * settings_group_text - text field with numeric
  # * settings_group_number - text field with text value

  def settings_group(nice_name, id, width, height, &block)
    res = ["<div id='#{id}'>"]
    res << "<div class='dhtmlgoodies_aTab'>"
    res << "<table class='simple' width='100%'>"
    res << capture(&block)
    res << '</table>'
    res << '</div>'
    res << '</div>'
    dtree_group_script(nice_name, id, width, height)
    concat(res.join("\n").html_safe).html_safe
  end

  # Simple helper to generate script yhat shows tabs.
  def dtree_group_script(name, div_name, width, height)
    content_for :scripts do
      content_tag(:script, raw("initTabs('#{div_name}', Array('#{name}'),0,#{width},#{height});"), type: 'text/javascript').html_safe
    end
  end

  #  Boolean setting.

  # *Params*

  # +name+ - nice name. It will be displayed as a text near checkbox.
  # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
  # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def setting_group_boolean(name, prop_name, conf_name, options = {})
    user_id = manager? ? 0 : session[:user_id]
    opts = {}.merge(options)
    settings_group_line_check(name, options[:tip]) {
      "#{check_box_tag prop_name, '1', Confline.get_value(conf_name, user_id).to_i == 1}#{opts[:sufix]}"
    }
  end

  #  Text setting.

  # *Params*

  # +name+ - nice name. It will be displayed as a text near text field.
  # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
  # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def settings_group_text(name, prop_name, conf_name, options = {}, html_options = {})
    user_id = manager? ? 0 : session[:user_id]
    opts = {sufix: ''}.merge(options)
    html_opts = {
      class: 'input',
      size: '35',
      maxlength: '50'}.merge(html_options)
    settings_group_line(name, prop_name, html_options[:tip]) {
      "#{text_field_tag(prop_name, Confline.get_value(conf_name, user_id), html_opts)}#{opts[:sufix]}"
    }
  end

  #  numeric setting.

  # *Params*

  # +name+ - nice name. It will be displayed as a text near text field.
  # +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
  # +conf_name+ - Confline name. This value will be selected when form is being generated.
  def settings_group_number(name, prop_name, conf_name, options = {}, html_options = {})
    user_id = manager? ? 0 : session[:user_id]
    opts = {sufix: ''}.merge(options)
    html_opts = {
      class: 'input',
      size: '35',
      maxlength: '50'}.merge(html_options)
    settings_group_line(name, prop_name, html_options[:tip]) {
      "#{text_field_tag(prop_name, (Confline.get(conf_name, user_id).try(:value) || opts[:default_value]).to_i, html_opts)}#{opts[:sufix]}"
    }
  end

  def limit_reseller
    if reseller?
      !(((User.where(owner_id: current_user.id).count < 2) or (current_user.own_providers == 0 and reseller_active?) or (current_user.own_providers == 1 and reseller_pro_active?)))
    end
  end

  def check_role_name(role_name)
    %w[admin accountant reseller user].include?(role_name)
  end

  def check_user_for_status(user)
    return user.postpaid == 1 && user.credit != -1 && (user.balance + user.credit <= 0)
  end

  def paypal_currencies
    currencies = %w[USD EUR AUD BRL CAD CNY CZK DKK HKD HUF ILS JPY MYR MXN TWD NZD NOK PHP PLN GBP RUB SGD SEK CHF THB]
    currencies.map { |currency| [currency, currency] }
  end

  def email_template_select_for_2fa(template_id, must_include_vars = [])
    emails = Email.where(must_include_vars.map { |var| "body LIKE '%<%= #{var} %>%'"}.join(' OR ')).all
    options_for_select(emails.map {|temp| [temp.name, temp.id]}, template_id)
  end
end
