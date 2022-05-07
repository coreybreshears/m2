$(document).ready(function() {
    initQuickRatesBuilder();

    $(document).click(function(e){
        var target = $(e.target);
        if((target).hasClass('livesearch-item')) $('#destination').val(target.text());
        $('.destination-livesearch').hide();
    });

    $('#refine_destination, #refine_prefix, #clear_search').click(function(){ $("#spinner2").show(); });

    $('#clear_manage_rates').click(function(){
        $('#manage_rates_ratedetail_rate, #manage_rates_ratedetail_connection_fee, #manage_rates_ratedetail_increment_s, #manage_rates_ratedetail_min_time').val('');
        $('#manage_rates_ratedetail_blocked').val(-1).change();
        jcf.customForms.refreshAll();
        clear_change_parameters();
    });
});

var destinations = [];

function initQuickRatesBuilder() {
    var url = $('#create-form').attr('prefix-checker-url');
    var rate_prefix_input = $('#rate_prefix');

    if (rate_prefix_input.val().length > 0) {
        rate_prefix_input.val(rate_prefix_input.val().trim());
        checkPrefix(url, rate_prefix_input.val().trim());
    } else {
        $("#button_id").attr('disabled', true);
    }

    rate_prefix_input.on('input', function () {
        rate_prefix_input.val(rate_prefix_input.val().trim());
        checkPrefix(url, rate_prefix_input.val().trim())
    });
}

function checkPrefix(url, prefix) {
    $.ajax({
        url: url,
        data: {prefix: prefix},
        async: true,
        dataType: 'html',
        success: function(response) {
            $('#prefix-availability').html(response);
            //The prefix availability is attached to an image tag, since the current API gives a single HTML response.
            if(response.search('img') == -1) {
                $("#button_id").attr('disabled', true);
            } else {
                $("#button_id").removeAttr('disabled');
            }
        }
    });
}

function download_destinations(url, tariff_id){
    $.ajax({
        url: url,
        type: "GET",
        async: true,
        dataType: "json",
        data: {tariff_id: tariff_id},
        success: function (data) {
            destinations = JSON.parse(data['data']);
        }
   });
}

function update_destination_livesearch(query){
    var filtered_dsts = filterItems(destinations, query);
    $('.destination-livesearch').html('');
    if (query == '' || filtered_dsts.length == 0){
        $('.destination-livesearch').css('display', 'none');
    }else{
        $('.destination-livesearch').css('display', 'block');
        filtered_dsts.forEach(function(item){
            $('.destination-livesearch').append('<li class="livesearch-item">' + item + '</li>')
        });

        if ($('.destination-livesearch').children().length >= 8){
            $('.destination-livesearch').css('height', '250px');
        }else{
            $('.destination-livesearch').css('height', 'initial');
        }
    }
}

function filterItems(arr, query) {
  if (query.startsWith('%') && query.endsWith('%')){
      if(query.endsWith('%')) query = query.slice(0, -1);
      return arr.filter(function(el) {
        return el.toLowerCase().indexOf(query.toLowerCase().substring(1)) !== -1
    });
  }

  if (query.startsWith('%')){
      return arr.filter(function(el) {
        return el.toLowerCase().endsWith(query.toLowerCase().substring(1))
    });
  }

  if (!query.includes('%') || query.endsWith('%')){
      if(query.endsWith('%')) query = query.slice(0, -1);
      return arr.filter(function(el) {
        return el.toLowerCase().startsWith(query.toLowerCase())
    });
  }

}

function get_prefixes(url, tariff_id){
    $.ajax({
        url: url,
        type: "GET",
        async: true,
        dataType: "json",
        data: {
            tariff_id: tariff_id,
            dst_name: $('#destination').val()
        },
        success: function (data) {
            $('#prefix').val(JSON.parse(data['data']).join(', '))
        }
   });
}


function clear_change_parameters(){
    $.ajax({
        url: Web_Dir + '/tariffs/manage_rates_clear_change_params',
        type: "GET",
        async: true,
        dataType: "json",
        data: { clear: 'clear_manage_rates' },
        success: function (data) {
            console.log(data['data']['message'])
        }
   });
}
