ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Fix for CGI class variable initialization issue with Ruby 3.2.3 + Alpine + GlobalID
require "cgi"
unless CGI.class_variable_defined?(:@@accept_charset)
  CGI.class_variable_set(:@@accept_charset, "UTF-8")
end
