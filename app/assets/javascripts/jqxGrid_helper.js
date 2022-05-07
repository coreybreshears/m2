/*
 * Visual data functions for jqxGrid table
 */

function nice_billsec(billsec, time_format) {
    var nice_time;
    var hours, minutes, seconds;

    if (time_format == '%H:%M:%S') {
        hours = ~~(billsec / 3600);
        minutes = ~~((billsec % 3600) / 60);
        seconds = billsec % 60;

        hours = (hours < 10) ? ('0' + hours) : hours;

        nice_time = hours + ':' + ('0' + minutes).slice(-2) + ':' + ('0' + seconds).slice(-2);
    } else {
        minutes = ~~(billsec / 60);
        seconds = billsec % 60;

        minutes = (minutes < 10) ? ('0' + minutes) : minutes;

        nice_time = minutes + ':' + ('0' + seconds).slice(-2);
    }

    return nice_time
}

function render_flag(flag_name, web_dir) {
    var flag_icon;

    if (flag_name && flag_name != '') {
        flag_icon = '&nbsp;<img alt="' + flag_name + '" src="' + web_dir + '/images/flags/' + flag_name + '.jpg" style="border-style:none" title="' + flag_name.toUpperCase() + '">';
    } else {
        flag_icon = '';
    }

    return flag_icon
}

function fix_column_width(jqxgrid_name) {
    var jqxgrid = jQuery("#" + jqxgrid_name);
    var grid_columns = jQuery.grep(jqxgrid.jqxGrid('columns').records, function(column) { return column.hidden == false });
    var used_width = 0, table_width = parseInt(document.getElementById("content" + jqxgrid_name).style.width);

    jQuery.each(
        grid_columns,
        function(index, column) {

            jqxgrid.jqxGrid('autoresizecolumn', column.datafield, 'all');
            used_width += column.width;
        }
    );

    var spare_width = 0, fixed_width = 0, fixed_width_last_column = 0;
    var column_count = grid_columns.length;
    if (used_width < table_width) {
        spare_width = table_width - used_width;
        fixed_width = parseInt(spare_width / column_count);
        fixed_width_last_column = spare_width % column_count;

        jQuery.each(
            grid_columns,
            function(index, column) {
                var set_width = column.width;

                if (index == (column_count - 1)) {
                    set_width += fixed_width + fixed_width_last_column;
                } else {
                    set_width += fixed_width;
                }
                jqxgrid.jqxGrid('setcolumnproperty', column.datafield, 'width', set_width);
            }
        );
    }
}

function fix_column_width_fast(jqxgrid_name) {
    // Fast because code removed from jqxgrid.columnsresize.js

    var jqxgrid = jQuery("#" + jqxgrid_name);
    var grid_columns = jQuery.grep(jqxgrid.jqxGrid('columns').records, function(column) { return column.hidden == false });
    var used_width = 0, table_width = parseInt(document.getElementById("content" + jqxgrid_name).style.width);

    jqxgrid.jqxGrid('autoresizecolumns', 'all');

    used_width = jQuery("#contenttable" + jqxgrid_name).width();

    var spare_width = 0, fixed_width = 0, fixed_width_last_column = 0;
    var column_count = grid_columns.length;
    if (used_width < table_width) {
        spare_width = table_width - used_width;
        fixed_width = parseInt(spare_width / column_count);
        fixed_width_last_column = spare_width % column_count;
        jQuery.each(
            grid_columns,
            function(index, column) {
                var set_width = column.width;

                if (index == (column_count - 1)) {
                    set_width += fixed_width + fixed_width_last_column;
                } else {
                    set_width += fixed_width;
                }
                jqxgrid.jqxGrid('setcolumnproperty', column.datafield, 'width', set_width);
            }
        );
    }
}

function nice_user_link(nice_user_and_id, web_dir) {
          var user_id_arr = nice_user_and_id.split(" ");
          var id = user_id_arr.pop();
          var nice_name = user_id_arr.join(" ");
          return '<a href="'+ web_dir + '/users/edit/' + id + '">' + nice_name + '</a></div>';
}

