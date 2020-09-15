require 'sinatra'
require 'sinatra/json'
require 'httparty'
require 'csv'

IDPH_DATA_URL = "https://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1".freeze
SELECT_COUNTIES = %w{Illinois Cook Lake}.freeze

get '/' do
  response = HTTParty.get(IDPH_DATA_URL, headers: {'Content-Type' => 'application/json'}).parsed_response

  result = response['historical_county']['values'].each_with_object({}) do |date, accumulator|
    accumulator[date['testDate']] = date['values'].filter_map do |county|
      next unless SELECT_COUNTIES.include? county['County']
      county_name = county.delete('County').downcase
      county.reject! {|k,_| k == 'lat' || k == 'lon'}
      county.transform_keys! {|k| "#{county_name}_#{k}"}
      county
    end.reduce(&:merge!)
  end

  json result
end

__END__

I want total tested, confirmed cases, for all dates, for the state, and for lake and cook counties

DATE, STATE TOTAL TESTED, STATE CONFIRMED CASES, COOK TOTAL TESTED, COOK CONFIRMED CASES, LAKE TOTAL TESTED, LAKE CONFIRMED CASES

{
  "testDate": "9/14/2020",
  "total_tested": 4771796,
  "confirmed_cases": 262744,
  "deaths": 8314
}
{
  "County": "Cook ",
  "confirmed_cases": 59865,
  "deaths": 2218,
  "total_tested": 866565,
  "lat": 42.050784,
  "lon": -87.963759
}
{
  "County": "Lake",
  "confirmed_cases": 15818,
  "deaths": 481,
  "total_tested": 221426,
  "lat": 42.3689,
  "lon": -87.8272
}