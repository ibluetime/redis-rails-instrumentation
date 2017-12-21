require 'redis'
require 'redis/rails/instrumentation/logging'
require 'redis/rails/instrumentation/version'
require 'active_support'
require 'sweet_notifications'

class Redis
  module Rails
    module Instrumentation
      Railtie, LogSubscriber = SweetNotifications.subscribe :redis,
                                                            label: 'Redis' do
        color ActiveSupport::LogSubscriber::RED

        event :command do |event|                                                
          next unless logger.debug?                                       
          cmds = event.payload[:commands]
          output = cmds.map do |name, *args|                                               
            if !args.empty?
              "[ #{name.to_s.upcase} #{format_arguments(args)} ]"
            else
              "[ #{name.to_s.upcase} ]"
            end
          end.join(' ')
      
          next if skip?(output)
          debug message(event, 'Redis', output)
        end

        private

        def format_arguments(args)
          args.map do |arg|
            if arg.respond_to?(:encoding) && arg.encoding == Encoding::ASCII_8BIT
              '<BINARY DATA>'
            else
              arg
            end
          end.join(' ')
        end
        
        def skip?(output)
          output.match?(Regexp.new(commands, true))
        end
        
        def commands
          [
            'Sidekiq',
            '(BRPOP queue)',
            '(SADD processes)',
            '(SMEMBERS processes)',
            '(SCARD processes)',
            '(INCRBY stat:processed)',
            '(ZRANGEBYSCORE schedule)',
            '(ZRANGEBYSCORE retry)'
          ].join('|')
        end
      end
    end
  end
end

Redis::Client.send(:prepend, Redis::Rails::Instrumentation::Logging)
