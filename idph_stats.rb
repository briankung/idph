require 'sinatra'
require "sinatra/reloader" if development?
require 'httparty'
require 'thamble'

IDPH_COVID_TEST_DATA = "https://www.dph.illinois.gov/sitefiles/COVIDHistoricalTestResults.json?nocache=1".freeze
IDPH_COVID_HOSPITAL_DATA = "https://www.dph.illinois.gov/sitefiles/COVIDHospitalRegions.json?nocache=1".freeze
SELECT_COUNTIES = %w{Illinois Chicago Cook Lake}.freeze
SELECT_HEADERS = %w{total_tested confirmed_cases deaths}.freeze
SELECT_HOSPITALIZATION_DATA = %w{ICUCovidPatients ICUCapacity VentCapacity VentCovidPatients}.freeze
SELECT_STATEWIDE_HOSPITALIZATION_DATA = %w{reportDate ICUInUseBedsCOVID ICUBeds VentilatorInUseCOVID VentilatorCapacity}.freeze

get '/' do
  hospital_data = HTTParty.get(IDPH_COVID_HOSPITAL_DATA).parsed_response
  test_data = HTTParty.get(IDPH_COVID_TEST_DATA).parsed_response

  region_10_hospitalization = hospital_data['regionValues'].find {|region| region['id'] == 10}.reject! {|k,_| k =~ /^(region|id)$/}
  state_hospitalization = hospital_data['statewideValues'].slice(*SELECT_HOSPITALIZATION_DATA)
  state_hospitalization_historic = hospital_data['HospitalUtilizationResults'].map {_1.slice(*SELECT_STATEWIDE_HOSPITALIZATION_DATA)}

  test_results = test_data['historical_county']['values'].map do |date|
    date['values'].filter_map do |county|
      next unless SELECT_COUNTIES.include? county['County']
      county_name = county.delete('County').downcase
      county = county_name == 'illinois' ? county.slice(*SELECT_HEADERS.rotate) : county.slice(*SELECT_HEADERS)
      county.transform_keys! {|k| "#{county_name}_#{k}".to_sym}
      {date: date['testDate']}.merge(county)
    end
  end.transpose

  region_10_table = Thamble.table(region_10_hospitalization)
  state_hospitalization_table = Thamble.table(state_hospitalization)
  state_hospitalization_historic_table = Thamble.table(state_hospitalization_historic.map(&:values).reverse, {
    headers: state_hospitalization_historic.first.keys,
    table: {id: "hospitalization-data"},
  })


  test_results_tables = test_results.each_with_index.map do |results, i|
    Thamble.table(results.map(&:values), {
      headers: results.first.keys,
      table: {id: "test-results-#{i}"},
    })
  end

  <<~HTML
    <style>
      tr:nth-child(odd) {
        background: #DDD
      }
      table {
        border: 2px solid black;
        border-collapse: collapse
      }

      th, td {
        border: thin solid black;
      }
    </style>

    <h1>Test Results Data</h1>
    #{
      test_results_tables.each_with_index.map do |results, i|
         %Q{
            <h2>#{SELECT_COUNTIES[i]}<span class="toggle-collapse" data-target="test-results-#{i}">🗞</span></h2>
            #{results}
          }
      end.join("\n")
    }

    <h1>Hospitalization Data</h1>
    <h2>Region 10</h2>
    #{region_10_table}

    <h2>Statewide Hospitalization Data</h2>
    #{state_hospitalization_table}

    <h2>Historic Statewide Hospitalization Data <span class="toggle-collapse" data-target="hospitalization-data">🗞</span></h2>
    #{state_hospitalization_historic_table}

    <script type="text/javascript">
      const toggleDisplay = (el) => {
        el.style.display = (el.style.display == 'none' ? null : 'none');
      };

      [...document.querySelectorAll('.toggle-collapse')].forEach(toggle => {
        toggle.onclick = (e) => {
          const table = document.getElementById(toggle.dataset.target);
          [...table.querySelectorAll('tbody tr:not(:first-child)')].forEach(toggleDisplay);
          e.preventDefault();
        };

        toggle.click();
      });
    </script>
  HTML
end
