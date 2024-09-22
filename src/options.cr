require "./completions.cr"
require "./config_initializer.cr"
require "yaml"

macro append_to_yaml_array(hash, key, value)
  tmp = [] of YAML::Any
  {{hash.id}}[{{key.stringify}}].as_a.each do |item|
    tmp << item
  end
  tmp << YAML::Any.new({{value}})
  {{hash.id}}[{{key.stringify}}] = YAML::Any.new(tmp)
end

def run_options_parser
  # Check config file
  config_init = ConfigInitializer.new
  noir_options = config_init.read_config

  OptionParser.parse do |parser|
    parser.banner = "USAGE: noir <flags>\n"
    parser.separator "FLAGS:"
    parser.separator "  BASE:".colorize(:blue)
    parser.on "-b PATH", "--base-path ./app", "(Required) Set base path" { |var| noir_options["base"] = YAML::Any.new(var) }
    parser.on "-u URL", "--url http://..", "Set base url for endpoints" { |var| noir_options["url"] = YAML::Any.new(var) }

    parser.separator "\n  OUTPUT:".colorize(:blue)
    parser.on "-f FORMAT", "--format json", "Set output format\n  * plain yaml json jsonl markdown-table\n  * curl httpie oas2 oas3\n  * only-url only-param only-header only-cookie only-tag" { |var| noir_options["format"] = YAML::Any.new(var) }
    parser.on "-o PATH", "--output out.txt", "Write result to file" { |var| noir_options["output"] = YAML::Any.new(var) }
    parser.on "--set-pvalue VALUE", "Specifies the value of the identified parameter for all types" do |var|
      append_to_yaml_array(noir_options, set_pvalue, var)
    end

    parser.on "--set-pvalue-header VALUE", "Specifies the value of the identified parameter for headers" do |var|
      append_to_yaml_array(noir_options, set_pvalue_header, var)
    end

    parser.on "--set-pvalue-cookie VALUE", "Specifies the value of the identified parameter for cookies" do |var|
      append_to_yaml_array(noir_options, set_pvalue_cookie, var)
    end

    parser.on "--set-pvalue-query VALUE", "Specifies the value of the identified parameter for query parameters" do |var|
      append_to_yaml_array(noir_options, set_pvalue_query, var)
    end

    parser.on "--set-pvalue-form VALUE", "Specifies the value of the identified parameter for form data" do |var|
      append_to_yaml_array(noir_options, set_pvalue_form, var)
    end

    parser.on "--set-pvalue-json VALUE", "Specifies the value of the identified parameter for JSON data" do |var|
      append_to_yaml_array(noir_options, set_pvalue_json, var)
    end

    parser.on "--set-pvalue-path VALUE", "Specifies the value of the identified parameter for path parameters" do |var|
      append_to_yaml_array(noir_options, set_pvalue_path, var)
    end

    parser.on "--status-codes", "Display HTTP status codes for discovered endpoints" do
      noir_options["status_codes"] = YAML::Any.new(true)
    end

    parser.on "--exclude-codes 404,500", "Exclude specific HTTP response codes (comma-separated)" { |var| noir_options["exclude_codes"] = YAML::Any.new(var) }

    parser.on "--include-path", "Include file path in the plain result" do
      noir_options["include_path"] = YAML::Any.new(true)
    end

    parser.on "--no-color", "Disable color output" do
      noir_options["color"] = YAML::Any.new(false)
    end

    parser.on "--no-log", "Displaying only the results" do
      noir_options["nolog"] = YAML::Any.new(true)
    end

    parser.separator "\n  TAGGER:".colorize(:blue)
    parser.on "-T", "--use-all-taggers", "Activates all taggers for full analysis coverage" { |_| noir_options["all_taggers"] = YAML::Any.new(true) }
    parser.on "--use-taggers VALUES", "Activates specific taggers (e.g., --use-taggers hunt,oauth)" { |var| noir_options["use_taggers"] = YAML::Any.new(var) }
    parser.on "--list-taggers", "Lists all available taggers" do
      puts "Available taggers:"
      techs = NoirTaggers.taggers
      techs.each do |tagger, value|
        puts "  #{tagger.to_s.colorize(:green)}"
        value.each do |k, v|
          puts "    #{k.to_s.colorize(:blue)}: #{v}"
        end
      end
      exit
    end

    parser.separator "\n  DELIVER:".colorize(:blue)
    parser.on "--send-req", "Send results to a web request" { |_| noir_options["send_req"] = YAML::Any.new(true) }
    parser.on "--send-proxy http://proxy..", "Send results to a web request via an HTTP proxy" { |var| noir_options["send_proxy"] = YAML::Any.new(var) }
    parser.on "--send-es http://es..", "Send results to Elasticsearch" { |var| noir_options["send_es"] = YAML::Any.new(var) }
    parser.on "--with-headers X-Header:Value", "Add custom headers to be included in the delivery" do |var|
      append_to_yaml_array(noir_options, send_with_headers, var)
    end
    parser.on "--use-matchers string", "Send URLs that match specific conditions to the Deliver" do |var|
      append_to_yaml_array(noir_options, use_matchers, var)
    end
    parser.on "--use-filters string", "Exclude URLs that match specified conditions and send the rest to Deliver" do |var|
      append_to_yaml_array(noir_options, use_filters, var)
    end

    parser.separator "\n  DIFF:".colorize(:blue)
    parser.on "--diff-path ./app2", "Specify the path to the old version of the source code for comparison" { |var| noir_options["diff"] = YAML::Any.new(var) }

    parser.separator "\n  TECHNOLOGIES:".colorize(:blue)
    parser.on "-t TECHS", "--techs rails,php", "Specify the technologies to use" { |var| noir_options["techs"] = YAML::Any.new(var) }
    parser.on "--exclude-techs rails,php", "Specify the technologies to be excluded" { |var| noir_options["exclude_techs"] = YAML::Any.new(var) }
    parser.on "--list-techs", "Show all technologies" do
      puts "Available technologies:"
      techs = NoirTechs.techs
      techs.each do |tech, value|
        puts "  #{tech.to_s.colorize(:green)}"
        value.each do |k, v|
          puts "    #{k.to_s.colorize(:blue)}: #{v}"
        end
      end
      exit
    end

    parser.separator "\n  CONFIG:".colorize(:blue)
    parser.on "--config-file ./config.yaml", "Specify the path to a configuration file in YAML format" { |var| noir_options["config_file"] = YAML::Any.new(var) }
    parser.on "--concurrency 100", "Set concurrency" { |var| noir_options["concurrency"] = YAML::Any.new(var) }
    parser.on "--generate-completion zsh", "Generate Zsh/Bash completion script" do |var|
      case var
      when "zsh"
        puts generate_zsh_completion_script
        puts "\n"
        puts "> Instructions: Copy the content above and save it in the zsh-completion directory as _noir".colorize(:yellow)
      when "bash"
        puts generate_bash_completion_script
        puts "\n"
        puts "> Instructions: Copy the content above and save it in the .bashrc file as noir.".colorize(:yellow)
      else
        puts "ERROR: Invalid completion type.".colorize(:yellow)
        puts "e.g., noir --generate-completion zsh"
        puts "e.g., noir --generate-completion bash"
      end

      exit
    end

    parser.separator "\n  DEBUG:".colorize(:blue)
    parser.on "-d", "--debug", "Show debug messages" do
      noir_options["debug"] = YAML::Any.new(true)
    end
    parser.on "-v", "--version", "Show version" do
      puts Noir::VERSION
      exit
    end
    parser.on "--build-info", "Show version and Build info" do
      puts Crystal::DESCRIPTION
      exit
    end
    parser.separator "\n  OTHERS:".colorize(:blue)
    parser.on "-h", "--help", "Show help" do
      puts parser
      puts ""
      puts "EXAMPLES:"
      puts "  Basic run of noir:".colorize(:green)
      puts "      $ noir -b ."
      puts "  Running noir targeting a specific URL and forwarding results through a proxy:".colorize(:green)
      puts "      $ noir -b . -u http://example.com"
      puts "      $ noir -b . -u http://example.com --send-proxy http://localhost:8090"
      puts "  Running noir for detailed analysis:".colorize(:green)
      puts "      $ noir -b . -T --include-path"
      puts "  Running noir with output limited to JSON or YAML format, without logs:".colorize(:green)
      puts "      $ noir -b . -f json --no-log"
      puts "      $ noir -b . -f yaml --no-log"
      exit
    end
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option.".colorize(:yellow)
      STDERR.puts parser
      exit(1)
    end
    parser.missing_option do |flag|
      STDERR.puts "ERROR: #{flag} is missing an argument.".colorize(:yellow)
      exit(1)
    end
  end

  noir_options
end
