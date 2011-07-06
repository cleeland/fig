require 'polyglot'
require 'treetop'

require 'fig/grammar'

module Fig
  class Parser
    def initialize
      @parser = FigParser.new
    end

    def parse_package(package_name, version_name, directory, input)
      input = input.gsub(/#.*$/, '')
      result = @parser.parse(" #{input} ")
      if result.nil? 
        $stderr.puts "#{directory}: #{@parser.failure_reason}"
        exit 10
      end
      result.to_package(package_name, version_name, directory)
    end

#    def parse_descriptor(descriptor)
#      puts @parser.methods.sort
#    end
  end

end
