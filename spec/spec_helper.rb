$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "google/ddns"
require "webmock/rspec"

# Patch for unreleased commit: https://github.com/bblimke/webmock/commit/29388df44f7ed09808a7f51379ad98be44bf3faa#diff-4fd2506a42939f27882b390651103483
raise "Remove WebMock patch!" unless WebMock::VERSION == "2.1.0"
class StubSocket
  def close
  end
end
