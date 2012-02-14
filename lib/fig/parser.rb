require 'polyglot'
require 'treetop'

require 'fig/grammar'
require 'fig/logging'
require 'fig/packageparseerror'
require 'fig/repository'
require 'fig/urlaccesserror'
require 'fig/userinputerror'

module Fig; end

# Parses .fig files (wrapping the Treetop-generated parser object) and deals
# with a few restrictions on them.
class Fig::Parser
  def self.node_location(node)
    offset_from_start_of_file = node.interval.first
    input = node.input

    return [
      input.line_of(offset_from_start_of_file),
      input.column_of(offset_from_start_of_file)
    ]
  end

  def initialize(application_config, check_include_versions)
    @parser                 = Fig::FigParser.new
    @application_config     = application_config
    @check_include_versions = check_include_versions
  end

  def parse_package(descriptor, directory, input)
    # Bye bye comments.
    input = input.gsub(/#.*$/, '')

    # Extra space at the end because most of the rules in the grammar require
    # trailing whitespace.
    result = @parser.parse(input + ' ')

    if result.nil?
      Fig::Logging.fatal "#{directory}: #{@parser.failure_reason}"
      raise Fig::PackageParseError.new("#{directory}: #{@parser.failure_reason}")
    end

    package = result.to_package(descriptor, directory)

    check_for_bad_urls(package, descriptor)
    check_for_multiple_command_statements(package)
    check_for_missing_versions_on_include_statements(package)

    return package
  end

  private

  def check_for_bad_urls(package, descriptor)
    bad_urls = []
    package.walk_statements do |statement|
      statement.urls.each do |url|
        # collect all bad urls in bad_urls
        next if not Fig::Repository.is_url?(url)
        bad_urls << url if not @application_config.url_access_allowed?(url)
      end
    end

    raise Fig::URLAccessError.new(bad_urls, descriptor) if not bad_urls.empty?

    return
  end

  def check_for_multiple_command_statements(package)
    command_processed = false
    package.walk_statements do |statement|
      if statement.is_a?(Fig::Statement::Command)
        if command_processed == true
          raise Fig::UserInputError.new(
            %Q<Found a second "command" statement within a "config" block#{statement.position_string()}.>
          )
        end
        command_processed = true
      elsif statement.is_a?(Fig::Statement::Configuration)
        command_processed = false
      end
    end

    return
  end

  def check_for_missing_versions_on_include_statements(package)
    return if not @check_include_versions

    package.walk_statements do |statement|
      if statement.is_a?(Fig::Statement::Include)
        statement.complain_if_version_missing()
      end
    end

    return
  end
end
