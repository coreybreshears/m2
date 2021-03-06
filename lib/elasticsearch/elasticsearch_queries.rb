# -*- encoding : utf-8 -*-
module ElasticsearchQueries

  def es_admin_quick_stats_query(options)
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {term: {disposition: 'ANSWERED'}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            total_provider_price: {
                sum: {
                    field: 'provider_price'
                }
            },
            total_user_price: {
                sum: {
                    field: 'user_price'
                }
            }
        }
    }
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:should] = [{terms: {src_user_id: options[:assigned_users]}}, {terms: {user_id: options[:assigned_users]}}]
    end
    query
  end

  def es_user_quick_stats_query(from, till, user_id)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: from, lte: till}}},
                            {term: {disposition: 'ANSWERED'}},
                            {
                                bool: {
                                    should: [
                                        {term: {src_user_id: user_id}},
                                        {term: {provider_id: user_id}}
                                    ]
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            total_billsec: {
                sum: {
                    field: 'billsec'
                }
            },
            user_billsec: {
                sum: {
                    field: 'user_billsec'
                }
            },
            total_user_price: {
                sum: {
                    script: "doc.provider_id.value == #{user_id} ? doc.provider_price.value : doc.user_price.value"
                }
            }
        }
    }
  end

  def self.es_hangup_cause_codes_stats_query(from, till, options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: from, lte: till}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                grouped_by_hgc: {
                    terms: {
                        field: 'hangupcause',
                        order: {_term: 'asc'},
                        size: 0
                    }
                }
            }
        }

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    end
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {user_id: options[:assigned_users]}}
    end
    if options[:device_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {src_device_id: "#{options[:device_id]}"}},
                      {term: {dst_device_id: "#{options[:device_id]}"}}
                  ]
              }
          }
    end

    if options[:dst_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:dst_group_id]}"}}
    end

    return query
  end

  def self.es_hangup_cause_codes_stats_calls_query(from, till, options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: from, lte: till}}}
                            ]
                        }
                    }
                }
            },
            aggregations: {
                dates: {
                    date_histogram: {
                        field: 'calldate',
                        interval: 'day',
                        time_zone: options[:utc_offset],
                        #time_zone: '-09:00',
                        format: 'yyyy-MM-dd'
                    }
                }
            }
        }

    if options[:good_calls]
      query[:query][:filtered][:filter][:bool][:must] << {term: {disposition: 'ANSWERED'}}
    elsif options[:bad_calls]
      query[:query][:filtered][:filter][:bool][:must] << {exists: {field: 'disposition'}}
      query[:query][:filtered][:filter][:bool].store(:must_not, [{term: {disposition: 'ANSWERED'}}])
    end

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {user_id: "#{options[:user_id]}"}}
    end
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {user_id: options[:assigned_users]}}
    end
    if options[:device_id]
      query[:query][:filtered][:filter][:bool][:must] <<
          {
              bool: {
                  should: [
                      {term: {src_device_id: "#{options[:device_id]}"}},
                      {term: {dst_device_id: "#{options[:device_id]}"}}
                  ]
              }
          }
    end

    if options[:dst_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:dst_group_id]}"}}
    end

    return query
  end

  def self.country_stats_query(options = {})
    query =
        {
            size: 0,
            query: {
                filtered: {
                    filter: {
                        bool: {
                            must: [
                                {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                                {term: {disposition: 'ANSWERED'}}
                            ],
                        }
                    }
                }
            },
            aggregations: {
                grouped_by_dg_id: {
                    terms: {
                        field: 'destinationgroup_id',
                        order: {_term: 'asc'},
                        size: 0
                    },
                    aggregations: {
                        total_billsec: {
                            sum: {
                                field: 'billsec'
                            }
                        },
                        total_user_price: {
                            sum: {
                                field: 'user_price'
                            }
                        }
                    }
                }
            }
        }

    if options[:user_id]
      query[:query][:filtered][:filter][:bool][:must] << {
        bool: {
          should: [
            { term: { user_id: options[:user_id] }},
            { term: { provider_id: options[:user_id] }}
          ]
        }
      }
    end

    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {user_id: options[:assigned_users]}}
    end

    if !options[:user_perspective]
      query[:aggregations][:grouped_by_dg_id][:aggregations][:total_provider_price] = {sum: {field: 'provider_price'}}
    end

    query
  end

  def self.calls_by_user(options)
  {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: { calldate: { gte: options[:gte], lte: options[:lte] }}},
                            {terms: { src_user_id: options[:users] }}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_user_id: {
                terms: {
                    field: 'src_user_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        'filter' => {term: {disposition: 'ANSWERED'}},
                        aggregations: {
                            total_billsec: {
                                sum: {
                                    field: 'billsec'
                                }
                            },
                            total_provider_price: {
                                sum: {
                                    field: 'provider_price'
                                }
                            },
                            total_user_price: {
                                sum: {
                                    field: 'user_price'
                                }
                            }
                        }
                    },
                    pdd:{
                        'filter' => {range: {pdd: {gt:0}}},
                        aggregations: {
                            avg_pdd: {
                                avg: {
                                    field: 'pdd'
                                }
                            },
                            total_pdd: {
                                sum: {
                                    field: 'pdd'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
  end
    def self.calls_per_hour_by_date(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_date: {
                date_histogram: {
                    field: 'calldate',
                    interval: 'day',
                    time_zone: options[:utc_offset],
                    format: 'yyyy-MM-dd'
                },
                aggregations: {
                    user_perspective: {
                        filter:  {range: {user_id:{gt: 0}}}
                    },
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    total_billsec: {
                        sum: {field: options[:billsec_field]}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      query[:query][:filtered][:filter][:bool][:must] <<{terms: {src_user_id: options[:user_array]}}
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {src_user_id: options[:user]}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    query
  end

  def self.calls_per_hour_by_originator(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_user_id: {
                terms: {
                    field: 'src_user_id',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter:  {range: {user_id:{gt: 0}}}
                    },
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    total_billsec: {
                        sum: {field: options[:billsec_field]}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      query[:query][:filtered][:filter][:bool][:must] <<{terms: {src_user_id: options[:user_array]}}
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {src_user_id: options[:user]}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    query
  end

  def self.calls_per_hour_by_hour(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_hour: {
                date_histogram: {
                    field: 'calldate',
                    interval: 'hour',
                    time_zone: options[:utc_offset],
                    format: 'H'
                },
                aggregations: {
                    user_perspective: {
                        filter:  {range: {user_id:{gt: 0}}}
                    },
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    total_billsec: {
                        sum: {field: options[:billsec_field]}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      query[:query][:filtered][:filter][:bool][:must] <<{terms: {src_user_id: options[:user_array]}}
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {src_user_id: options[:user]}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end


    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    query
  end

  def self.calls_per_hour_by_destination(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_prefix: {
                terms: {
                    field: 'prefix',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter:  {range: {user_id:{gt: 0}}}
                    },
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    total_billsec: {
                        sum: {field: options[:billsec_field]}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      query[:query][:filtered][:filter][:bool][:must] <<{terms: {src_user_id: options[:user_array]}}
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {src_user_id: options[:user]}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    query
  end

  def self.calls_per_hour_by_terminator(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {exists: {field: 'prefix'}}
                        ],
                        must_not: [
                            {term: {prefix: ''}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_provider_id: {
                terms: {
                    field: 'provider_id',
                    size: 0
                },
                aggregations: {
                    user_perspective: {
                        filter:  {range: {user_id:{gt: 0}}}
                    },
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    total_billsec: {
                        sum: {field: options[:billsec_field]}
                    }
                }
            }
        }
    }

    if options[:show_only_assigned_users] == 1
      query[:query][:filtered][:filter][:bool][:must] <<{terms: {src_user_id: options[:user_array]}}
    end

    if options[:user].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {src_user_id: options[:user]}}
    end

    if options[:providers].present?
      query[:query][:filtered][:filter][:bool][:must] << {terms: {provider_id: options[:providers]}}
    end

    if options[:prefix]
      query[:query][:filtered][:query] = {wildcard: {prefix: options[:prefix].gsub('%', '*').gsub('_', '?')}}
    end

    if options[:destination_group_id]
      query[:query][:filtered][:filter][:bool][:must] << {term: {destinationgroup_id: "#{options[:destination_group_id]}"}}
    end

    query
  end
  def self.aggregates(options = {})
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}}
                        ]
                    }
                }
            }
        }
    }

    if options[:set_time_of_day].to_i == 1
       query[:query][:filtered][:filter][:bool][:must] << {
         script: {
          script: "doc.calldate.date.getHourOfDay() >= min && doc.calldate.date.getHourOfDay() <= max",
          params: {
            min: options[:from_time_of_day],
            max: options[:till_time_of_day]
          }
        }
       }
    end

    if options[:originator_present]
      query[:query][:filtered][:filter][:bool][:must] << {term: options[:user_perspective].present? ? {user_id: options[:originator]} : {src_user_id: options[:originator]}}
    else
      query[:query][:filtered][:filter][:bool][:must] << {range: options[:user_perspective].present? ? {user_id: {gt: 0}} : {src_user_id: {gt: 0}}}
    end
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: options[:user_perspective].present? ? {user_id: options[:assigned_users]} : {src_user_id: options[:assigned_users]}}
    end
    query[:query][:filtered][:filter][:bool][:must] << {term: {src_device_id: options[:op]}} if options[:op].present?

    if options[:terminator_present]
      query[:query][:filtered][:filter][:bool][:must] << {term: {provider_id: options[:terminator]}}
    end

    query[:query][:filtered][:filter][:bool][:must] << {term: {dst_device_id: options[:tp]}} if options[:tp].present?

    if options[:dst].present?
      query[:query][:filtered][:filter][:bool][:must] << { query: {wildcard: {localized_dst: options[:dst].gsub('%', '*').gsub('_', '?')}}}
    end

    if options[:src].present?
      query[:query][:filtered][:filter][:bool][:must] << { query: {wildcard: {src: options[:src].gsub('%', '*').gsub('_', '?')}}}
    end

    if options[:destinationgroups_present]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {destinationgroup_id: options[:destinationgroups]}}
    end

    if options[:group_by].any? { |h| ['agg_by_dst_group', 'agg_by_dst'].include?(h[:group_name]) }
      query[:query][:filtered][:filter][:bool][:must] << {exists: {field: 'prefix'}}
      query[:query][:filtered][:filter][:bool][:must_not] = [{term: {prefix: ''}}]
    end

    if options[:group_by].any? { |h| ['agg_by_terminator', 'agg_by_tp'].include?(h[:group_name]) }
      query[:query][:filtered][:filter][:bool][:must] << {range: {provider_id: {gt: 0}}}
    end

    if options[:s_duration].present?
      query[:query][:filtered][:filter][:bool][:must] <<{script: {script: "(doc['billsec'].value == 0 && doc['real_billsec'].value > 1 ? ceil(doc['real_billsec'].value) : doc['billsec'].value) == #{options[:s_duration]}"}}
    end

    if options[:s_manager].present?
      query[:query][:filtered][:filter][:bool][:must] << {term: {manager_id: options[:s_manager]}}
    end


    agg_by_answered = {
        agg_by_answered: {
            filter: {term: {disposition: 'ANSWERED'}},
            aggregations: {
                total_originator_price: {
                    sum: {field: 'user_price'}
                },
                total_billsec: {
                    sum: {field: options[:use_real_billsec].present? ? 'real_billsec' : 'billsec'}
                },
                total_originator_billsec: {
                    sum: {field: 'user_billsec'}
                },
                total_terminator_billsec: {
                    sum: {field: 'provider_billsec'}
                },
                total_terminator_price: {
                    sum: {field: 'provider_price'}
                }
            }
        },
        pdd:{
            'filter' => {range: {pdd: {gt:0}}},
                aggregations: {
                    avg_pdd: {
                        avg: {
                            field: 'pdd'
                        }
                    },
                    total_pdd: {
                        sum: {
                            field: 'pdd'
                        }
                    }
                }
        }
    }

    options[:group_by].each_with_index do |group_by, index|
      aggregation = {
          group_by[:group_name] => {
              terms: {
                  field: group_by[:group_field],
                  size: 0
              }
          }
      }

      case index
        when 0
          query[:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations] = agg_by_answered
        when 1
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations] = agg_by_answered
        when 2
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations] = agg_by_answered
        when 3
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations][options[:group_by][3][:group_name]][:aggregations] = agg_by_answered
        when 4
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations][options[:group_by][3][:group_name]][:aggregations] = aggregation
          query[:aggregations][options[:group_by][0][:group_name]][:aggregations][options[:group_by][1][:group_name]][:aggregations][options[:group_by][2][:group_name]][:aggregations][options[:group_by][3][:group_name]][:aggregations][options[:group_by][4][:group_name]][:aggregations] = agg_by_answered
      end
    end

    query
  end

  def self.balance_reports_traffic_to_us(options = {})
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {terms: {user_id: options[:users]}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_originator_id: {
                terms: {
                    field: 'user_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        filter: {term: {disposition: 'ANSWERED'}},
                        aggregations: {
                            total_originator_price: {
                                sum: {field: 'user_price'}
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.balance_reports_traffic_from_us(options = {})
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {range: {calldate: {gte: options[:from], lte: options[:till]}}},
                            {terms: {provider_id: options[:users]}}
                        ]
                    }
                }
            }
        },
        aggregations: {
            group_by_terminator_id: {
                terms: {
                    field: 'provider_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        filter: {term: {disposition: 'ANSWERED'}},
                        aggregations: {
                            total_terminator_price: {
                                sum: {field: 'provider_price'}
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.last_calls_totals(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            { range: { calldate: { gte: options[:from_es], lte: options[:till_es] } } }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Total price from Providers.
            total_provider_price: {
                sum: { field: :provider_price }
            },
            # Total price from Users.
            total_user_price: {
                sum: {
                    script: options[:user_price_script]
                }
            },
            # Total duration in seconds.
            total_duration: {
                sum: {
                    field: :duration
                }
            },
            # Total billsec in seconds
            total_billsec: {
                sum: {
                    script: 'doc.billsec.value == 0 && doc.real_billsec.value > 1 ? Math.ceil(doc.real_billsec.value) : doc.billsec.value'
                }
            }
        }
    }
    if options[:usertype] == 'user'
        query[:query][:filtered][:filter][:bool][:must] << {
            bool: {
                should: [
                    { term:  { user_id: options[:current_user][:id] }},
                    { term:  { provider_id: options[:current_user][:id] }}
                ]
            }
        }
    end
    last_calls_filter(query, options)
  end

  def self.dashboard_stats_op_last_day(options = {})
     query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must_not: [
                            {
                                range: {
                                    hangupcause: {
                                        gte: 300,
                                        lt: 312
                                    }
                                }
                            },
                            {
                                range: {
                                    hangupcause: {
                                        gt: 312,
                                        lte: 399
                                    }
                                }
                            }
                        ],
                        must: [
                            {
                                range: {
                                    hangupcause: {
                                        gt: 0
                                    }
                                }
                            },
                            {
                                range: {
                                    calldate: {
                                        gte: options[:last_day],
                                        lte: options[:now]
                                    }
                                }
                            },
                            {
                                range: {
                                    src_user_id: {
                                        gt: 0
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Group only Originators
            grouped_by_op_user: {
                terms: {
                    field: 'src_user_id',
                    size: 0
                },
                aggregations: {
                    # Today's Calls aggregation
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    billsec: {
                        sum: {
                            field: options[:billsec_field]
                        }
                    },
                    user_price: {
                        sum: {
                            field: 'user_price'
                        }
                    },
                    provider_price: {
                        sum: {
                            field: 'provider_price'
                        }
                    }
                }
            }
        }
    }
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {src_user_id: options[:assigned_users]}}
    end
    query
  end

  def self.dashboard_stats_op_last_hour(options = {})
     query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must_not: [
                            {
                                range: {
                                    hangupcause: {
                                        gte: 300,
                                        lt: 312
                                    }
                                }
                            },
                            {
                                range: {
                                    hangupcause: {
                                        gt: 312,
                                        lte: 399
                                    }
                                }
                            }
                        ],
                        must: [
                            {
                                range: {
                                    hangupcause: {
                                        gt: 0
                                    }
                                }
                            },
                            {
                                range: {
                                    calldate: {
                                        gte: options[:last_hour],
                                        lte: options[:now]
                                    }
                                }
                            },
                            {
                                range: {
                                    src_user_id: {
                                        gt: 0
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            # Group only Originators
            grouped_by_op_user: {
                terms: {
                    field: 'src_user_id',
                    size: 0
                },
                aggregations: {
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    billsec: {
                        sum: {
                            field: options[:billsec_field]
                        }
                    },
                    user_price: {
                        sum: {
                            field: 'user_price'
                        }
                    },
                    provider_price: {
                        sum: {
                            field: 'provider_price'
                        }
                    }
                }
            }
        }
    }
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {src_user_id: options[:assigned_users]}}
    end
    query
  end

  def self.dashboard_stats_tp_last_day(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must_not: [
                            {
                                range: {
                                    hangupcause: {
                                        gte: 300,
                                        lt: 312
                                    }
                                }
                            },
                            {
                                range: {
                                    hangupcause: {
                                        gt: 312,
                                        lte: 399
                                    }
                                }
                            }
                        ],
                        must: [
                            {
                                range: {
                                    hangupcause: {
                                        gt: 0
                                    }
                                }
                            },
                            {
                                range: {
                                    calldate: {
                                        gte: options[:last_day],
                                        lte: options[:now]
                                    }
                                }
                            },
                            {
                                range: {
                                    provider_id: {
                                        gt: 0
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        # Group only Terminators
        aggregations: {
            grouped_by_tp_user: {
                terms: {
                    field: 'provider_id',
                    size: 0
                },
                aggregations: {
                    # Today's Calls aggregation
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    billsec: {
                        sum: {
                            field: options[:billsec_field]
                        }
                    },
                    user_price: {
                        sum: {
                            field: 'user_price'
                        }
                    },
                    provider_price: {
                        sum: {
                            field: 'provider_price'
                        }
                    }
                }
            }
        }
    }
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {src_user_id: options[:assigned_users]}}
    end
    query
  end

  def self.dashboard_stats_tp_last_hour(options = {})
    query = {
        query: {
            filtered: {
                filter: {
                    bool: {
                        must_not: [
                            {
                                range: {
                                    hangupcause: {
                                        gte: 300,
                                        lt: 312
                                    }
                                }
                            },
                            {
                                range: {
                                    hangupcause: {
                                        gt: 312,
                                        lte: 399
                                    }
                                }
                            }
                        ],
                        must: [
                            {
                                range: {
                                    hangupcause: {
                                        gt: 0
                                    }
                                }
                            },
                            {
                                range: {
                                    calldate: {
                                        gte: options[:last_hour],
                                        lte: options[:now]
                                    }
                                }
                            },
                            {
                                range: {
                                    provider_id: {
                                        gt: 0
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        # Group only Terminators
        aggregations: {
            grouped_by_tp_user: {
                terms: {
                    field: 'provider_id',
                    size: 0
                },
                aggregations: {
                    # One hour-ago Calls aggregation
                    answered_calls: {
                        filter: {
                            term: {
                                disposition: 'ANSWERED'
                            }
                        }
                    },
                    billsec: {
                        sum: {
                            field: options[:billsec_field]
                        }
                    },
                    user_price: {
                        sum: {
                            field: 'user_price'
                        }
                    },
                    provider_price: {
                        sum: {
                            field: 'provider_price'
                        }
                    }
                }
            }
        }
    }
    if options[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {terms: {src_user_id: options[:assigned_users]}}
    end
    query
  end

  def self.user_stats_disp(options)
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            disp_groups: {
                terms: {
                    field: 'disposition'
                }
            }
        }
    }

    if options[:user_id] > 0
        query[:query][:filtered][:filter][:bool][:must] << {
            term: {
                src_user_id: options[:user_id]
            }
        }
    end

    if options[:assigned_users]
        query[:query][:filtered][:filter][:bool][:must] << {
            terms: {
                src_user_id: options[:assigned_users]
            }
        }
    end
    query
  end

  def self.user_stats_days(options)
    query = {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            },
                            {
                                term: {
                                    disposition: 'ANSWERED'
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            days_histogram: {
                date_histogram: {
                    field: 'calldate',
                    interval: 'day',
                    format: 'yyyy-MM-dd',
                    time_zone: options[:tz],
                    order: {
                        _key: 'desc'
                    }
                },
                aggregations: {
                    duration: {
                        sum: {
                            field: 'billsec'
                        }
                    },
                    acd: {
                        avg: {
                            field: 'billsec'
                        }
                    }
                }
            },
            duration: {
                sum: {
                    field: 'billsec'
                }
            },
            acd: {
                avg:{
                    field: 'billsec'
                }
            }
        }
    }
    if options[:user_id] > 0
        query[:query][:filtered][:filter][:bool][:must] << {
            term: {
                src_user_id: options[:user_id]
            }
        }
    end
    if options[:assigned_users]
        query[:query][:filtered][:filter][:bool][:must] << {
            terms: {
                src_user_id: options[:assigned_users]
            }
        }
    end
    query
  end

  def self.tp_deviations(options)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            },
                            {
                                terms: {
                                    dst_device_id: options[:tps]
                                }
                            }
                        ]
                    }
                }
            }
        },
        aggregations: {
            tps: {
                terms: {
                    field: 'dst_device_id',
                    size: 0,
                    min_doc_count: 0,
                },
                aggregations: {
                    billsec: {
                        sum: {
                            field: 'billsec'
                        }
                    },
                    answered: {
                        filter: {
                            term: {
                                hangupcause: 16
                            }
                        }
                    }
                }
            }
        }
    }
  end

  def self.quick_stats_call(options)
    {
        size: 0,
        query: {
            filtered: {
                filter: {
                    bool: {
                        must: [
                            {
                                range: {
                                    calldate: {
                                        gte: options[:from],
                                        lte: options[:till]
                                    }
                                }
                            }
                        ]
                    }
                }
            }
        }
    }
  end

private

  def self.last_calls_filter(query, filters)
    unless filters[:s_user_id].blank? || %w(-2 -1).include?(filters[:s_user_id])
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { term:  { user_id: filters[:s_user_id] } },
                  { terms: { src_device_id: filters[:device_ids] } }
              ]
          }
      }
    end

    unless filters[:s_origination_point].blank? || filters[:s_origination_point] == 'all'
      query[:query][:filtered][:filter][:bool][:must] << { term: { src_device_id: filters[:s_origination_point].to_i } }
    end

    unless filters[:s_call_type].blank? || filters[:s_call_type] == 'all'
      if filters[:s_call_type].to_s.upcase == 'CANCEL'
        query[:query][:filtered][:filter][:bool][:must] << { term: { hangupcause: '312' } }
      else
        if filters[:s_call_type].to_s == 'no answer'
          query[:query][:filtered][:filter][:bool][:must_not] = { term: { hangupcause: '312' } }
        end
        query[:query][:filtered][:filter][:bool][:must] << { term: { disposition: filters[:s_call_type].to_s.upcase } }
      end
    end

    unless filters[:s_hgc].blank? || filters[:s_hgc].to_i <= 0
      query[:query][:filtered][:filter][:bool][:must] << { term: { hangupcause: filters[:hangup] } } if filters[:hangup]
    end

    unless filters[:s_user_terminator_id].blank? || %w(-2 -1).include?(filters[:s_user_terminator_id])
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { term:  { user_id: filters[:s_user_terminator_id] } },
                  { terms: { dst_device_id: filters[:tp_device_ids] } }
              ]
          }
      }
    end

    unless filters[:s_termination_point].blank? || filters[:s_termination_point] == '0' || filters[:s_termination_point] == 'all'
      query[:query][:filtered][:filter][:bool][:must] << { term: { dst_device_id: filters[:s_termination_point].to_i } }
    end

    if filters[:assigned_users]
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { terms: { user_id: filters[:assigned_users] } },
                  { terms: { src_device_id: filters[:assigned_users_device_ids] } }
              ]
          }
      }
    end
    unless filters[:s_source].blank?
      query[:query][:filtered][:filter][:bool][:must] << {
          bool: {
              should: [
                  { query: { wildcard: { src: filters[:s_source].gsub('%', '*').gsub('_', '?') } } },
                  { query: { wildcard: { clid: filters[:s_source].gsub('%', '*').gsub('_', '?') } } }
              ]
          }
      }
    end

    unless filters[:s_destination].blank?
      query[:query][:filtered][:filter][:bool][:must] << {
          query: { wildcard: { localized_dst: filters[:s_destination].gsub('%', '*').gsub('_', '?') } }
      }
    end

    unless filters[:s_billsec].blank?
      query[:query][:filtered][:filter][:bool][:must] <<{script: {script: "(doc['billsec'].value == 0 && doc['real_billsec'].value > 1 ? ceil(doc['real_billsec'].value) : doc['billsec'].value) == #{filters[:s_billsec]}"}}
    end

    unless filters[:s_duration].blank?
      query[:query][:filtered][:filter][:bool][:must] <<{ term: { duration: filters[:s_duration] } }
    end

    unless filters[:s_server].blank?
      query[:query][:filtered][:filter][:bool][:must] << { term: { server_id: filters[:s_server] } }
    end

    unless filters[:calls_ids_by_unique_id].blank?
      query[:query][:filtered][:filter][:bool][:must] << { terms: { '_id' => filters[:calls_ids_by_unique_id] } }
    end
    query
  end
end
