var tariffId;
var lastMatch;

$(document).ready(function() {
	initUpdateRates();

	if($('#autocomplete').val().length > 0) {
	  onDestinationGroupSelect();
	}
});

function initUpdateRates() {
	detailsForm = $('.details-form');
	destinationsUrl = detailsForm.attr('destinations-url');
	tariffId = detailsForm.attr('tariff-id');

	//Disables submit on enter
	detailsForm.keypress(function(event) {
	  return event.keyCode != 13;
	});

	//Initializes the autocomplete field
	jQuery("#autocomplete").autocomplete({
        source: function (request, response) {
            if (request.term.length > 2) {
				updateDestinations();
            } else {
                renderDestinationRatesTable('');
                response('');
            }
        },
        select: function( event, ui ) {
		  $("#autocomplete").val( ui.item.label );
		  onDestinationGroupSelect();
		  return false;
		},
        close: function (event, ui) {
            onDestinationGroupSelect();
        },
		focus: function (event, ui) {
            event.preventDefault();
            $("#autocomplete").val(ui.item.label);
            onDestinationGroupSelect();
        },
		minlength:2,
	});

    $("#autocomplete").keyup(function() {
        if ( $('#autocomplete').val().length < 3) {
            renderDestinationRatesTable([]);
        }
    }
    );
}

function onDestinationGroupSelect() {
	updateDestinations();
}

function updateDestinations() {
	$.ajax({
		url: destinationsUrl,
		data: {tariff_id: tariffId, mask: $('#autocomplete').val()},
		async: true,
		dataType: 'json',
		success: function(response) {
			renderDestinationRatesTable(response);
		}
	});
}

function renderDestinationRatesTable(destinations) {
    if (destinations.length == 0) {
        $('#destination-group-field').val('');
        destinations = [{name: 'No Destinations', rate: ''}];
        $('#destination-count').text('');
    } else if (destinations.length > 1000) {
    	destinations = [{name: 'Too many Destinations to show', rate: ''}];
        $('#destination-count').text('');
    } else {
    	$('#destination-count').text('(' + destinations.length + ')');
    }
	table = $('#destinations-table');
	table.html('');
    var each_index = 0;

   	$.each(destinations, function() {
        each_index += 1;
		row = $('<tr/>').attr('row', each_index);
		row.append($('<td/>').attr('align', 'left').attr('name', each_index).text(this.name));
		row.append($('<td/>').attr('align', 'right').attr('rate', each_index).text(this.rate));
		table.append(row);
	});

}