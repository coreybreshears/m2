# Destination model
class Destination < ActiveRecord::Base

  attr_protected

  has_many :rates
  has_many :calls, -> (prefix) { where(prefix: prefix) }
  belongs_to :destinationgroup
  belongs_to :direction, foreign_key: 'direction_code', primary_key: 'code'

  validates_uniqueness_of :prefix
  validates_presence_of :prefix, :direction_code, :name,
                        message: ->(object, data) do
                          "#{data[:attribute]} #{_('cannot_be_empty')}"
                        end
  validates :prefix,
            allow_nil: true,
            format: {
                with: /\A\d+\z/,
                message: _('Prefix_can_only_be_numeric_value')
            }

  before_destroy :dest_before_destroy

  after_save :update_destinationgroup_id

  #This should be moved to Rate modrecord_changed?el's association scope eventually.
  scope :linked_with_rate, ->(id) do
    select('destinations.*, directions.*, destinations.name AS \'destination_name\'').
    joins(:direction).
    where(id: id)
  end

  def update_destinationgroup_id
    if self.destinationgroup_id_changed?
      Confline.set_value('dg_group_was_changed_today', 1)
    end
  end

  def dest_before_destroy
    th = Thread.new { @call = Call.select(:id).where("prefix = '#{prefix}'").first; ActiveRecord::Base.connection.close }

    used_prefix = rates.pluck(:prefix)

    if rates.size > 0
      errors.add(:rates, _('rates_exist') + ': ' + used_prefix.join(' '))
      return false
    end

    th.join
    if @call
      errors.add(:calls, _('calls_to_this_destination_exist') + ': ' + prefix)
      return false
    end
  end

  def update_by(params)
    updated = false
    if params[("dg" + self.id.to_s).intern] && params[('dg' + self.id.to_s).intern].length > 0

        self.destinationgroup_id = params[("dg#{id}").intern]
        updated = true
    end
    updated
  end

  def direction
    Direction.where(code: self.direction_code).order('name ASC').first
  end

  def calls
    Call.where(prefix: prefix).all
  end

  # Renames all destination names that have certaint prefix pattern.
  # name - destination name, may be blank. if logner than 255 symbols, name will be truncated
  # prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE
  def self.rename_by_prefix(name, prefix)
    update = "name = #{ActiveRecord::Base::sanitize(name.to_s)}"
    condition = prefix_pattern_condition(prefix)
    Destination.where(condition).update_all(update)
  end

=begin
  Finds all destinations that match supplied prefix pattern

  *Params*
  prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE

  *Returns*
  destinations - array containing all found destinations
=end
  def self.dst_by_prefix(prefix)
    condition = prefix_pattern_condition(prefix)
    includes(:destinationgroup).where(condition).order('prefix ASC').all
  end

=begin
  *Params*
  prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE

  *Returns*
  condition - condition with regular expression
=end
  def self.prefix_pattern_condition(prefix)
    condition = 'prefix REGEXP ?', prefix_pattern(prefix)
  end

=begin
  Deletes % if it is supplied in pattern, because this is not a metacharacter
  of regexp and supplied pattern is hybrid of mysql's REGXEP and LIKE.
  if you would pass prefix X, search would look for pattern Y:
  12%3 -> ^123(thats a system wide feature, heck knows why. AJ)
  123% -> ^123
  %123 -> ^123(thats a system wide feature, heck knows why. AJ)
  123  -> ^123$
