jQuery(document).ready(function($) {
    var rec_type = $('#auto_aggregate_export_recurrence_type');
    var period_type = $('#auto_aggregate_export_period_type');
    var fre_types = [$('.auto_aggregate_export_frequency_type_1'),$('.auto_aggregate_export_frequency_type_2')];
    var fre_types_ids = [
                          [$('#auto_aggregate_export_frequency_type_1'),$('#auto_aggregate_export_frequency_type_2')],
                          [$('#auto_aggregate_export_recurrence_type'),$('#auto_aggregate_export_recurrence_type')], // Filled with fake values, because we do not have frequency type on weekly period
                          [$('#auto_aggregate_export_frequency_type_21'),$('#auto_aggregate_export_frequency_type_22')],
                          [$('#auto_aggregate_export_frequency_type_31'),$('#auto_aggregate_export_frequency_type_32')],
                          [$('#auto_aggregate_export_recurrence_type'),$('#auto_aggregate_export_recurrence_type')] // Filled with fake values, because we do not have frequency type on hourly period
                         ];

    var fre_types_by_rec_type = [
                                  [$('.fre_type_1_daily'), $('.fre_type_2_daily')],
                                  [$('.fre_type_1_weekly'), $('.fre_type_2_weekly')],
                                  [$('.fre_type_1_monthly'), $('.fre_type_2_monthly')],
                                  [$('.fre_type_1_yearly'), $('.fre_type_2_yearly')],
                                  [$('.fre_type_1_hourly'), $('.fre_type_2_hourly')]
                                ];

    // initialize

    set_recurrence_pattern_details(rec_type.val());
    set_hours_of_day(period_type.val());

    var rec_type_val = rec_type.val() - 1;
    if (fre_types_ids[rec_type_val][0].prop("checked")) {
      enableAllChildrens(fre_types_by_rec_type[rec_type_val][0]);
      clearDisableAllChildrens(fre_types_by_rec_type[rec_type_val][1]);
    } else if (fre_types_ids[rec_type_val][1].prop("checked")) {
      enableAllChildrens(fre_types_by_rec_type[rec_type_val][1]);
      clearDisableAllChildrens(fre_types_by_rec_type[rec_type_val][0]);
    } else {
      clearChildrens(fre_types_by_rec_type[rec_type_val][1]);
      clearChildrens(fre_types_by_rec_type[rec_type_val][0]);
    }

    // On Recurrence type change
    rec_type.change(function () {
      set_recurrence_pattern_details(rec_type.val());
    });

    period_type.change(function() {
      set_hours_of_day(period_type.val());
    });

    // On Frequency type change
    fre_types.forEach(function(element) {
      element.change(function (){
        var rec_type_val = rec_type.val() - 1;
        if (element == fre_types[0]){
          enableAllChildrens(fre_types_by_rec_type[rec_type_val][0]);
          clearDisableAllChildrens(fre_types_by_rec_type[rec_type_val][1]);
        } else {
          enableAllChildrens(fre_types_by_rec_type[rec_type_val][1]);
          clearDisableAllChildrens(fre_types_by_rec_type[rec_type_val][0]);
        }
      });
    });

});

function set_recurrence_pattern_details(rec_type) {
  var daily = jQuery('.daily');
  var weekly = jQuery('.weekly');
  var monthly = jQuery('.monthly');
  var yearly = jQuery('.yearly');
  var hourly = jQuery('.hourly');
  var rec_types = [daily, weekly, monthly, yearly, hourly];
  turnOn(rec_types, rec_type);
}

function set_hours_of_day(period_type_val) {
  var hours_of_day = jQuery('.hours_of_day');
  if (period_type_val == 1){
    hours_of_day.hide();
    hours_of_day.prop("disabled", true);
  } else{
    hours_of_day.show();
    hours_of_day.prop("disabled", false);
  }
}
// Hide and Disable all elements of other rec type
// It is very important to disable hidden elements, otherwise
// hidden elements can overwrite visible params.
function turnOn(rec_types, rec_type_index) {
   rec_types.forEach(function(element){
     if (element != rec_types[rec_type_index - 1]) {
       element.hide();
       clearDisableAllChildrens(element);
     }
   });
   rec_type = rec_types[rec_type_index - 1];
   rec_type.show();
   enableAllChildrens(rec_type);
}

function clearDisableAllChildrens(element) {
  var val = "";
  clearChildrens(element);
  var i;
  for(i = 0; i < 5; i++) {
    element.children().prop("disabled", true);
    element = element.children();
  }
}

function clearChildrens(element) {
  var i;
  for(i = 0; i < 5; i++) {
    element.children().each(function () { setVal(this) });
    element = element.children();
  }
}

function enableAllChildrens(element) {
  var i;
  for(i = 0; i < 5; i++) {
    element.children().prop("disabled", false);
    element = element.children();
  }
}

function setVal(element) {
   if (element.tagName == 'OPTION' || element.getAttribute('type') == 'radio'){
   } else if(element.tagName == 'SELECT') {
     element.selectedIndex = 0;
   } else {
     element.value = "";
   }
}