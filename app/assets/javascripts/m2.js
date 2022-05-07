function change_selection_edit_link(selection, selection_edit_link, selection_edit_link_url, false_values) {
    var selection_value = selection.val();

    if (selection_value && (false_values && (false_values.indexOf(selection_value) === -1))) {
        selection_edit_link.html('<a href="' + Web_Dir + selection_edit_link_url + selection_value + '" id="' + selection_edit_link.attr('id') + selection_value + '"><img alt="Edit" src="' + Web_Dir + '/images/icons/edit.png" title="Edit"></a>');
    } else {
        selection_edit_link.html('<img alt="Edit" src="' + Web_Dir + '/images/icons/edit_faded.png" title="Edit">');
    }
}
function change_selection_details_link(selection, selection_details_link, selection_details_link_url, false_values) {
    var selection_value = selection.val();

    if (selection_value && (false_values && (false_values.indexOf(selection_value) === -1))) {
        selection_details_link.html('<a href="' + Web_Dir + selection_details_link_url + selection_value + '" id="' + selection_details_link.attr('id') + selection_value + '"><img alt="Details" src="' + Web_Dir + '/images/icons/details.png" title="Details"></a>');
    } else {
        selection_details_link.html('<img alt="Details" src="' + Web_Dir + '/images/icons/details.png" title="Details">');
    }
}

function find_in_array_by_int(array, key, value){
    for (var i=0; i < array.length; i++) {
        if (array[i][key] == value) {
            return array[i];
        }
    }
}

function find_in_array_by_string(array, key, value){
    for (var i=0; i < array.length; i++) {
        if (array[i][key] === value) {
            return array[i];
        }
    }
}