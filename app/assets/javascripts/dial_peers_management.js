var routingGroupId;

$(document).ready(function() {
    initRoutingGroupDialPeers();
});

function initRoutingGroupDialPeers() {
    detailsForm = $('.details-form');
    rgDialPeersUrl = detailsForm.attr('rg-dial-peers-url');
    rgDialPeersAssignmentUrl = detailsForm.attr('rg-dial-peers-assignment-url');
    routingGroupId = detailsForm.attr('routing-group-id');

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

    $("#dp-filter").keyup(function() {
            delay(function () {
                updateDialPeersTables();
            }, 500);
        }
    );

    $('#dp-filter-clear').click(function() {
            $("#dp-filter").val('');
            updateDialPeersTables();
        }
    );

    $('#dp-assign-all-not-assigned').click(function() {
            dialPeerAssignment('assign', -1);
        }
    );

    $('#dp-unassign-all-assigned').click(function() {
            dialPeerAssignment('unassign', -1);
        }
    );

    updateDialPeersTables();
}

function updateDialPeersTables() {
    $.ajax({
        url: rgDialPeersUrl,
        data: {routing_group_id: routingGroupId, mask: $('#dp-filter').val()},
        async: true,
        dataType: 'json',
        beforeSend: function(xhr) {
            $("#spinner2").show();
            // Protect from forgery, else rails will kill the session
            xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
        },
        success: function(response) {
            renderDialPeersTables(response);
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

function renderDialPeersTables(dial_peers) {
    renderDialPeersTable(dial_peers['not_assigned'], '#dp-not-assigned-table', '#dp-not-assigned-count', 'assign');
    renderDialPeersTable(dial_peers['assigned'], '#dp-assigned-table', '#dp-assigned-count', 'unassign');
}

function renderDialPeersTable(dial_peers, dp_table_id, dp_count_id, assignment_direction) {
    var dial_peers_size = dial_peers.length;
    if (dial_peers_size == 0) {
        dial_peers = [{name: 'No Dial Peers'}];
        $(dp_count_id).text('');
    } else {
        $(dp_count_id).text('(' + dial_peers.length + ')');
    }

    var dp_table = $(dp_table_id);
    dp_table.html('');
    var each_index = 0;

    $.each(dial_peers, function() {
        each_index += 1;
        row = $('<tr/>').attr('row', each_index).attr('dp_id', this.id);
        if (dial_peers_size > 0) {
            row.attr('class', 'dp-hoverable');
        }
        row.append($('<td/>').attr('align', 'left').attr('name', each_index).text(this.name));
        dp_table.append(row);
    });

    if (dial_peers_size > 0) {
        $(dp_table_id + ' tr').click(function() {
            dialPeerAssignment(assignment_direction, this.getAttribute('dp_id'));
        });
    }
}

function dialPeerAssignment(assignment_direction, dp_id) {
    $.ajax({
        url: rgDialPeersAssignmentUrl,
        data: {
            routing_group_id: routingGroupId,
            assignment_direction: assignment_direction,
            dial_peer_id: dp_id,
            mask: $('#dp-filter').val()
        },
        async: true,
        dataType: 'json',
        beforeSend: function(xhr) {
            $("#spinner2").show();
            // Protect from forgery, else rails will kill the session
            xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
        },
        success: function(response) {
            updateDialPeersTables();
        },
        complete: function() {
            $("#spinner2").hide();
        },
        error: function(response, error, full_error){
            updateDialPeersTables();
            console.log('Ajax Error:');
            console.log(response);
            console.log(error);
            console.log(full_error);
        }
    });
}