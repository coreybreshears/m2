# Number Pools are used for CallerIDs or Blacklisting/Whitelisting
class NumberPoolsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { user? || reseller? }
  before_filter :authorize
  before_filter :check_post_method, only: [:pool_create, :pool_update, :pool_destroy, :number_create, :number_destroy]
  before_filter :find_number, only: [:number_destroy]
  before_filter :find_number_pool,
                only: [
                  :pool_edit, :pool_update, :pool_destroy, :number_list, :number_import,
                  :destroy_all_numbers, :reset_all_number_counters, :bad_numbers, :number_add
                ]

  # Number Pools Begin
  def pool_list
    @page_title = _('Number_Pools')
    @page_icon = 'number_pool.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'

    @options = session[:number_pool_list] || {}

    set_options_from_params(@options, params, page: 1, order_desc: 0, order_by: 'id')

    order_by = NumberPool.number_pools_order_by(@options)

    # Page params

    @total_pools_size = NumberPool.count
    @fpage, @total_pages, _options = Application.pages_validator(session, @options, @total_pools_size)
    @page = @options[:page]

    @number_pools = NumberPool.select('number_pools.*, COUNT(n.id) AS num')
                              .joins('LEFT JOIN numbers n ON (n.number_pool_id = number_pools.id)')
                              .group('number_pools.id')
                              .order(order_by)
                              .limit("#{@fpage}, #{session[:items_per_page].to_i}").all

    session[:number_pool_list] = @options
  end

  def pool_new
    @page_title = _('New_number_pool')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'
  end

  def pool_create
    @number_pool = NumberPool.new(params[:number_pool])
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_created')
      redirect_to(action: :pool_list) && (return false)
    else
      flash_errors_for(_('number_pool_was_not_created'), @number_pool)
      render :pool_new
    end
  end

  def pool_edit
    @page_title = _('number_pool_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'
  end

  def pool_update
    @number_pool.attributes = @number_pool.attributes.merge(params[:number_pool])
    if @number_pool.save
      flash[:status] = _('number_pool_successfully_updated')
      redirect_to(action: :pool_list) && (return true)
    else
      flash_errors_for(_('number_pool_was_not_updated'), @number_pool)
      render :pool_edit
    end
  end

  def pool_destroy
    if @number_pool.destroy
      flash[:status] = _('number_pool_successfully_deleted')
    else
      flash_errors_for(_('number_pool_was_not_deleted'), @number_pool)
    end
    redirect_to(action: :pool_list)
  end

  # Number Pools End

  # Numbers Start

  def number_list
    @page_title = _('Number_Pools')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'

    @options = session[:number_list] || {}

    set_options_from_params(@options, params, order_desc: 0, order_by: 'id')

    order_by = Number.numbers_order_by(@options)
    number_wcard = params[:s_number] || @options[:s_number]
    number_wcard = '' if params[:clear]
    number_wcard_for_search = number_wcard.gsub('#', '\_') if number_wcard.present?

    number_pool_numbers = @number_pool.numbers.retrieve(number_wcard_for_search, order_by)
    @total_numbers_size = number_pool_numbers.size
    @page = params[:page].presence
    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @total_numbers_size, @page)
    @numbers = number_pool_numbers.limit(session[:items_per_page].to_i).offset(@fpage)

    @options[:s_number] = number_wcard
    session[:number_list] = @options
  end

  def number_destroy
    if @number.destroy
      flash[:status] = _('number_successfully_deleted')
    else
      flash_errors_for(_('number_was_not_deleted'), @number_pool)
    end
    redirect_to action: :number_list, id: @number.number_pool_id
  end

  def destroy_all_numbers
    retry_lock_error(3) { @number_pool.numbers.delete_all }
    @number_pool.changes_present_set_1
    flash[:status] = _('all_numbers_successfully_deleted')
    redirect_to action: :number_list, id: @number_pool.id
  end

  def reset_all_number_counters
    ActiveRecord::Base.connection.execute("UPDATE numbers SET counter = 0 WHERE number_pool_id = #{@number_pool.id};")
    @number_pool.changes_present_set_1
    flash[:status] = _('All_Number_Counters_successfully_reset')
    redirect_to(action: :number_list, id: @number_pool.id) && (return false)
  end

  def number_add
    number = params[:number].strip
    number_to_add = ''
    if Number.where(number: number.chomp, number_pool_id: params[:id]).first.blank?
      number_to_add = Number.new(number: number.chomp, number_pool_id: params[:id])
      number_to_add.check_pattern
      unless is_number_pool_format?(number) || number == 'empty'
        number_to_add.errors.add(:number, _('Number_must_consist_only_of_digits_and_symbols'))
      end
    end

    if number_to_add.blank?
      flash[:notice] = _('Number_already_exist')
    elsif number_to_add.errors.empty? && number_to_add.save
      flash[:status] = _('Number_added')
    else
      flash_errors_for(_('Bad_number'), number_to_add)
    end
    redirect_to(action: :number_list, id: @number_pool.id) && (return false)
  end

  def number_import
    @page_title = _('Number_import')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'

    @step = (params[:step] || 1).to_i
    number_pool_id = @number_pool.id
    file_param = params[:file]

    if @step == 2
      if file_param
        @file = file_param
        if @file.size > 0

          if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to(action: :number_import, id: number_pool_id, step: '0') && (return false)
          end
          @imported_numbers = 0
          numbers_to_import = 0
          @bad_numbers_quantity = 0
          array_for_sql = []
          bad_numbers = []
          begin
            @file.rewind
            file = @file.read.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').gsub("\xEF\xBB\xBF", '')
            session[:file_size] = file.size

            # Creating temp table.
            ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS temp_numbers_#{number_pool_id}")
            ActiveRecord::Base.connection.execute("CREATE TEMPORARY TABLE temp_numbers_#{number_pool_id} (number VARCHAR(255), number_pool_id int(11), pattern TINYINT(4))")
            file.each_line do |file_line|
              file_line_stripped = file_line.to_s.strip
              test_line = file_line_stripped.chomp
              if is_number_pool_format?(test_line) || test_line == 'empty'
                numbers_to_import += 1
                number = file_line.strip.chomp
                pattern = (number.include?('%') ? 1 : 0)
                array_for_sql << "('#{number}', #{number_pool_id}, #{pattern})"
              elsif file_line.present?
                line = file_line_stripped.force_encoding('UTF-8')
                if line.valid_encoding?
                  @bad_numbers_quantity += 1
                  bad_numbers << line
                end
              end
            end

            @total_numbers = numbers_to_import + @bad_numbers_quantity

            # File for bad numbers
            `chmod 777 /tmp/m2/bad_numbers.txt`

            File.open('/tmp/m2/bad_numbers.txt', 'w+') do |line|
              line.write(bad_numbers.join("\n"))
            end

            # Remove working files on DB servers
            Server.where(db: 1).each do |server|
              server.execute_command_in_server(
                "rm -rf /tmp/m2/existing_numbers_in_db_#{number_pool_id}.txt "\
                "/tmp/m2/duplicate_numbers_in_file_#{number_pool_id}.txt"
              )
            end

            # For the case when local server is not in the servers list
            system("rm -rf /tmp/m2/existing_numbers_in_db_#{number_pool_id}.txt "\
                   "/tmp/m2/duplicate_numbers_in_file_#{number_pool_id}.txt")

            # Inserting numbers into temp table.
            sql = "INSERT INTO temp_numbers_#{number_pool_id} (number, number_pool_id, pattern) VALUES #{array_for_sql.join(', ')}"
            ActiveRecord::Base.connection.execute(sql) if numbers_to_import > 0

            # Existing numbers in db.
            existing_numbers_query = "SELECT temp_numbers_#{number_pool_id}.number
                                      INTO OUTFILE '/tmp/m2/existing_numbers_in_db_#{number_pool_id}.txt'
                                      FIELDS TERMINATED BY ','
                                      LINES TERMINATED BY '\n'
                                      FROM temp_numbers_#{number_pool_id}
                                      LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                      WHERE numbers.number IS NOT NULL"
            ActiveRecord::Base.connection.execute(existing_numbers_query)

            # Duplicate numbers with their count.
            duplicate_numbers_in_file = "SELECT number
                                          INTO OUTFILE '/tmp/m2/duplicate_numbers_in_file_#{number_pool_id}.txt'
                                          FIELDS TERMINATED BY ','
                                          LINES TERMINATED BY '\n'
                                          FROM temp_numbers_#{number_pool_id}
                                          GROUP BY number HAVING COUNT(number) > 1"
            ActiveRecord::Base.connection.execute(duplicate_numbers_in_file)

            # Successfully imported numbers.
            imported_numbers_count_query = "SELECT COUNT(DISTINCT temp_numbers_#{number_pool_id}.number) AS imported_numbers
                                            FROM temp_numbers_#{number_pool_id}
                                            LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                            WHERE numbers.number IS NULL"

            @imported_numbers = ActiveRecord::Base.connection.select_value(imported_numbers_count_query)

            # Inserting unique numbers into numbers table.
            inserting_query = "INSERT INTO numbers(number, number_pool_id, pattern)
                                                  (SELECT DISTINCT temp_numbers_#{number_pool_id}.number,
                                                                   temp_numbers_#{number_pool_id}.number_pool_id,
                                                                   temp_numbers_#{number_pool_id}.pattern
                                                   FROM temp_numbers_#{number_pool_id}
                                                   LEFT JOIN numbers ON (numbers.number = temp_numbers_#{number_pool_id}.number AND numbers.number_pool_id = #{number_pool_id})
                                                   WHERE numbers.number IS NULL)"
            ActiveRecord::Base.connection.execute(inserting_query)

            if @total_numbers == @imported_numbers
              flash[:status] = _('Numbers_successfully_imported')
              @number_pool.changes_present_set_1
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
              @bad_numbers_quantity = @total_numbers - @imported_numbers
            end
          rescue StandardError
            flash[:notice] = _('Number_import_error')
            redirect_to(action: :number_import, id: number_pool_id) && (return false)
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to(action: :number_import, id: number_pool_id) && (return false)
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: :number_import, id: number_pool_id) && (return false)
      end
    end
  end

  def bad_numbers
    @page_title = _('Bad_numbers_from_file')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Number_Pool'

    @rows = []
    File.open('/tmp/m2/bad_numbers.txt', 'r').each_line { |file| @rows << file }

    @dup_numbers = @number_pool.bad_numbers
  end

  # Numbers End

  private

  def find_number_pool
    @number_pool = NumberPool.where(id: params[:id]).first
    return if @number_pool
    flash[:notice] = _('number_pool_was_not_found')
    redirect_to(action: :pool_list) && (return false)
  end

  def find_number
    @number = Number.where(id: params[:id]).first
    return if @number.present?

    flash[:notice] = _('number_was_not_found')
    redirect_to(action: :number_list) && (return false)
  end
end
