require 'eventmachine'
require 'logger'
require 'em-http-request'

class Watcher
  REFRESH_INTERVAL = 15
  NOTIFY_INTERVALS = [20, 40, 60].sort.freeze #seconds

  def failed_urls
    @failed_urls ||= {}
  end

  def watch_urls
    %w{http://flibusta.net http://ya.ru http://www.rbc.ru}
  end

  def check_urls
    watch_urls.each { |url| check_url(url) }
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
    if failed_urls[url]
      report_up(url)
      failed_urls.delete(url)
    else
      logger.debug { "#{url} is fine" }
    end
  end

  def problem(url, error)
    logger.debug { "#{url} is down" }
    first_down_at, counter = failed_urls[url]
    if first_down_at
      unless counter >= NOTIFY_INTERVALS.size
        if Time.now - first_down_at > NOTIFY_INTERVALS[counter]
          failed_urls[url] = [first_down_at, counter + 1]
          report_down(url, error, first_down_at)
        end
      else
        logger.debug { "#{url} still down, doing nothing" }  
      end
    else
      failed_urls[url] = [Time.now, 0]
    end
  end

  def report_up(url)
    logger.info { "#{url} UP!" }
  end

  def report_down(url, error, down_since)
    logger.error { "#{url} DOWN: #{error} (since #{down_since})" }
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end
   
  def post_init
    logger.info { "Started..." }
  end

  def receive_data data
     send_data ">>>you sent: #{data}"
     close_connection if data =~ /quit/i
  end

  def unbind
  end
end

EventMachine.run {
  watcher = Watcher.new
  EventMachine.next_tick { watcher.check_urls}
  EventMachine.add_periodic_timer(Watcher::REFRESH_INTERVAL) { watcher.check_urls}
}
