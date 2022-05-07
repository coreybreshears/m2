# Helper module for CDR Disputes
module CdrDisputesHelper
  class << self
    def codes_for_select
      Dispute::ReportGroup.types.map do |code, type|
        [%w[TT TC TM NM].include?(code) ? type : "#{code} - #{type}", code]
      end
    end

    def cell_class(code)
      return 'good-cell' if code == 10
      return 'bad-cell' if code >= 31
      return 'ok-cell' if code >= 21
    end

    def special_code?(code)
      %w[TT TC TM NM].include? code
    end
  end
end
