var updatableCells;
var initialValues = {};
var KEYCODE_ESCAPE = 27;
var KEYCODE_ENTER = 13;

$(document).ready(function() {
    init();
});

function init() {
    updatableCells = $("input[id^='percent'], input[id^='weight'], input[id^='cps'], input[id^='call_limit']");

    updatableCells.bind("change", function() {
            requestUpdate($(this));
            requestUpdateErorrs();
    });

    $(document).keydown(function(event) {
        if (event.keyCode == KEYCODE_ESCAPE) {
            updatableCells.each(function() {
                resetElement($(this));
            });
        }

        if (event.keyCode == KEYCODE_ENTER) {
            updatableCells.each(function() {
                requestUpdate($(this));
            });
        }
    });
}

function requestUpdateErorrs() {
    updatableCells = $("[status='error']");
     updatableCells.each(function() {
        requestUpdate($(this));
    });
}

function displayError(error) {
    var currentErrorBox = $('.error-box');
    var updatedErrorBox = initErrorBox(error);
    if(currentErrorBox.length <= 0) {
        $('.head-section').append(updatedErrorBox);
    } else {
        currentErrorBox.html(updatedErrorBox.html());
    }
    initCloseBlock();
}

function displaySuccess(success) {
    var currentSuccessBox = $('.success-box');
    var updatedSuccessBox = initSuccessBox(success);
    if(currentSuccessBox.length <= 0) {
        $('.head-section').append(updatedSuccessBox);
    } else {
        currentSuccessBox.html(updatedSuccessBox.html());
    }
    initCloseBlock();
}

function initErrorBox(error) {
    var errorBox = $('<div/>').attr({class: 'error-box'});
    errorBox.html('<span class="text" id="status">' + error + '</span><a href="#" class="close">Close</a>');
    return errorBox;
}

function initSuccessBox(success) {
    var successBox = $('<div/>').attr({class: 'success-box'});
    successBox.html('<span class="text" id="status">' + success + '</span><a href="#" class="close">Close</a>');
    return successBox;
}


function updateErrorElement(element) {

    element.attr('status', 'error');
    console.log(element);

}

function updateSuccessElement(element) {
    element.removeAttr("status")
}

function requestUpdate(element) {
    var input = element.find('input');
    console.log(element);
    console.log(element.attr('value'))

        var TerminationPointId = element.attr('id').match(/\d+$/)[0];
        var attributeName = 'termination_point[' + element.attr('name') + ']';

        var requestData = {id: TerminationPointId};
        requestData[attributeName] =  element.attr('value');
        requestData['attribute_name'] =  element.attr('name');

        $.ajax({
            url: Web_Dir + "/dial_peers/update_termination_point",
            data: requestData,
            async: true,
            error: function(response, error, full_error){
                console.log('Ajax Error:');
                console.log(response);
                console.log(error);
                console.log(full_error);
            },
            success: function(response) {
                console.log('Ajax Success:');
                console.log(response);
                if(response[0] == 'success') {
                    $('.error-box').hide();
                    $('.success-box').show();
                    updateSuccessElement(element);
                    displaySuccess(response[1])
                } else {
                    $('.error-box').show();
                    $('.success-box').hide();
                    updateErrorElement(element);
                    displayError(response);
                }
            }
        });

}