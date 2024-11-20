require 'sinatra'
require 'roo'
require 'json'

class App < Sinatra::Base

  set :bind, '0.0.0.0'
  set :port, ENV['PORT'] || 4567

  DATA_FILE = 'cleaned_agprices.xlsx' # Path to the cleaned Excel file

  # Function to normalize names directly
  def normalize_name(name)
    name.to_s.downcase.strip # Standardize case and trim whitespace
  end

  # Helper to read and prepare year-over-year data
  def read_and_prepare_chart_data
    sheet = Roo::Spreadsheet.open(DATA_FILE)
    headers = sheet.row(1).map(&:strip) # Clean column headers

    # Parse rows into a data structure
    rows = []
    (2..sheet.last_row).each do |i|
      row_data = Hash[headers.zip(sheet.row(i))]
      row_data.each do |key, value|
        row_data[key] = value.to_s.strip if value.is_a?(String)
      end
      row_data['Normalized Name'] = normalize_name(row_data['Name']) # Add normalized name
      rows << row_data
    end

    # Group data by normalized name and year
    grouped_data = rows.group_by { |row| row['Normalized Name'] }
    year_over_year_data = grouped_data.transform_values do |entries|
      entries.group_by { |entry| entry['Year'] }.transform_values do |year_entries|
        # Combine numerical fields for the same year
        numerical_fields = %w[RetailPrice Yield CupEquivalentSize CupEquivalentPrice]
        combined_entry = year_entries.first.dup
        numerical_fields.each do |field|
          combined_entry[field] = year_entries.map { |e| e[field].to_f }.sum.round(2)
        end
        combined_entry
      end
    end

    year_over_year_data
  end

  # API endpoint to fetch all product names
  get '/products' do
    content_type :json
    begin
      data = read_and_prepare_chart_data.keys
      data.to_json # Ensure proper JSON format
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # API endpoint to fetch year-over-year data for a specific product
  get '/chart-data/:product' do
    content_type :json
    begin
      product = params[:product].downcase
      data = read_and_prepare_chart_data
      if data[product]
        data[product].to_json # Ensure proper JSON format
      else
        status 404
        { error: "Product not found" }.to_json
      end
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # Root route - Serve the frontend
  get '/' do
    erb :index
  end

end
