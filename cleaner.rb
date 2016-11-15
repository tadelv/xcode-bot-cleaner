#!/usr/bin/ruby

require 'net/http'
require 'openssl'
require 'json'
require 'optparse'

# A crude cleaner script
# It connects to an Xcode server and fetches info regarding all the bots.
# After fetching bot info, you are prompted to specify a bot you are interested in.
# Depending on the command options you can then list integration results or delete integrations,
# that ended with a specific result value, i.e. "build-failed".

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: cleaner.rb [options]\nInspects and optionally cleans Xcode server integrations."

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end
  opts.on('-k', '--klean', 'Clean all failed integrations') do |v|
    options[:klean] = v
  end
  opts.on('-a', '--auth', 'Set authentication <user:pass> for xcode server. REQUIRED if you want to delete integrations') do |v|
    options[:auth] = v
  end
  opts.on('-s', '--server=SERVER_URL', String, 'Set server url, i.e https://localhost:20343/api') do |v|
    puts "#{v}, #{v.class}"
    options[:server] = v
  end
end

opt_parser.parse!(ARGV)

API_URL = (options[:server]).to_s.freeze
BOTS_API_URL = "#{options[:server]}/bots".freeze

class Cleaner
  attr_accessor :opts

  def initialize(options)
    @opts = options
  end

  def fetch_all_bots
    bots_response = `curl -v -k #{BOTS_API_URL}`
    bots_json = JSON.parse(bots_response)
    bot_data = []

    bots_json['results'].each do |result|
      bot_data << { name: result['name'], id: result['_id'], tinyID: result['tinyID'] }
    end

    bot_data
  end

  def clean_integrations(bot, result_filter = '')
    # fetch bot integrations
    puts "#{BOTS_API_URL}/#{bot[:id]}/integrations"

    integrations = JSON.parse(`curl -k #{BOTS_API_URL}/#{bot[:id]}/integrations`)['results']

    failed = []
    result_filter = ['trigger-error', 'canceled'] if result_filter.empty?

    integrations.each do |integration|
      p integration['result'] unless @opts[:klean]
      failed << integration['_id'] if result_filter.include? integration['result']
    end
    return if !@opts[:klean] || !@opts[:auth]
    # purge all failed integrations
    delete_integrations(failed)
  end
  
  def delete_integrations(integrations)
    integrations.each do |integration|
      `curl -v -X DELETE -u "#{@opts[:auth]}" -k #{API_URL}/integrations/#{integration}`
    end
  end
end

cleaner = Cleaner.new(options)

bot_data = cleaner.fetch_all_bots

puts 'Which bot integrations do you want to delete?'
bot_data.each_with_index do |bot, index|
  p "#{index + 1}: #{bot[:name]}"
end
puts 'Enter number:'
num = -1
num = gets.to_i while num < 0 || num > bot_data.count
# array zero index
num -= 1

bot = bot_data[num]

puts 'Enter result filter (leave empty for default: trigger-error, canceled)'
filter = gets

cleaner.clean_integrations(bot, filter)
