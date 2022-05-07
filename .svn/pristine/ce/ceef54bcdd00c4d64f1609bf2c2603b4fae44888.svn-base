$(document).ready(function(){
	initEffectiveFromUpdater();
	$('#till').css('cursor', 'pointer');
});

function initEffectiveFromUpdater(){
	effective_from_ajax = null;

	var web_dir = $('#web_dir').val();
	var url = web_dir + '/tariffs/update_effective_from_ajax'
	$("#date").data('done-clicked', 'no');

	$(document).on('click', 'button', function () {
	    var clickedElement = $(this);
	    if(clickedElement.is(':button') && clickedElement.text() == 'Done'){
	    	doneClicked();
	    }
	});

	$(document).keypress(function(e) {
	    if(e.which == 13) {
	        doneClicked();
	    }
	});

	$("#date").on('select', function(){
		var till = $('#till').val();
		var time2 = $('#time2').val();
		var rateId = $('#rateId').val();
		updateEffectiveFrom(url, till, time2,rateId, $("#date").data('done-clicked'));
	})

	$('#date').click(function(){
		$('#till').css('cursor', 'text');
	});

	$('#time').click(function(){
		$('#till').css('cursor', 'text');
	});

}

function doneClicked(){
  $("#date").data('done-clicked', 'yes');
	$("#date").trigger("select");
}

function updateEffectiveFrom(url, date, time, rate_id, doneClicked){
	if($("#date").data('done-clicked') != undefined && time != ''){
		if(effective_from_ajax){
			effective_from_ajax.abort();
		}
		effective_from_ajax = 	$.ajax({
									url: url,
									data: {date: date, time: time, id: rate_id, done_clicked: doneClicked}
								}).done(function(response){
									$("#date").data('done-clicked', 'no');
									var obj = JSON.parse(response);
									if(obj.error) return false;
									$('#till').val(obj.date);
									$('#time2').val(obj.time);
								})
	}

	$('#till').css('cursor', 'pointer');
}