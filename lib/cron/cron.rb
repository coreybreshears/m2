module Cron
  class << self
    def do_jobs
      cron_actions = %w[invoice_cron agg_export_cron]
      cron_actions.each do |action|
        Cron.send(action) do |job|
          # Do job of certain cron
          job.do_job
          # After job done, set new next_run_at
          job.next_run_at
        end
      end
    end

    def invoice_cron
      user_crons = User.where(["billing_run_at < ? AND billing_period IN ('bimonthly','quarterly','halfyearly','dynamic') AND generate_invoice_manually = 0", Time.now().to_s(:db)]).all
      user_crons.each do |cron|
        if cron.billing_period == 'dynamic'
          job = InvoiceJob.new(run_at: cron.billing_run_at, days: cron.billing_dynamic_days, user: cron, dynamic_hours: cron.billing_dynamic_generation_time)
        else
          job = InvoiceJob.new(run_at: cron.billing_run_at, user: cron)
        end
        yield job
      end
    end

    def agg_export_cron
      agg_exports = AutoAggregateExport.where('next_run_at <= ? AND completed = 0', Time.now.to_s(:db)).all
      agg_exports.each do |cron|
        job = AggregateExportJob.new(agg_export: cron)
        yield job
      end
    end
  end
end