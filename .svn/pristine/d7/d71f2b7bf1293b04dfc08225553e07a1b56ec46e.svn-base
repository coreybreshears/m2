# Servers helper module
module ServersHelper
  def server_load(server)
    if server.is_a? Server
      output = ''
      stats = server.server_loadstats.last
      if stats
        output << '<table>'
        arr = [
                [_('hdd_util'), "#{stats.hdd_util} %"],
                [_('cpu_general_load'), "#{stats.cpu_general_load} %"],
                ([_('cpu_mysql_label'), "#{stats.cpu_mysql_load} %"] if server.db == 1),
                ([_('cpu_ruby_label'), "#{stats.cpu_ruby_load} %"] if server.gui == 1),
                ([_('cpu_asterisk_label'), "#{stats.cpu_asterisk_load} %"] if server.core == 1 && server.server_type == 'asterisk'),
                ([_('cpu_freeswitch_label'), "#{stats.cpu_freeswitch_load} %"] if server.core == 1 && server.server_type == 'freeswitch'),
                [_('cpu_loadstats1'), "#{stats.cpu_loadstats1}"],
              ]
        arr.compact.each do |label, content|
          output << ('<tr><td>' + label + ': </td><td>' + content + '</td></tr>')
        end
        output << '</table>'
        return output.html_safe
      else
        _('no_data_available')
      end
    end
  end

  def free_space_style(space)
    (0...server_free_space_limit).include?(space) ? 'style=background-color:#FFDDCC' : ''
  end
end
