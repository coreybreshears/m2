function pressed(dir, controller, action) {
	jQuery.ajax({
		url: dir,
		data: {controll: controller, act: action, "refine_results": "pressed"},
		async: true,
		beforeSend: function(xhr){
			xhr.setRequestHeader('X-CSRF-Token', jQuery('meta[name="csrf-token"]').attr('content'))
		},
		error: function(err){
			console.log(err);
		}
	});

    if (jQuery('.content-box').data('ResizeBox')) {
        jQuery('.content-box').data('ResizeBox').getResize();
    }

    var which_pressed = dir.split('_').pop();
    var check_for_forms = ['search', 'manage', 'create'];
    var form_id, form_attr, check_for_forms_others;

    check_for_forms.forEach( function(form_name) {
        if (form_name != which_pressed) {
            return;
        }

        form_id = '#' + form_name + '-form-button';
        form_attr = form_name + '_status';

        if (jQuery(form_id).attr(form_attr) == 'up') {
            jQuery(form_id).attr(form_attr, 'down');

            check_for_forms_others = check_for_forms.concat();
            check_for_forms_others.splice(check_for_forms_others.indexOf(form_name), 1);
            check_for_forms_others.forEach( function(form_name_other) {
                if (jQuery('#' + form_name_other + '-form-button').attr(form_name_other + '_status') == 'down') {
                    jQuery('#' + form_name_other + '-form-button').attr(form_name_other + '_status', 'up');
                }
            });

        } else if (jQuery(form_id).attr(form_attr) == 'down') {
            jQuery(form_id).attr(form_attr, 'up');
        }

    });
};

jQuery(function ($) {
    var csrf_token = $('meta[name=csrf-token]').attr('content'),
        csrf_param = $('meta[name=csrf-param]').attr('content');

    $.fn.extend({
        /**
         * Triggers a custom event on an element and returns the event result
         * this is used to get around not being able to ensure callbacks are placed
         * at the end of the chain.
         *
         * TODO: deprecate with jQuery 1.4.2 release, in favor of subscribing to our
         *       own events and placing ourselves at the end of the chain.
         */
        triggerAndReturn: function (name, data) {
            var event = new $.Event(name);
            this.trigger(event, data);

            return event.result !== false;
        },

        /**
         * Handles execution of remote calls firing overridable events along the way
         */
        callRemote: function () {
            var el      = this,
                data    = el.is('form') ? el.serializeArray() : [],
                method  = el.attr('method') || el.attr('data-method') || 'GET',
                url     = el.attr('action') || el.attr('href');

            if (url === undefined) {
              throw "No URL specified for remote call (action or href must be present).";
            } else {
                if (el.triggerAndReturn('ajax:before')) {
                    jQuery.ajax({
                        url: url,
                        data: data,
                        dataType: 'script',
                        type: method.toUpperCase(),
                        beforeSend: function (xhr) {
                            el.trigger('ajax:loading', xhr);
                        },
                        success: function (data, status, xhr) {
                            el.trigger('ajax:success', [data, status, xhr]);
                        },
                        complete: function (xhr) {
                            el.trigger('ajax:complete', xhr);
                        },
                        error: function (xhr, status, error) {
                            el.trigger('ajax:failure', [xhr, status, error]);
                        }
                    });
                }

                el.trigger('ajax:after');
            }
        }
    });

    /**
     *  confirmation handler
     */
    $('a[data-confirm],input[data-confirm]').live('click', function () {
        var el = $(this);
        if (el.triggerAndReturn('confirm')) {
            if (!confirm(el.attr('data-confirm'))) {
                return false;
            }
        }
    });


    /**
     * remote handlers
     */
    $('form[data-remote]').live('submit', function (e) {
        $(this).callRemote();
        e.preventDefault();
    });
    $('a[data-remote],input[data-remote]').live('click', function (e) {
        $(this).callRemote();
        e.preventDefault();
    });

    $('a[data-method]:not([data-remote])').live('click', function (e){
        var link = $(this),
            href = link.attr('href'),
            method = link.attr('data-method'),
            form = $('<form method="post" action="'+href+'">'),
            metadata_input = '<input name="_method" value="'+method+'" type="hidden" />';

        if (csrf_param != null && csrf_token != null) {
          metadata_input += '<input name="'+csrf_param+'" value="'+csrf_token+'" type="hidden" />';
        }

        form.hide()
            .append(metadata_input)
            .appendTo('body');

        e.preventDefault();
        form.submit();
    });

    /**
     * disable-with handlers
     */
    var disable_with_input_selector = 'input[data-disable-with]';
    var disable_with_form_selector = 'form[data-remote]:has(' + disable_with_input_selector + ')';

    $(disable_with_form_selector).live('ajax:before', function () {
        $(this).find(disable_with_input_selector).each(function () {
            var input = $(this);
            input.data('enable-with', input.val())
                 .attr('value', input.attr('data-disable-with'))
                 .attr('disabled', 'disabled');
        });
    });

    $(disable_with_form_selector).live('ajax:after', function () {
        $(this).find(disable_with_input_selector).each(function () {
            var input = $(this);
            input.removeAttr('disabled')
                 .val(input.data('enable-with'));
        });
    });
});
