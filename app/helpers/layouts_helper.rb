# -*- encoding : utf-8 -*-
module LayoutsHelper
  def current_user_permission
    current_user.usertype == 'user' and (current_user.owner)
  end

  def check_active(controller, action, parent)
    if parent == {controller: controller, action: action}
      "class=\"active\"".html_safe
    else
      ''
    end
  end

  def calendar_date_format
    render text: session[:date_format].to_s.sub('%Y', 'yy').sub('%m', 'mm').sub('%d', 'dd').sub('%b', 'M').sub('%B', 'MM').sub('%a', 'D').sub('%A', 'DD'), layout: false
  end

  def aggregates_link
    agg_link = admin? ? '/aggregates/list' : '/calls/aggregates'

    return agg_link
  end

  def currency_change_url
    {action: params[:action], controller: params[:controller], id: params[:id], page: params[:page]}
  end

  def all_security_on(security_check, security_schedules, security_groups)
    if security_check || security_schedules || security_groups
      return true
    end
  end

  def get_page_title
    controller, action = [params[:controller], params[:action]]
    page_path, parent = find_path(controller, action, params[:spec_param_for_layout_name])
    page_title = ''
    (page_path.each_with_index { |page, index| page_title = page }) if page_path.present?
    return ActionController::Base.helpers.strip_tags(page_title), parent, page_path
  end

  def tariff_inbox_permission
    authorize_manager_permissions({controller: :tariff_inbox, action: :inbox, no_redirect_return: 1})
  end

  def tariff_jobs_permission
    authorize_manager_permissions({controller: :tariff_jobs, action: :list, no_redirect_return: 1})
  end

  def tariff_import_rules_permission
    authorize_manager_permissions({controller: :tariff_import_rules, action: :list, no_redirect_return: 1})
  end

  def tariff_rate_import_rules_permission
    authorize_manager_permissions({controller: :tariff_rate_import_rules, action: :list, no_redirect_return: 1})
  end

  def tariff_templates_permission
    authorize_manager_permissions({controller: :tariff_templates, action: :list, no_redirect_return: 1})
  end

  def tariff_link_attachment_rules_permission
    authorize_manager_permissions({controller: :tariff_link_attachment_rules, action: :list, no_redirect_return: 1})
  end
end
