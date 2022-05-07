var dial_peer_dst_regexp_value = $('#dial_peer_dst_regexp').val();

$(document).ready(function() {
    initDialPeersForm();
});

function initDialPeersForm() {
    var remoteDgUrl = $('.details-form').attr('data-remote-dg-url');
    var selectFlag = false;
    initRegexpRadioButton();
    initTariffButton();
    initMarginFields();
    initNoFollowCheckbox();
}

function initRegexpRadioButton() {
    var adjustProperties = function() {
        $('#dial_peer_dst_regexp').prop('disabled', false).val(dial_peer_dst_regexp_value);
        $('#dial_peer_tariff_id').prop('disabled', true);
        $('#destination-group-row').attr('hidden', '');
        jcf.customForms.refreshAll();
    };

    if($('#dial_peer_destination_by_regexp').attr('checked')) {
        adjustProperties();
    }

    $('#dial_peer_destination_by_regexp').on('change', function() {
        adjustProperties();
    })
}

function initTariffButton() {
    var adjustProperties = function() {
        dial_peer_dst_regexp_value = $('#dial_peer_dst_regexp').val();
        $('#dial_peer_dst_regexp').prop('disabled', true).val('');
        $('#dial_peer_tariff_id').prop('disabled', false);
        $('#destination-group-row').removeAttr('hidden');
        jcf.customForms.refreshAll();
    };

    if($('#dial_peer_destination_by_tariff_id').attr('checked')) {
        adjustProperties();
    }

    $('#dial_peer_destination_by_tariff_id').on('change', function() {
        adjustProperties();
    })
}

function initMarginFields(){
    var minimal_margin = $('#dial_peer_minimal_rate_margin');
    var minimal_margin_percent = $('#dial_peer_minimal_rate_margin_percent');

    minimal_margin.on('click', function() {
        $('#dial_peer_minimal_rate_margin_percent').val('');
    });

    minimal_margin_percent.on('click', function() {
        $('#dial_peer_minimal_rate_margin').val('');
    });

    minimal_margin_percent.on('change', function() {
        $('#dial_peer_minimal_rate_margin').val('');
    });

    minimal_margin.on('change', function() {
        $('#dial_peer_minimal_rate_margin_percent').val('');
    })
}

function initNoFollowCheckbox(){
    var dp_tp_priority = $('#dial_peer_tp_priority');

    if (dp_tp_priority.val() != 'percent'){
        $('#no_follow').hide();
    }

    dp_tp_priority.on('change', function() {
        if (dp_tp_priority.val() == 'percent'){
            $('#no_follow').show();
        } else {
            $('#no_follow').hide();
        }
    })
}