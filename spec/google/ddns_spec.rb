require "spec_helper"

describe Google::Ddns do
  let(:update_url) { "https://domains.google.com/nic/update" }
  let(:home_directory) { "/home/user" }
  let(:settings_directory) { "#{home_directory}/.google-ddns-gem" }
  let(:settings_file) { "#{settings_directory}/settings.yml" }
  let(:dns_instance_double) { double(Resolv::DNS) }
  let(:file_double) { double(File) }
  before { allow($stdout).to receive(:isatty).and_return false }

  it "has a version number" do
    expect(Google::Ddns::VERSION).not_to be nil
  end

  describe ".run" do
    subject(:run) { Google::Ddns.run }
    before { allow(Dir).to receive(:home).and_return home_directory }

    context "when a settings file exists" do
      it do
        expect(File).to receive(:exist?).with(settings_file).and_return true
        expect(YAML).to receive(:load_file).with(settings_file).and_return(
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        )
        expect(dns_instance_double).to receive(:getaddress).with("myip.opendns.com").and_return "1.2.3.4"
        expect(Resolv::DNS).to receive(:new).with(:nameserver => "resolver1.opendns.com").and_return dns_instance_double
        expect(FileUtils).not_to receive :mkdir_p
        expect(WebMock).not_to have_requested :post, update_url

        run
      end
    end

    context "when a settings file does not exist" do
      before { stub_request(:post, update_url).to_return :body => "good 1.2.3.4" }
      it do
        expect($stdout).to receive(:isatty).and_return true
        expect(File).to receive(:exist?).with(settings_file).and_return false
        expect(FileUtils).to receive(:mkdir_p).with(settings_directory)
        expect($stdin).to receive(:gets).and_return 'host.example.com', 'user', 'pass'
        expect(File).to receive(:new).with(settings_file, "w").and_return file_double
        expect(FileUtils).to receive(:chmod).with(0600, settings_file)
        expect(Time).to receive(:now).at_least(:once).and_return Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        expect(YAML).to receive(:dump).with({
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => "2000-01-01 05:59:59 UTC"
        }, file_double)

        run

        expect(WebMock).to have_requested(:post, update_url).with(
          :basic_auth => ["user", "pass"],
          :body => { :hostname => "host.example.com" }
        )
      end
    end
  end

  describe ".update_on_change" do
    subject(:update_on_change) { Google::Ddns.update_on_change settings_file }

    context "when the IP Address has changed" do
      before { stub_request(:post, update_url).to_return :body => "good 1.2.3.5" }
      it do
        expect(YAML).to receive(:load_file).with(settings_file).and_return(
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        )
        expect(dns_instance_double).to receive(:getaddress).with("myip.opendns.com").and_return "1.2.3.5"
        expect(Resolv::DNS).to receive(:new).with(:nameserver => "resolver1.opendns.com").and_return dns_instance_double
        expect(Time).to receive(:now).at_least(:once).and_return Time.new(2000, 01, 01, 00, 00, 00, "-06:00")
        expect(File).to receive(:new).with(settings_file, "w").and_return file_double
        expect(FileUtils).to receive(:chmod).with(0600, settings_file)
        expect(YAML).to receive(:dump).with({
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.5",
          "updated_at" => "2000-01-01 06:00:00 UTC"
        }, file_double)

        update_on_change
      end
    end

    context "when the IP Address has not changed" do
      it do
        expect(YAML).to receive(:load_file).with(settings_file).and_return(
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        )
        expect(dns_instance_double).to receive(:getaddress).with("myip.opendns.com").and_return "1.2.3.4"
        expect(Resolv::DNS).to receive(:new).with(:nameserver => "resolver1.opendns.com").and_return dns_instance_double
        expect(WebMock).not_to have_requested :post, update_url
        expect(YAML).not_to receive :dump

        update_on_change
      end
    end
  end

  describe ".init_settings" do
    subject(:init_settings) { Google::Ddns.init_settings settings_directory, settings_file }
    context "when run in a terminal context" do
      before { stub_request(:post, update_url).to_return :body => "good 1.2.3.4" }
      it do
        expect($stdout).to receive(:isatty).and_return true
        expect(FileUtils).to receive(:mkdir_p).with(settings_directory)
        expect($stdin).to receive(:gets).and_return 'host.example.com', 'user', 'pass'
        expect(File).to receive(:new).with(settings_file, "w").and_return file_double
        expect(FileUtils).to receive(:chmod).with(0600, settings_file)
        expect(Time).to receive(:now).at_least(:once).and_return Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        expect(YAML).to receive(:dump).with({
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => "2000-01-01 05:59:59 UTC"
        }, file_double)

        init_settings

        expect(WebMock).to have_requested(:post, update_url).with(
          :basic_auth => ["user", "pass"],
          :body => { :hostname => "host.example.com" }
        )
      end
    end

    context "when run in a non-terminal context" do
      it do
        expect($stdout).to receive(:isatty).and_return false
        expect(Google::Ddns.logger).to receive(:error).with "No Google DDNS setup information found! Please run google-ddns from an interactive terminal to get setup."
        expect($stdin).not_to receive :gets

        expect do
          init_settings
        end.to raise_error SystemExit

        expect(WebMock).not_to have_requested :post, update_url
      end
    end

  end

  describe ".update_ip" do
    subject(:update_ip) do
      Google::Ddns.update_ip({
        "username" => "user",
        "password" => "pass",
        "hostname" => "host.example.com"
      }, settings_file)
    end

    context "when a 'good' response is received" do
      before { stub_request(:post, update_url).to_return :body => "good 1.2.3.4" }
      it do
        expect(Google::Ddns.logger).to receive(:info).with("Updated host.example.com IP Address to 1.2.3.4.")
        expect(File).to receive(:new).with(settings_file, "w").and_return file_double
        expect(FileUtils).to receive(:chmod).with(0600, settings_file)
        expect(Time).to receive(:now).at_least(:once).and_return Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        expect(YAML).to receive(:dump).with({
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => "2000-01-01 05:59:59 UTC"
        }, file_double)

        update_ip

        expect(WebMock).to have_requested(:post, update_url).with(
          :basic_auth => ["user", "pass"],
          :body => { :hostname => "host.example.com" }
        )
      end
    end

    context "when a 'nochg' response is received" do
      before { stub_request(:post, update_url).to_return :body => "nochg 1.2.3.4" }
      it do
        expect(Google::Ddns.logger).to receive(:info).with("Tried to update, but host.example.com IP Address was already set to 1.2.3.4.")
        expect(File).to receive(:new).with(settings_file, "w").and_return file_double
        expect(FileUtils).to receive(:chmod).with(0600, settings_file)
        expect(Time).to receive(:now).at_least(:once).and_return Time.new(1999, 12, 31, 23, 59, 59, "-06:00")
        expect(YAML).to receive(:dump).with({
          "hostname" => "host.example.com",
          "username" => "user",
          "password" => "pass",
          "ip_address" => "1.2.3.4",
          "updated_at" => "2000-01-01 05:59:59 UTC"
        }, file_double)

        update_ip
      end
    end

    context "when a non-200 response code is received" do
      before { stub_request(:post, update_url).to_return :status => 500, :body => "error" }
      it do
        expect(Google::Ddns.logger).to receive(:error).with "Error updating IP Address! Received response code 500 and body \"error\"."
        expect(YAML).not_to receive :dump

        expect do
          update_ip
        end.to raise_error SystemExit
      end
    end

    context "when an unsuccessful response body is received" do
      before { stub_request(:post, update_url).to_return :status => 200, :body => "nohost" }
      it do
        expect(Google::Ddns.logger).to receive(:error).with "Error updating IP Address! Received response code 200 and body \"nohost\"."
        expect(YAML).not_to receive :dump

        expect do
          update_ip
        end.to raise_error SystemExit
      end
    end
  end

  describe ".logger" do
    subject(:logger) { Google::Ddns.logger }
    before { Google::Ddns.instance_variable_set :@logger, nil }
    context "when run in a terminal context" do
      it do
        expect($stdout).to receive(:isatty).and_return true

        expect(logger.level).to eq Logger::INFO
      end
    end

    context "when run in a non-terminal context (e.g. cron)" do
      it do
        expect($stdout).to receive(:isatty).and_return false

        expect(logger.level).to eq Logger::WARN
      end
    end
  end
end
