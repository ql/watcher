require 'resque'
require 'pony'
require 'nexmo'

class EmailNotifierJob
  @queue = :notifications

  def self.perform(to, message, subject)
    p Pony.mail(config.merge(to: to, body: message, subject: subject))
  end

  def self.config
    YAML.load(File.open('config.yaml'))[:settings][:email_credentials]
  end
end

class SmsNotifierJob
  @queue = :notifications

  def self.perform(to, message)
    nexmo = Nexmo::Client.new(config)
    p nexmo.send_message(from: 'Ruby', to: to, text: message)
  end

  def self.config
    YAML.load(File.open('config.yaml'))[:settings][:sms_credentials]
  end
end
