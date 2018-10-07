module SidekiqManager
  module Sidekiq
    class StopOnComplete
      RETRY_IN_SECONDS = 30
      WAIT_BEFORE_STOPPING = 30

      attr_reader :pid_file

      def initialize(pid_file)
        @pid_file = pid_file
      end

      def process
        return unless pid_file && pid_process_exists?

        quiet_sidekiq!
        stop_on_idle!
      end

      private

      def pid_process_exists?
        pid_file_exists? && (begin
                               !!Process.kill(0, process_id)
                             rescue StandardError
                               false
                             end)
      end

      def pid_file_exists?
        File.file?(pid_file)
      end

      def process_id
        @process_id ||= File.read(pid_file).to_i
      end

      def quiet_sidekiq!
        return if sidekiq_process_quiet?

        sidekiq_process.quiet!
        sleep WAIT_BEFORE_STOPPING
      end

      def stop_on_idle!
        begin
          process = sidekiq_process
          if process['busy'].zero?
            process.stop!
            remove_pid_file
          else
            sleep RETRY_IN_SECONDS
          end
        end until sidekiq_process.nil?
      end

      def sidekiq_process
        ps = ::Sidekiq::ProcessSet.new
        ps.find { |p| p['pid'] == process_id }
      end

      def sidekiq_process_quiet?
        sidekiq_process['quiet'] == 'true'
      end

      def remove_pid_file
        File.delete(pid_file) if File.exist?(pid_file)
      end
    end
  end
end
