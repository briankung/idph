require 'sinatra'
require "sinatra/reloader" if development?
require 'httparty'
require 'thamble'

IDPH_DATA_URL = "https://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1".freeze
SELECT_COUNTIES = %w{Illinois Cook Lake}.freeze
SELECT_HEADERS = %w{confirmed_cases total_tested deaths}

get '/' do
  response = HTTParty.get(IDPH_DATA_URL).parsed_response

  result = response['historical_county']['values'].map do |date|
    row = date['values'].filter_map do |county|
      next unless SELECT_COUNTIES.include? county['County']
      county_name = county.delete('County').downcase
      county.select! {|k,_| SELECT_HEADERS.include?(k)}
      county.transform_keys! {|k| "#{county_name}_#{k}"}
      county
    end

    row.unshift(date: date['testDate'])

    row.reduce(&:merge!)
  end

  table = Thamble.table(result.map(&:values), {
    headers: result.first.keys,
    table: {style: 'border: 2px solid black;border-collapse: collapse;'},
    th: {style: 'border: thin solid black;'},
    td: {style: 'border: thin solid black;'},
  })

  table
end
