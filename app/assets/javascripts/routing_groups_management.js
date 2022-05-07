var dialPeerId;

$(document).ready(function() {
    initDialPeerRoutingGroups();
});

function initDialPeerRoutingGroups() {
    detailsForm = $('.details-form');
    dpRoutingGroupsUrl = detailsForm.attr('dp-routing-groups-url');
    rgDialPeersAssignmentUrl = detailsForm.attr('rg-dial-peers-assignment-url');
    dialPeerId = detailsForm.attr('dial-peer-id');

    //Disables submit on enter
    detailsForm.keypress(function(event) {
        return event.keyCode != 13;
    });

    var delay = (function() {
        var timer = 0;
        return function(callback, ms){
            clearTimeout (timer);
            timer = setTimeout(callback, ms);
        };
    })();

    $("#rg-filter").keyup(function() {
            delay(function () {
                updateRoutingGroupsTables();
            }, 500);
        }
    );

    $('#rg-filter-clear').click(function() {
            $("#rg-filter").val('');
            updateRoutingGroupsTables();
        }
    );

    $('#rg-assign-all-not-assigned').click(function() {
            routingGroupAssignment('assign', -1);
        }
    );

    $('#rg-unassign-all-assigned').click(function() {
            routingGroupAssignment('unassign', -1);
        }
    );

    updateRoutingGroupsTables();
}

function updateRoutingGroupsTables() {
    $.ajax({
        url: dpRoutingGroupsUrl,
        data: {dial_peer_id: dialPeerId, mask: $('#rg-filter').val()},
        async: true,
        dataType: 'json',
        beforeSend: function(xhr) {
            $("#spinner2").show();
            // Protect from forgery, else rails will kill the session
            xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
        },
        success: function(response) {
            renderRoutingGroupsTables(response);
        },
        complete: function() {
            $("#spinner2").hide();
        },
        error: function(response, error, full_error){
            console.log('Ajax Error:');
            console.log(response);
            console.log(error);
            console.log(full_error);
        }
    });
}

function renderRoutingGroupsTables(routing_groups) {
    renderRoutingGroupsTable(routing_groups['not_assigned'], '#rg-not-assigned-table', '#rg-not-assigned-count', 'assign');
    renderRoutingGroupsTable(routing_groups['assigned'], '#rg-assigned-table', '#rg-assigned-count', 'unassign');
}

function renderRoutingGroupsTable(routing_groups, rg_table_id, rg_count_id, assignment_direction) {
    var routing_groups_size = routing_groups.length;
    if (routing_groups_size == 0) {
        routing_groups = [{name: 'No Routing Groups'}];
        $(rg_count_id).text('');
    } else {
        $(rg_count_id).text('(' + routing_groups.length + ')');
    }

    var rg_table = $(rg_table_id);
    rg_table.html('');
    var each_index = 0;

    $.each(routing_groups, function() {
        each_index += 1;
        row = $('<tr/>').attr('row', each_index).attr('rg_id', this.id);
        if (routing_groups_size > 0) {
            row.attr('class', 'dp-hoverable');
        }
        row.append($('<td/>').attr('align', 'left').attr('name', each_index).text(this.name));
        rg_table.append(row);
    });

    if (routing_groups_size > 0) {
        $(rg_table_id + ' tr').click(function() {
            routingGroupAssignment(assignment_direction, this.getAttribute('rg_id'));
        });
    }
}

function routingGroupAssignment(assignment_direction, rg_id) {
    $.ajax({
        url: rgDialPeersAssignmentUrl,
        data: {
            dial_peer_id: dialPeerId,
            assignment_direction: assignment_direction,
            routing_group_id: rg_id,
            mask: $('#rg-filter').val()
        },
        async: true,
        dataType: 'json',
        beforeSend: function(xhr) {
            $("#spinner2").show();
            // Protect from forgery, else rails will kill the session
            xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
        },
        success: function(response) {
            updateRoutingGroupsTables();
        },
        complete: function() {
            $("#spinner2").hide();
        },
        error: function(response, error, full_error){
            updateRoutingGroupsTables();
            console.log('Ajax Error:');
            console.log(response);
            console.log(error);
            console.log(full_error);
        }
    });
}