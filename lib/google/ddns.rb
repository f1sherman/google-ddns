require "google/ddns/version"
require 'yaml'
require 'fileutils'
require 'io/console'
require 'net/http'
require 'logger'
require 'resolv'

module Google
  module Ddns
    def self.run
      settings_directory = File.join Dir.home, ".google-ddns-gem"
      settings_file = File.join settings_directory, "settings.yml"

      if File.exist?(settings_file)
        update_on_change settings_file
      else
        init_settings settings_directory, settings_file
      end
    end

    def self.update_on_change(settings_file)
      settings = YAML.load_file settings_file
      old_ip = settings["ip_address"]

      current_ip = get_current_ip

      if old_ip != current_ip
        # Using the "warn" level will cause cron to send mail, so we know when our IP address changes
        logger.warn "IP Address changed from #{old_ip} to #{current_ip}, updating..."
        update_ip settings, settings_file
      else
        logger.info "IP Address has not changed from #{old_ip}, skipping update."
      end
    end

    def self.init_settings(settings_directory, settings_file)
      unless $stdout.isatty
        error "No Google DDNS setup information found! Please run google-ddns from an interactive terminal to get setup."
      end

      puts "Hi there! Looks like you don't have a settings file. Let's get you setup!"
      FileUtils.mkdir_p settings_directory

      settings = {}

      print "Google DDNS Hostname: "
      settings["hostname"] = $stdin.gets.chomp
      print "Google DDNS Username: "
      settings["username"] = $stdin.gets.chomp
      print "Google DDNS Password (typing will be hidden): "
      settings["password"] = $stdin.noecho(&:gets).chomp
      puts

      update_ip settings, settings_file
    end

    def self.update_ip(settings, settings_file)
      response = Net::HTTP.post_form URI("https://#{settings["username"]}:#{settings["password"]}@domains.google.com/nic/update"), "hostname" => settings["hostname"]

      response_type, ip_address = response.body.split

      unless response.code == "200" && ["good", "nochg"].include?(response_type)
        error "Error updating IP Address! Received response code #{response.code} and body \"#{response.body}\"."
      end

      success_message = if response_type == "good"
                          "Updated #{settings["hostname"]} IP Address to #{ip_address}."
                        else
                          "Tried to update, but #{settings["hostname"]} IP Address was already set to #{ip_address}."
                        end

      logger.info success_message

      settings["ip_address"] = ip_address
      settings["updated_at"] = Time.now.utc.to_s

      YAML.dump settings, File.new(settings_file, "w")
      FileUtils.chmod 0600, settings_file
    end

    def self.get_current_ip
      Resolv::DNS.new(:nameserver => "resolver1.opendns.com").getaddress("myip.opendns.com").to_s
    end

    def self.logger
      @logger ||= Logger.new($stdout).tap do |logger_instance|
        logger_instance.level = $stdout.isatty ? Logger::INFO : Logger::WARN
        logger_instance.formatter = proc { |_severity, _time, _progname, msg|
          "#{msg}\n"
        }
      end
    end

    def self.error(message)
      logger.error message
      exit false
    end

    run if defined? IN_EXECUTABLE_CONTEXT
  end
end
