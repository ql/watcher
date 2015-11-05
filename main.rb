require 'eventmachine'
require 'logger'
require 'em-http-request'
require 'yaml'

require './notifiers.rb'

class Watcher
  REFRESH_INTERVAL = 30
  NOTIFY_INTERVALS = [3*60, 5*60, 10*60, 100*60, 500*60].sort.freeze #seconds

  def initialize
    @failed_urls = {}
    @config = YAML.load(File.open('config.yaml')).freeze
    @watch_urls = @config[:watch_urls].inject({}) {|hash, h| hash.merge(h.delete(:url) => h) }
  end

  def check_urls
    logger.debug { "checking urls..." }
    @watch_urls.keys.each { |url| check_url(url) }
  end

  def notify_method(url)
    @watch_urls[url][:notify]
  end

  def check_url(url)
    http = EventMachine::HttpRequest.new(url).get
    http.callback do
      status = http.response_header.status
      (status == 200) ?  ok(url) : problem(url, status)
    end

    http.errback { problem(url, http.error) }
  end

  def ok(url)
    if @failed_urls[url]
      report_up(url)
      @failed_urls.delete(url)
    else
      logger.debug { "#{url} is fine" }
    end
  end

  def problem(url, error)
    logger.debug { "#{url} is down" }
    first_down_at, counter = @failed_urls[url]
    if first_down_at
      unless counter >= NOTIFY_INTERVALS.size
        if Time.now - first_down_at > NOTIFY_INTERVALS[counter]
          @failed_urls[url] = [first_down_at, counter + 1]
          report_down(url, error, first_down_at)
        end
      else
        logger.debug { "#{url} still down, doing nothing" }  
      end
    else
      @failed_urls[url] = [Time.now, 0]
    end
  end

  def report_up(url)
    message = "Hurray, #{url} is up again!"
    logger.info { message }
    notify(url, message)
  end

  def report_down(url, error, down_since)
    message = "#{url} DOWN: #{error} (since #{down_since})"
    logger.error { message }
    notify(url, message)
  end

  def notify(url, message)
    case notify_method(url)
      when :email
        Resque.enqueue(EmailNotifierJob, @config[:settings][:contacts][:email], message, url)
      when :sms
        Resque.enqueue(SmsNotifierJob, @config[:settings][:contacts][:phone], message)
      else
        raise "Unknown notify method, check config"
    end
  end

  def logger
    @logger ||= Logger.new(STDOUT).tap do |logger|
      logger.level = Logger::DEBUG
    end
  end
end

EventMachine.run {
  watcher = Watcher.new
  EventMachine.next_tick { watcher.check_urls}
  EventMachine.add_periodic_timer(Watcher::REFRESH_INTERVAL) { watcher.check_urls}
}