=end
  def self.prefix_pattern(prefix)
    '^' + (prefix.to_s.include?('%') ? prefix.to_s.delete('%') : prefix.to_s + '$')
  end

  def get_direction
    direction = self.direction

    results = direction.name.to_s + ' ' + self.name.to_s if direction

    return direction, results, message
  end

  def Destination.select_destination_assign_dg(page, order)
    limit = Confline.get_value('Items_Per_Page').to_i
    offset = limit*(page-1)

    sql = "SELECT destinations.* FROM destinations
           JOIN directions ON directions.code = destinations.direction_code
           WHERE (destinations.destinationgroup_id = 0 OR destinations.destinationgroup_id is NULL)
           ORDER BY #{order}, destinations.id LIMIT #{limit} OFFSET #{offset}"
    Destination.find_by_sql(sql)
  end

  def Destination.auto_assignet_to_dg
    begining_of_sql = 'UPDATE destinations ' +
      'LEFT JOIN destinationgroups ON (destinationgroups.flag = destinations.direction_code ) ' +
      'LEFT JOIN rates ON (destinations.id = rates.destination_id) ' +
      'SET destinations.destinationgroup_id = destinationgroups.id, rates.destinationgroup_id = destinationgroups.id WHERE destinations.destinationgroup_id = 0 AND '
    sql = "#{begining_of_sql}destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }
    sql2 = "#{begining_of_sql}destinations.name LIKE '%MOB%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql2) }
    sql3 = "#{begining_of_sql}destinations.name LIKE '%NGN%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql3) }
    sql4 = "#{begining_of_sql}destinations.name LIKE '%FIX%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql4) }
    sql5 = "#{begining_of_sql}destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql5) }
  end

  def self.retry_lock_error(retries = 3, &block)
    begin
      yield
    rescue ActiveRecord::StatementInvalid => e
      if e.message =~ /Deadlock found when trying to get lock/ and (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        MorLog.my_debug("#{e.message}")
      end
    end
  end

  def self.count_without_group
    Destination.where(destinationgroup_id: 0).count.to_i
  end

  def self.assign_all_unassigned_destinations(options = {})
    assigned_destinations = []
    # Ticket #13584 (for more elaborated specification)
    options[:individual_destination_action] = 0 unless options[:individual_destination_action]
    options[:fixed_unassigned_destination_prefix_difference] = 1 if options[:fixed_unassigned_destination_prefix_difference].to_i <= 0

    # 1. Select all Unassigned Destinations
    unassigned_destinations = Destination.where(destinationgroup_id: [0, nil]).all.as_json

    # 0. Backup Database table - destinations && destinationgroups
    if unassigned_destinations.present?
      cfg = ActiveRecord::Base.configurations[Rails.env].symbolize_keys
      `mkdir /tmp/m2/destinations_and_destinationgroups_backups`
      path = '/tmp/m2/destinations_and_destinationgroups_backups'
      filename = "destinations_and_destinationgroups_backup_#{Time.now.to_i}.sql"
      dmp_action = system("mysqldump #{cfg[:database]} destinations destinationgroups --skip-triggers " \
               "-h #{cfg[:host]} -P #{cfg[:port]} " \
               "-u #{cfg[:username]} --password='#{cfg[:password]}' " \
               "> #{path}/#{filename}"
      )
      `cd #{path}; tar -czf #{filename}.tar.gz #{filename}`
      `rm -rf #{path}/#{filename}`
      unless dmp_action
        MorLog.my_debug('Cannot create mysqldump in /tmp/m2 folder (for Unassigned Destinations fix)', 1)
        return {error: _('Cannot_create_Backup_please_contact_Support')}
      end
    else
      return {error: _('Unassigned_Destinations_were_not_found')}
    end

    unassigned_destinations.keep_if do |destination|
      # 1.1. Normalize their names into separate key
      destination['normalized_name'] = Destination.name_normalization(destination['name'].to_s)

      # 2. Validation by shortest prefix and direction name and code
      #  2.1. We have Destination (prefix: '3706', name: 'Lithuania mobile', direction_code: 'LTU'),
      #       find an Assigned Destination for it by shortest prefix and matching direction_code
      #       which we find - Destination (prefix: '370', name: 'Lithuania proper', direction_code: 'LTU')
      shorter_longest_prefix_string = Application.shorter_longest_prefix_string(destination['prefix'].to_s, false)
      next(false) if shorter_longest_prefix_string.blank?
      destination_by_shortest_prefix = Destination.
          where("prefix IN (#{shorter_longest_prefix_string})").
          where('destinationgroup_id > 0').
          where(direction_code: destination['direction_code']).
          order('prefix ASC').first
      next(false) unless destination_by_shortest_prefix

      #  2.2. With found Destination, we take it's Direction (over destination.direction_code 'LTU' relation)
      #       which we find - Direction (name: 'Lithuania', code: 'LTU')
      direction = destination_by_shortest_prefix.direction
      next(false) unless direction
      destination['direction_name'] = direction.name

      #  2.3. If Direction.name is within unassigned Destination.name boundaries - all good
      #       (Direction.name 'Lithuania' is present in Destination.name 'Lithuania mobile')
      next(false) unless destination['normalized_name'].include?(direction.name.downcase)

      #  2.4. Skip Unassigned Destinations containing 'Fixed' and of only Direction name ('Lithuania - Fixed')
      #       and prefix length difference more than 'fixed_unassigned_destination_prefix_difference'
      splitted_direction_name = Destination.split_destination_name(destination['direction_name'])
      if destination['normalized_name'].include?('fixed') && (destination['normalized_name'].split(' ') - splitted_direction_name - %w[fixed]).blank?
        prefix_length_difference = destination['prefix'].size - destination_by_shortest_prefix.prefix.size
        next(false) if prefix_length_difference > options[:fixed_unassigned_destination_prefix_difference]
      end

      next(true)
      #  2.X. If not all good, skip this Destination, Admin must fix it manually
    end

    # 3. Group unassigned Destinations by their names
    unassigned_destinations = unassigned_destinations.group_by { |destination| destination['normalized_name'] }

    # 4. Find possible existent Destination Group
    #  4.1. Remove special characters from Group's name (made in step 3)
    #  4.2. Split them by whitespaces and dashes
    #  4.3. Search in Database for Destination Group by name,
    #       where all splitted Group's words match splitted Destination Group's name
    #       (if Unassigned Destination does not contain of only Direction Name, allow assigning it to 'Fixed' DGs)
    #  4.4. If Destination Group found, assign Destinations to that group
    unassigned_destinations.keep_if do |group_name, destinations|
      splitted_group_name = group_name.split(' ')
      splitted_direction_name = Destination.split_destination_name(destinations.first['direction_name'])

      searchable_group_name = splitted_group_name.
          join("%' AND name LIKE '%").
          gsub("AND name LIKE '%and%'", "AND (name LIKE '%and%' OR name LIKE '%&%')")

      plausible_destination_groups = Destinationgroup.where("name LIKE '%#{searchable_group_name}%'").all
      plausible_destination_group = plausible_destination_groups.find do |destination_group|
        Destination.split_destination_name(destination_group.name).sort == splitted_group_name.sort
      end

      # If Unassigned Destination does not contain of only Direction Name, allow assigning it to 'Fixed' DGs
      #  (repeat above process, this time allowing 'fixed' in found DGs)
      if plausible_destination_group.blank? && (splitted_group_name - splitted_direction_name).present?
        plausible_destination_group = plausible_destination_groups.find do |destination_group|
          (Destination.split_destination_name(destination_group.name).sort - %w[fixed]) == splitted_group_name.sort
        end
      end

      # If we had Unassigned Destination with name contained 'fixed' and not any other special name
      #   and when removing Direction name from that Destination we still have a name
      #   (for example Austria - Fixed is not good in this step, so we skip it)
      #   (if it were Austria - Fixed Vienna, then it is ok, because Vienna is sufficient)
      # To such Destinations we try to find Destination Group once again, that does not have keyword 'fixed' in their name
      if plausible_destination_group.blank? && splitted_group_name.include?('fixed') &&
          (splitted_group_name - splitted_direction_name).present? &&
          (splitted_group_name & %w[mobile premium services other ngn]).blank?

        splitted_group_name = splitted_group_name - %w[fixed]
        searchable_group_name = splitted_group_name.
            join("%' AND name LIKE '%").
            gsub("AND name LIKE '%and%'", "AND (name LIKE '%and%' OR name LIKE '%&%')")

        plausible_destination_groups = Destinationgroup.where("name LIKE '%#{searchable_group_name}%'").all
        plausible_destination_group = plausible_destination_groups.find do |destination_group|
          Destination.split_destination_name(destination_group.name).sort == splitted_group_name.sort
        end
      end

      if plausible_destination_group
        Destination.where(
            prefix: destinations.map do |destination|
              destination['destinationgroup_id'] = plausible_destination_group.id
              destination['destinationgroup_name'] = plausible_destination_group.name
              assigned_destinations << destination

              destination['prefix']
            end
        ).update_all(destinationgroup_id: plausible_destination_group.id)
        next false
      else
        next true
      end
    end

    #  3.1. if group consist of only one Destination, decide what to do with it with pre-selected setting:
    #   3.1.1. Create a new group with it's name
    #          (no further modifications in this step required ('options[:individual_destination_action] == 1'))
    case options[:individual_destination_action].to_i
      when 2
        #   3.1.2. Assign it to Destination's (found by it's longest prefix) Destination Group
        unassigned_destinations.keep_if do |group_name, destinations|
          next(true) if destinations.size > 1

          destination = destinations.first
          shorter_longest_prefix_string = Application.shorter_longest_prefix_string(destination['prefix'].to_s, false)
          next(false) if shorter_longest_prefix_string.blank?

          destination_with_most_fitting_prefix = Destination.
              where("prefix IN (#{shorter_longest_prefix_string})").
              where('destinationgroup_id > 0').
              where(direction_code: destination['direction_code']).
              order('prefix DESC').first

          if destination_with_most_fitting_prefix.present? && destination_with_most_fitting_prefix.destinationgroup
            destination['destinationgroup_id'] = destination_with_most_fitting_prefix.destinationgroup.id
            destination['destinationgroup_name'] = destination_with_most_fitting_prefix.destinationgroup.name
            assigned_destinations << destination

            Destination.where(prefix: destination['prefix']).
                update_all(destinationgroup_id: destination_with_most_fitting_prefix.destinationgroup.id)
          end

          next false
        end
      when 0
        #   3.1.3. Skip it (remove them from further processing, will be fixed manually)
        unassigned_destinations.keep_if { |group_name, destinations| destinations.size > 1 }
    end

    # 5. For left unassigned Destinations create new Destination Group
    unassigned_destinations.each do |group_name, destinations|
      direction_code = destinations.first['direction_code'].downcase
      direction_name = destinations.first['direction_name'].downcase

      # Do not create new Destination Group if Unassigned Destination consists of only Direction Name
      group_name = (group_name.split(' ') - Destination.split_destination_name(direction_name))
      next if group_name.blank?

      new_destination_group_name = "#{direction_name} -"

      group_name.delete_if do |word|
        if %w[mobile fixed premium].include?(word)
          new_destination_group_name << " #{word}"
          true
        else
          false
        end
      end

      new_destination_group_name << " #{group_name.join(' ')}"
      new_destination_group_name = new_destination_group_name.humanize.gsub(/\b('?[a-z])/) { $1.capitalize }
      new_destination_group_name.strip!
      new_destination_group_name = new_destination_group_name[0..-3] if new_destination_group_name[-1] == '-'

      new_destination_group = Destinationgroup.create(name: new_destination_group_name, flag: direction_code)

      Destination.where(
          prefix: destinations.map do |destination|
            destination['destinationgroup_id'] = new_destination_group.id
            destination['destinationgroup_name'] = new_destination_group.name
            assigned_destinations << destination

            destination['prefix']
          end
      ).update_all(destinationgroup_id: new_destination_group.id)
    end

    {success: true, assigned_destinations: assigned_destinations}
  end

  def self.name_normalization(name)
    name = Destination.split_destination_name(name)

    Destination.name_normalization_values(0).each { |value| name.map! { |word| word.gsub(value[0], value[1]) } }
    name = name.join(' ')

    Destination.name_normalization_values(1).each { |value| name.gsub!(value[0], value[1]) }

    name.downcase
  end

  def self.name_normalization_values(type = 0)
    # Types
    # 0 - single words (when name is already splitted by space)
    # 1 - whole name
    # 2 - Special keywords
    case type
      when 2
        [
            ['t-mobile', 't(dash)mobile']
        ]
      when 1
        [
            [/Cook (islands|island|isl|is)/i, 'Cook Islands'],
            [/Cocos (islands|island|isl|is)/i, 'Cocos (Keeling) Islands'],
            [/Christmas (islands|island|isl|is)/i, 'Christmas Island'],
            [/Easter (islands|island|isl|is)/i, 'Easter Island'],
            [/Cayman (islands|island|isl|is)/i, 'Cayman Islands'],
            [/(Faeroe (islands|island|isl|is)|Faroe)/i, 'Faroe Islands'],
            [/(Faroe (islands|island|isl|is)|Faroe)/i, 'Faroe Islands'],
            [/(Falklands|(Falkland (islands|island|isl|is)))/i, 'Falkland Islands (Malvinas)'],
            [/Cote Divoire/i, 'Ivory Coast'],
            [/Cote D\'ivoire/i, 'Ivory Coast'],
            [/Guinea Bissau/i, 'Guinea-Bissau'],
            [/Guinea Republic/i, 'Guinea'],
            [/Marshall (islands|island|isl|is)/i, 'Marshall Islands'],
            [/Libya/i, 'Libyan Arab Jamahiriya'],
            [/Norfolk (islands|island|isl|is)/i, 'Norfolk Island'],
            [/Mayotte (islands|island|isl|is)/i, 'Mayotte'],
            [/Turks and Caicos (islands|island|isl|is)/i, 'Turks and Caicos Islands'],
            [/Russia(\s|-)/i, 'Russian Federation '],
            [/Ascension(\s*is\w*)?/i, 'Ascension Island'],
            [/Brunei(\s*darus\w*)?/i, 'Brunei Darussalam'],
            [/Antigua(\s*and\s*barb\w*)?/i, 'Antigua and Barbuda'],
            [/Bosnia Herzegovina/i, 'Bosnia and Herzegovina'],
            [/Somali Republic/i, 'Somalia'],
            [/Viet Nam/i, 'Vietnam'],
            [/Macau/i, 'Macao'],
            [/(St\.|St) Lucia/i, 'Saint Lucia'],
            [/St Kitts Nevis/i, 'Saint Kitts And Nevis'],
            [/St Vincents/i, 'Saint Vincent And The Grenadines'],
            [/Sao Tome Principe/i, 'Sao Tome And Principe'],
            [/Korea South/i, 'South Korea'],
            [/Trinidad Tobago/i, 'Trinidad And Tobago'],
            [/UK(\s|-)/i, 'United Kingdom '],
            [/USA(\s|-)/i, 'United States '],
            [/Turks Caicos(\s*is\w*)?/i, 'Turks and Caicos Islands'],
            [/Virgin Islands Gb/i, 'Virgin Islands, British'],
            [/Turks and Caicos(\s*is\w*)?/i, 'Turks and Caicos Islands']
        ]
      else
        [
            [/\A(FXD|FIX)\z/i, 'Fixed'],
            [/\A(MOB|M|CELLULAR)\z/i, 'Mobile'],
            [/\APREM\z/i, 'Premium'],
            [/\ASRVCS\z/i, 'Services'],
            [/\AOTHR\z/i, 'Other'],
            ['&', 'and'],
            [/\ARep\z/i, 'Republic']
        ]
    end
  end

  def self.split_destination_name(name)
    name = name.downcase.gsub('&', 'and')

    # Gsub special keywords, so that they would be safe when splitting
    Destination.name_normalization_values(2).each { |value| name.gsub!(value[0], value[1]) }

    # Split by dashes (-), whitespaces ( ) and commas (,)
    name = name.split(/[-\s,]/).reject(&:empty?)

    # Bring back special keywords as they were
    Destination.name_normalization_values(2).each { |value| name.map! { |word| word.gsub(value[1], value[0]) } }

    name
  end
end
