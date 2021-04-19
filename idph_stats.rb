require 'sinatra'
require "sinatra/reloader" if development?
require 'httparty'
require 'thamble'
require 'pry'

IDPH_COVID_HOSPITAL_DATA = "https://idph.illinois.gov/DPHPublicInformation/api/COVID/GetHospitalizationResults".freeze
COUNTY_TEST_DATA = "https://idph.illinois.gov/DPHPublicInformation/api/COVID/GetCountyHistorical?countyName=".freeze
SELECT_COUNTIES = %w{Illinois Chicago Cook Lake}.freeze
SELECT_HEADERS = %i{tested confirmed_cases deaths}.freeze
SELECT_STATEWIDE_HOSPITALIZATION_DATA = %i{ReportDate ICUInUseBedsCOVID ICUBeds VentilatorInUseCOVID VentilatorCapacity}.freeze
DATE_FORMAT = "%-m/%-d/%Y"

get '/' do
  hospital_data = JSON.parse(HTTParty.get(IDPH_COVID_HOSPITAL_DATA, format: :plain), symbolize_names: true)
  test_data = SELECT_COUNTIES.map do |county|
    JSON.parse(HTTParty.get("#{COUNTY_TEST_DATA}#{county}", format: :plain), symbolize_names: true).fetch(:values)
  end

  case hospital_data
  in  {
        regionValues: [*, {id: 10, **region_10_hospitalization}, *],
        HospitalUtilizationResults: state_hospitalization_historic
      }
    state_hospitalization_historic.map! do |data|
      data.slice(*SELECT_STATEWIDE_HOSPITALIZATION_DATA).tap {|d| d[:ReportDate] = Time.parse(d[:ReportDate]).strftime(DATE_FORMAT)}
    end
  else
  end

  test_results = test_data.map do |values|
    values.map do |county|
      county_name = county.delete(:CountyName).downcase
      date = county.delete(:reportDate).then {|d| Time.parse(d).strftime(DATE_FORMAT)}
      county = (county_name == 'illinois') ? county.slice(*SELECT_HEADERS.rotate) : county.slice(*SELECT_HEADERS)
      county.transform_keys! {|k| "#{county_name}_#{k}".to_sym}
      {date: date, **county}
    end
  end

  test_results.map! {_1.last(28)} # only show the last 28 days' worth of data

  region_10_table = Thamble.table([region_10_hospitalization.values], {headers: region_10_hospitalization.keys})
  state_hospitalization_historic_table = Thamble.table(state_hospitalization_historic.map(&:values).last(14), {
    headers: state_hospitalization_historic.first.keys,
    table: {id: "hospitalization-data"},
  })

  test_results_tables = test_results.each_with_index.map do |results, i|
    Thamble.table(results.map(&:values), {
      headers: results.first.keys,
      table: {id: "test-results-#{i}"},
    })
  end

  STATE_RECOVERY_DATA_COLUMN_ORDER = %i{report_date sample_surveyed recovered_cases recovered_and_deceased_cases recovery_rate}

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

    <h1>Test Results Data 🍺🦠🧪📝</h1>
    #{
      test_results_tables.each_with_index.map do |results, i|
         %Q{
            <h2>#{SELECT_COUNTIES[i]}<span class="toggle-collapse" data-target="test-results-#{i}">🗞</span></h2>
            #{results}
          }
      end.join("\n")
    }

    <!-- <h1>State Recovery Data <span class="toggle-collapse" data-target="state-recovery-data">🗞</span></h1>
    {state_recovery_table} -->

    <h1>Hospitalization Data 🍺🦠🏥😷</h1>
    <h2>Region 10</h2>
    #{region_10_table}

    <h2>Historic Statewide Hospitalization Data <span class="toggle-collapse" data-target="hospitalization-data">🗞</span></h2>
    #{state_hospitalization_historic_table}

    <script type="text/javascript">
      const toggleDisplay = (el) => {
        el.style.display = (el.style.display == 'none' ? null : 'none');
      };

      [...document.querySelectorAll('.toggle-collapse')].forEach(toggle => {
        toggle.onclick = (e) => {
          const table = document.getElementById(toggle.dataset.target);
          [...table.querySelectorAll('tbody tr:not(:last-child)')].forEach(toggleDisplay);
          e.preventDefault();
        };

        toggle.click();
      });
    </script>
  HTML
end
