class ActiveRecord::Result
  def size
    self.rows.size
  end
end

# http://trac.ocean-tel.uk/trac/ticket/13140
module ActionView
  module Helpers
    module DateHelper
      def select_datetime(datetime = Time.current, options = {}, html_options = {})
        options[:locale] = 'en'
        DateTimeSelector.new(datetime, options, html_options).select_datetime
      end

      def select_date(date = Date.current, options = {}, html_options = {})
        options[:locale] = 'en'
        DateTimeSelector.new(date, options, html_options).select_date
      end
    end
  end
end