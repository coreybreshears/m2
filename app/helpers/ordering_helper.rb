# OrderingHelper module
module OrderingHelper
  def sortable_header(name, column, html_options = {}, options = {})
    column = column.to_s.downcase

    url_params = params.slice(:controller, :action, :page, :order_by, :order_desc, :search_on, :device_id)

    current_direction = options[:order_desc] || url_params[:order_desc] || 0
    current_direction = current_direction.to_i
    current_column = options[:order_by] || url_params[:order_by].to_s

    direction = current_direction == 0 ? 1 : 0

    url_params.update(order_by: column, order_desc: direction)

    url = url_for url_params

    selected = (current_column == column)

    id = html_options[:id] || column
    klass = html_options[:class] || column
    klass << " #{current_direction == 0 ? 'asc' : 'desc'}" if selected

    link = link_to name, url
    link = '<span>' + link + '</span>' if selected

    rowspan = html_options[:rowspan] || column
    colspan = html_options[:colspan] || column

    html = "<th id=\"#{id}-header\" class=\"#{klass}\" rowspan=\"#{rowspan}\" colspan=\"#{colspan}\">#{link}</th>"
    html.html_safe
  end

  def header(name, column, html_options = {})
    column = column.to_s.downcase

    id = html_options[:id] || column
    klass = html_options[:class] || column
    rowspan = html_options[:rowspan] || column
    colspan = html_options[:colspan] || column

    html = "<th id=\"#{id}-header\" class=\"#{klass}\" rowspan=\"#{rowspan}\" colspan=\"#{colspan}\">#{name}</th>"
    html.html_safe
  end
end
