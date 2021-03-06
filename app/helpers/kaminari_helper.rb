# Kaminari Paginator helper
module KaminariHelper
  def paginate(scope, options = {}, &block)
    paginator = Kaminari::Helpers::Paginator.new self, options.reverse_merge(current_page: scope.current_page,
      total_pages: scope.total_pages, per_page: scope.limit_value, remote: false,
      page_entries_info: page_entries_info(scope, options)
    )
    paginator.to_s
  end

  def url_for_page(page)
    url_for params.slice(:controller, :action, :page, :order_by, :order_desc, :search_on)
                  .merge(page: ((page <= 0) ? nil : page), only_path: true)
  end

  def page_entries_info(collection, options = {})
    entry_name = if options[:entry_name]
        options[:entry_name]
      elsif collection.is_a?(::Kaminari::PaginatableArray)
        'entry'
      else
        if collection.respond_to? :model # DataMapper
          collection.model.model_name.human.downcase
        else # AR
          collection.model_name.human.downcase
        end
      end

    entry_name = entry_name.pluralize

    first = collection.offset_value + 1
    last = collection.last_page? ? collection.total_count : collection.offset_value + collection.limit_value
    _('display_entries', first, last, collection.total_count, _(entry_name)).html_safe
  end

  def page_outer_or_inside?(page)
    page.left_outer? || page.right_outer? || page.inside_window?
  end
end
