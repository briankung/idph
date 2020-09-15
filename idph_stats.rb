require 'sinatra'
require "sinatra/reloader" if development?
require 'httparty'
require 'thamble'

IDPH_COVID_TEST_DATA = "https://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1".freeze
IDPH_COVID_HOSPITAL_DATA = "https://www.dph.illinois.gov/sitefiles/COVIDHospitalRegions.json?nocache=1".freeze
SELECT_COUNTIES = %w{Illinois Cook Lake}.freeze
SELECT_HEADERS = %w{confirmed_cases total_tested deaths}.freeze
DEFAULT_TABLE_ATTRIBUTES = {
  table: {style: 'border: 2px solid black;border-collapse: collapse;'},
  th: {style: 'border: thin solid black;'},
  td: {style: 'border: thin solid black;'},
}.freeze

get '/' do
  hospital_data = HTTParty.get(IDPH_COVID_HOSPITAL_DATA).parsed_response
  test_data = HTTParty.get(IDPH_COVID_TEST_DATA).parsed_response

  region_10_hospitalization = hospital_data['regionValues'].find {|region| region['id'] == 10}.reject! {|k,_| k =~ /^(region|id)$/}
  state_hospitalization = hospital_data['statewideValues']
  state_hospitalization_historic = hospital_data['HospitalUtilizationResults']

  test_results = test_data['historical_county']['values'].map do |date|
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

  region_10_table = Thamble.table(region_10_hospitalization, DEFAULT_TABLE_ATTRIBUTES)
  state_hospitalization_table = Thamble.table(state_hospitalization, DEFAULT_TABLE_ATTRIBUTES)
  state_hospitalization_historic_table = Thamble.table(state_hospitalization_historic.map(&:values).reverse, {
    headers: state_hospitalization_historic.first.keys,
    **DEFAULT_TABLE_ATTRIBUTES,
    table: {style: 'border: 2px solid black;border-collapse: collapse;', class: :collapsible},
  })
  test_results_table = Thamble.table(test_results.map(&:values), {
    headers: test_results.first.keys,
    **DEFAULT_TABLE_ATTRIBUTES,
    table: {style: 'border: 2px solid black;border-collapse: collapse;', class: :collapsible},
  })

  <<~HTML
    <h1>Region 10</h1>
    #{region_10_table}

    <h1>Statewide Hospitalization Data</h1>
    #{state_hospitalization_table}

    <h1>Historic Statewide Hospitalization Data</h1>
    #{state_hospitalization_historic_table}

    <h1>Historic Testing Data</h1>
    #{test_results_table}

    <script type="text/javascript">
      const toggleDisplay = (el) => {
        el.style.display = (el.style.display == 'none' ? null : 'none');

      };

      const collapseTable = (e) => {
        const table = e.target.closest('table');
        [...table.querySelectorAll('tbody tr:not(:first-child)')].forEach(toggleDisplay);
        e.preventDefault();
      };

      const collapsibleTables = [...document.querySelectorAll('table.collapsible')];

      collapsibleTables.forEach(table => {
        const tableContents = [...table.querySelectorAll('*')];
        tableContents.forEach(el => el.onclick = collapseTable);
        tableContents[0].click();
      });
    </script>
  HTML
end
