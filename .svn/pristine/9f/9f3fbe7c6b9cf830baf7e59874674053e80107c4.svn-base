module ApiRequiredParams
  def self.method_is_defined_in_required_params_module(method)
    required_params_for_api_method.has_key?(method.to_s.to_sym)
  end

  def self.get_required_params_for_api_method(method)
    required_params_for_api_method[method.to_s.to_sym] ||= []
  end

  # here you must add new api method with required params for it (in order that is specified in ticket)
  # note, that you can create array of strings as %w[param_one param_two]
  # for example: %w[param_one param_two] == ['param_one', 'param_two']
  def self.required_params_for_api_method
    {
      tariff_rates_get: %w[tariff_id device_id],
      exchange_rate_update: %w[currency rate],
      aggregate_get: %w(),
      quickstats_get: %w(u),
      user_login: %w(u p)
    }
  end
end