function session_sorting(jqxgrid_name, web_dir, session_column, session_direction, controller, action) {
    var jqxgrid = jQuery("#" + jqxgrid_name);

    var s_column = session_column;
    var s_direction = session_direction;
    if (s_column && s_column != '' && s_direction && s_direction != '') {
        jqxgrid.jqxGrid('sortby', s_column, s_direction);
    }

    jqxgrid.on('sort', function(event) {
        var sortInfo = event.args.sortinformation;
        var column = sortInfo.sortcolumn;
        var direction = sortInfo.sortdirection.ascending ? 'asc' : 'desc';

        jQuery.ajax({
            url: web_dir + '/application/jqxgrid_sort',
            type: 'POST',
            cache: false,
            dataType: 'html',
            data: {fcontroller: controller, faction: action, column: column, direction: direction, grid: jqxgrid_name},
            beforeSend: function (xhr) {
                xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
            }
        });
    });
}

// This function for automatically retrieving JqxTable column names and working with them
//   quite fast when not too many columns present in a table and less hassle for reimplementation on different tables
function jqx_table_settings_auto(web_dir, json_current_settings) {
    var jqxgrid_name = json_current_settings['table_identifier'].split(',').pop();
    var jqxgrid = jQuery("#" + jqxgrid_name);
    var jqxgrid_column_visibility = jQuery("#" + jqxgrid_name + '_column_visibility');
    var jqxgrid_column_visibility_check_all = jQuery("#" + jqxgrid_name + '_column_visibility_check_all');
    var jqxgrid_column_visibility_uncheck_all = jQuery("#" + jqxgrid_name + '_column_visibility_uncheck_all');
    var jqxgrid_column_visibility_check_all_flag = false;
    var column_orders_updated;
    var column_visibility_updated;
    var all_columns = [];

    jqxgrid.jqxGrid('beginupdate');
    json_current_settings['column_order'].split(',').forEach( function(column_name, index) {
            try {
                jqxgrid.jqxGrid('setcolumnindex', column_name, index, false);
            } catch (error) {
                // Either column_order is still empty (first time page loaded), or non existent column is being ordered
                //   (because of possible update after which specific column was removed/renamed)
            }
        }
    );
    jqxgrid.jqxGrid('endupdate');

    for (var key in jqxgrid.jqxGrid('getstate').columns) {
        if (jqxgrid.jqxGrid('getstate').columns.hasOwnProperty(key)) {
            all_columns.push(key);
        }
    }

    jqxgrid.on('columnreordered', function (event) {
        column_orders_updated = [];

        jqxgrid.jqxGrid('beginupdate');
        for (var key in jqxgrid.jqxGrid('getstate').columns) {
            if (jqxgrid.jqxGrid('getstate').columns.hasOwnProperty(key)) {
                column_orders_updated.push(key);
            }
        }
        jqxgrid.jqxGrid('endupdate');

        jQuery.ajax({
            url: web_dir + '/application/jqxgrid_table_settings_update',
            type: 'POST',
            cache: false,
            dataType: 'html',
            data: {
                user_id: json_current_settings['user_id'],
                table_identifier: json_current_settings['table_identifier'],
                column_orders_updated: column_orders_updated.join(',')
            },
            beforeSend: function (xhr) {
                xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
            }
        });
    });

    if (json_current_settings['newly_created'] != 0) {
        jQuery.ajax({
            url: web_dir + '/application/jqxgrid_table_settings_update',
            type: 'POST',
            cache: false,
            dataType: 'html',
            data: {
                user_id: json_current_settings['user_id'],
                table_identifier: json_current_settings['table_identifier'],
                column_visibility_updated: all_columns.join(','),
                remove_newly_created: true
            },
            beforeSend: function (xhr) {
                xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
            }
        });
    }

    if (jqxgrid_column_visibility.length > 0) {

        if (json_current_settings['newly_created'] == 0) {
            jqxgrid.jqxGrid('beginupdate');
            all_columns.forEach(function (item) {
                jqxgrid.jqxGrid('hidecolumn', item);
            });
            jqxgrid.jqxGrid('endupdate');
        }

        jqxgrid.jqxGrid('beginupdate');
        json_current_settings['column_visibility'].split(',').forEach( function(column_name) {
                try {
                    jqxgrid.jqxGrid('showcolumn', column_name);
                } catch (error) {
                    // Either column_visibility is empty (no visible columns), or non existent column is being ordered
                    //   (because of possible update after which specific column was removed/renamed)
                }
            }
        );
        jqxgrid.jqxGrid('endupdate');

        var listSource = [];
        var label;

        all_columns.forEach(function (key) {
            label = jqxgrid.jqxGrid('getstate').columns[key]['text'].trim();

            if (label == '') {
                // Titleize
                label = key.replace('_', ' ').replace(/\w\S*/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
            }

            listSource.push({
                label: label,
                value: key,
                checked: !jqxgrid.jqxGrid('getstate').columns[key]['hidden']
            });
        });

        jqxgrid_column_visibility.jqxListBox({ source: listSource, checkboxes: true, width: '100%' });

        if (jqxgrid_column_visibility_check_all.length > 0) {
            jqxgrid_column_visibility_check_all.on('click', function () {
                jqxgrid_column_visibility_check_all_flag = true;
                jqxgrid_column_visibility.jqxListBox('checkAll');

                jqxgrid_column_visibility.blur();
                jqxgrid.jqxGrid('beginupdate');
                all_columns.forEach(function (item) {
                    jqxgrid.jqxGrid('showcolumn', item);
                });
                jqxgrid.jqxGrid('endupdate');

                fix_column_width_fast(jqxgrid_name);

                jQuery.ajax({
                    url: web_dir + '/application/jqxgrid_table_settings_update',
                    type: 'POST',
                    cache: false,
                    dataType: 'html',
                    data: {
                        user_id: json_current_settings['user_id'],
                        table_identifier: json_current_settings['table_identifier'],
                        column_visibility_updated: all_columns.join(',')
                    },
                    beforeSend: function (xhr) {
                        xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
                    }
                });

                jqxgrid_column_visibility_check_all_flag = false;
            });
        }

        if (jqxgrid_column_visibility_uncheck_all.length > 0) {
            jqxgrid_column_visibility_uncheck_all.on('click', function () {
                jqxgrid_column_visibility_check_all_flag = true;
                jqxgrid_column_visibility.jqxListBox('uncheckAll');

                jqxgrid_column_visibility.blur();
                jqxgrid.jqxGrid('beginupdate');
                all_columns.forEach(function (item) {
                    jqxgrid.jqxGrid('hidecolumn', item);
                });
                jqxgrid.jqxGrid('endupdate');

                fix_column_width_fast(jqxgrid_name);

                jQuery.ajax({
                    url: web_dir + '/application/jqxgrid_table_settings_update',
                    type: 'POST',
                    cache: false,
                    dataType: 'html',
                    data: {
                        user_id: json_current_settings['user_id'],
                        table_identifier: json_current_settings['table_identifier'],
                        column_visibility_updated: ''
                    },
                    beforeSend: function (xhr) {
                        xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
                    }
                });

                jqxgrid_column_visibility_check_all_flag = false;
            });
        }

        jqxgrid_column_visibility.on('checkChange', function (event) {
            if (jqxgrid_column_visibility_check_all_flag) {
                return
            }

            jqxgrid_column_visibility.blur();
            jqxgrid.jqxGrid('beginupdate');
            if (event.args.checked) {
                jqxgrid.jqxGrid('showcolumn', event.args.value);
            }
            else {
                jqxgrid.jqxGrid('hidecolumn', event.args.value);
            }
            jqxgrid.jqxGrid('endupdate');

            column_visibility_updated = [];

            for (var key in jqxgrid.jqxGrid('getstate').columns) {
                if (jqxgrid.jqxGrid('getstate').columns.hasOwnProperty(key)) {
                    if (!jqxgrid.jqxGrid('getstate').columns[key]['hidden']) {
                        column_visibility_updated.push(key);
                    }
                }
            }

            fix_column_width_fast(jqxgrid_name);

            jQuery.ajax({
                url: web_dir + '/application/jqxgrid_table_settings_update',
                type: 'POST',
                cache: false,
                dataType: 'html',
                data: {
                    user_id: json_current_settings['user_id'],
                    table_identifier: json_current_settings['table_identifier'],
                    column_visibility_updated: column_visibility_updated.join(',')
                },
                beforeSend: function (xhr) {
                    xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
                }
            });
        });
    }
}

function jqx_table_settings(web_dir, json_current_settings, all_possible_columns) {
    var jqxgrid_name = json_current_settings['table_identifier'].split(',').pop();
    var jqxgrid = jQuery("#" + jqxgrid_name);
    var jqxgrid_column_visibility = jQuery("#" + jqxgrid_name + '_column_visibility');
    var jqxgrid_column_visibility_check_all = jQuery("#" + jqxgrid_name + '_column_visibility_check_all');
    var jqxgrid_column_visibility_uncheck_all = jQuery("#" + jqxgrid_name + '_column_visibility_uncheck_all');
    var jqxgrid_column_visibility_apply = jQuery("#" + jqxgrid_name + '_column_visibility_apply');
    var column_orders_updated;
    var column_visibility_updated;

    jqxgrid.jqxGrid('beginupdate');
    json_current_settings['column_order'].split(',').forEach( function(column_name, index) {
            try {
                jqxgrid.jqxGrid('setcolumnindex', column_name, index, false);
            } catch (error) {
                // Either column_order is still empty (first time page loaded), or non existent column is being ordered
                //   (because of possible update after which specific column was removed/renamed)
            }
        }
    );
    jqxgrid.jqxGrid('endupdate');

    jqxgrid.on('columnreordered', function (event) {
        column_orders_updated = [];

        jqxgrid.jqxGrid('beginupdate');
        for (var key in jqxgrid.jqxGrid('getstate').columns) {
            if (jqxgrid.jqxGrid('getstate').columns.hasOwnProperty(key)) {
                column_orders_updated.push(key);
            }
        }
        jqxgrid.jqxGrid('endupdate');

        jQuery.ajax({
            url: web_dir + '/application/jqxgrid_table_settings_update',
            type: 'POST',
            cache: false,
            dataType: 'html',
            data: {
                user_id: json_current_settings['user_id'],
                table_identifier: json_current_settings['table_identifier'],
                column_orders_updated: column_orders_updated.join(','),
                remove_newly_created: true
            },
            beforeSend: function (xhr) {
                xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
            }
        });
    });

    if (jqxgrid_column_visibility.length > 0) {

        var listSource = [];
        for (var key in all_possible_columns) {
            listSource.push({
                label: all_possible_columns[key],
                value: key,
                checked: jqxgrid.jqxGrid('getstate').columns.hasOwnProperty(key)
            });
        }
        jqxgrid_column_visibility.jqxListBox({ source: listSource, checkboxes: true, width: '100%' });

        if (jqxgrid_column_visibility_check_all.length > 0) {
            jqxgrid_column_visibility_check_all.on('click', function () {
                jqxgrid_column_visibility.jqxListBox('checkAll');
                jqxgrid_column_visibility.blur();
            });
        }

        if (jqxgrid_column_visibility_uncheck_all.length > 0) {
            jqxgrid_column_visibility_uncheck_all.on('click', function () {
                jqxgrid_column_visibility.jqxListBox('uncheckAll');
                jqxgrid_column_visibility.blur();
            });
        }

        jqxgrid_column_visibility.on('checkChange', function (event) {
            jqxgrid_column_visibility.blur();
        });

        jqxgrid_column_visibility_apply.on('click', function (event) {
            jqxgrid_column_visibility.blur();

            column_visibility_updated = [];
            jqxgrid_column_visibility.jqxListBox('getCheckedItems').forEach(function (item) {
                column_visibility_updated.push(item.value);
            });

            jQuery.ajax({
                url: web_dir + '/application/jqxgrid_table_settings_update',
                type: 'POST',
                cache: false,
                dataType: 'html',
                data: {
                    user_id: json_current_settings['user_id'],
                    table_identifier: json_current_settings['table_identifier'],
                    column_visibility_updated: column_visibility_updated.join(','),
                    remove_newly_created: true
                },
                beforeSend: function (xhr) {
                    xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
                },
                complete: function(xhr) {
                    location.reload(true);
                }
            });
        });
    }
}