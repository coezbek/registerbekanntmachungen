require 'watir'
require 'webdrivers'
require 'colorize'
require 'optparse'
require 'date'
require 'fileutils'
require 'json'

require_relative 'registerbekanntmachungen/parser'
require_relative 'registerbekanntmachungen/version'

return if $0 != __FILE__

# Initialize variables for command-line options
@verbose = false
@reload = false
@no_save = false
@start_date = nil
@end_date = nil
@all = false
@headless = false

# Set up OptionParser
opts = OptionParser.new do |opts|
  opts.banner = 'Usage: registerbekanntmachungen [options]'

  opts.on('-v', '--verbose', 'Enable verbose/debug output') do
    @verbose = true
    puts "Verbose mode enabled".yellow
  end

  opts.on('-r', '--reload', 'Reload data and skip cache') do
    @reload = true
  end

  opts.on('--no-save', 'Do not save any data') do
    @no_save = true
  end

  opts.on('--start-date DATE', 'Start date in format DD.MM.YYYY') do |date|
    @start_date = date
  end

  opts.on('--end-date DATE', 'End date in format DD.MM.YYYY') do |date|
    @end_date = date
  end

  opts.on('-y', 'Download yesterday\'s data') do
    @start_date = @end_date = (Date.today - 1).strftime('%d.%m.%Y')
  end

  opts.on('-o', 'Download oldest available data') do
    @start_date = @end_date = (Date.today - 7 * 8).strftime('%d.%m.%Y')
  end

  opts.on('--all', 'Download all data from the last 8 weeks') do
    @all = true
  end

  opts.on('--headless', 'Run in headless mode') do
    @headless = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

# Parse the command-line arguments
begin
  opts.parse!
rescue OptionParser::InvalidOption => e
  puts e
  exit(1)
end

# Determine the date range to process
if @all
  start_date_obj = Date.today - 7 * 8 # 8 weeks ago
  end_date_obj = Date.today
elsif @start_date || @end_date
  # Use specified dates in dd.mm.yyyy format with fallback to yyyy-mm-dd
  @start_date ||= @end_date
  @end_date ||= @start_date
  start_date_obj = (Date.strptime(@start_date, '%d.%m.%Y') rescue nil) || Date.strptime(@start_date, '%Y-%m-%d')
  end_date_obj   = (Date.strptime(@end_date,   '%d.%m.%Y') rescue nil) || Date.strptime(@end_date,   '%Y-%m-%d')
else
  # Default to today
  start_date_obj = end_date_obj = Date.today
end

# Ensure start_date_obj is not earlier than allowed (max 8 weeks ago)
max_date = Date.today - 7 * 8
if start_date_obj < max_date
  start_date_obj = max_date
end

# Generate the date range
date_range = (start_date_obj..end_date_obj).to_a

# Initialize counters for statistics
total_dates = date_range.size
dates_downloaded = 0
dates_skipped = 0
total_announcements = 0
unique_types = Hash.new(0)

# Identify dates that already have cached data
cached_dates = date_range.select do |date|
  filename = "db/#{date.strftime('%Y-%m')}/registerbekanntmachungen-#{date.strftime('%Y-%m-%d')}.json"
  File.exist?(filename) && !@reload
end

# Adjust date range to exclude cached dates unless reloading
dates_to_download = date_range - cached_dates

# Say which dates will be downloaded
# Day of week in parentheses
puts "Downloading data for the following dates: #{dates_to_download.map { |d| d.strftime('%Y-%m-%d (%a)')}.join(', ')}".green if @verbose

if dates_to_download.empty? && !@reload
  puts "All data for the specified date range is already downloaded. Use '-r' to re-download.".red
  exit 1
end

# Initialize the headless browser
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--disable-gpu')
options.add_argument('--lang=de-DE')
options.add_argument('--window-size=1920,1080')
options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' \
                     'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                     'Chrome/95.0.4638.69 Safari/537.36')
options.add_argument('--headless') if @headless

# Set language preferences
options.prefs = {
  'intl.accept_languages' => 'de-DE,de'
}

# Initialize the browser
browser = Watir::Browser.new :chrome, options: options

# Maximize browser window to ensure all elements are accessible
browser.window.maximize

begin
  # Navigate to the Handelsregister homepage
  puts 'Navigating to the Handelsregister homepage...' if @verbose
  browser.goto('https://www.handelsregister.de/rp_web/welcome.xhtml')

  # Wait for the Registerbekanntmachungen section to load
  puts 'Waiting for the "Registerbekanntmachungen" section to load...' if @verbose
  browser.wait_until { browser.a(title: 'Registerbekanntmachungen').exists? }

  puts 'Accessing the "Registerbekanntmachungen" section...'
  browser.as(title: 'Registerbekanntmachungen').each_with_index do |link, index|
    puts "Link ##{index + 1}: Title: #{link.title}, Href: #{link.href}, Present? #{link.present?}"

    link.click if link.present?
  end

  # Wait for the page to load
  puts "Waiting for the 'Registerbekanntmachungen' title to be set..." if @verbose
  browser.wait_until { browser.title.include?('Registerbekanntmachungen') }

  # Wait until pop-up disappears
  puts 'Waiting for the pop-up to disappear...' if @verbose
  browser.wait_until { !browser.div(text: "Ihre Anfrage wird bearbeitet").present? }

  # Set the date range in the form
  start_date_str = dates_to_download.first.strftime('%d.%m.%Y')
  end_date_str = dates_to_download.last.strftime('%d.%m.%Y')

  puts "Setting the date range from #{start_date_str} to #{end_date_str}..." if @verbose
  browser.text_field(id: 'bekanntMachungenForm:datum_von_input').set(start_date_str)
  browser.text_field(id: 'bekanntMachungenForm:datum_von_input').send_keys(:escape)
  browser.text_field(id: 'bekanntMachungenForm:datum_bis_input').set(end_date_str)
  browser.text_field(id: 'bekanntMachungenForm:datum_bis_input').send_keys(:escape)

  puts 'Submitting the search form...' if @verbose
  browser.button(id: 'bekanntMachungenForm:rrbSuche').click

  # Wait until pop-up disappears
  puts 'Waiting for the pop-up to disappear...' if @verbose
  browser.wait_until { !browser.div(text: "Ihre Anfrage wird bearbeitet").present? }

  # Wait for the results to load
  sleep 5 # Adjust as necessary

  # Extract data from dl elements
  dl = browser.dl(id: 'bekanntMachungenForm:datalistId_list')
  if dl.exists?
    dts = dl.dts
    dds = dl.dds
  else
    dts = []
  end

  if dts.empty?
    puts "No announcements found for the specified date range."
  end

  # Extract ViewState
  view_state = browser.hidden(name: 'javax.faces.ViewState').value

  # Get cookies
  cookies = browser.cookies.to_a.map { |c| "#{c[:name]}=#{c[:value]}" }.join('; ')

  # Process the announcements grouped by date
  data_by_date = {}

  dts.each_with_index do |dt, index|
    date_text = dt.text.strip
    date_obj = Date.strptime(date_text, '%d.%m.%Y') # Parse as German dates!
    date_text = date_obj.strftime('%Y-%m-%d') # ISO Dates please
    dd = dds[index]
    announcements = dd.as
    announcements_data = []

    # Skip dates that are already cached unless reloading
    if File.exist?("db/registerbekanntmachungen-#{date_obj.strftime('%Y-%m-%d')}.json") && !@reload
      puts "Data for #{date_text} already exists, skipping." if @verbose
      dates_skipped += 1
      next
    end

    announcements.each_with_index do |a, index|

      puts "Processing announcement ##{index + 1} of ##{announcements.size} for date #{date_text}..." if @verbose
      label = a.label
      text = label.text.strip
      lines = text.split("\n").map(&:strip)

      announcement = parse_announcement(lines)

      # Prepend 'date' to each announcement
      announcement = { date: date_text }.merge!(announcement)

      onclick = a.attribute_value('onclick')
      if onclick =~ /fireBekanntmachung\d+\('([^']+)',\s*'([^']+)'\)/
        datum = Regexp.last_match(1)
        id = Regexp.last_match(2)
        
        # Make the POST request
        response_body = get_detailed_announcement(datum, id, view_state, cookies)
      
        # Parse the announcement
        announcement_text = parse_announcement_response(response_body)
        if announcement_text.nil? || announcement_text.empty?
          puts "WARN: Failed to extract announcement details for announcement #{index} on #{date_text} from responsebody: #{text}"
        end

        announcement[:details] = announcement_text
      else
        puts "WARN: Failed to find link to click for announcement details #{index} on #{date_text}: #{onclick}"
      end

      announcements_data << announcement
      unique_types[announcement[:type]] += 1
      total_announcements += 1
    end

    data_by_date[date_obj] = {
      date: date_text,
      # Add date+time of scrape in JSON format, e.g. 2012-04-23T18:25:43.511Z
      date_of_scrape: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
      tool_version: Registerbekanntmachungen::VERSION,
      announcements: announcements_data
    }
    dates_downloaded += 1
  end

  # Add dates with no announcements to the data
  dates_without_announcements = date_range - data_by_date.keys
  dates_without_announcements.each do |date_obj|
    date_text = date_obj.strftime('%Y-%m-%d')
    data_by_date[date_obj] = {
      date: date_text,
      date_of_scrape: Date.today.strftime('%Y-%m-%d'),
      tool_version: Registerbekanntmachungen::VERSION,
      announcements: []
    }
    dates_downloaded += 1
  end

  # Save data per date
  data_by_date.each do |date_obj, data|
    filename = "db/#{date_obj.strftime('%Y-%m')}/registerbekanntmachungen-#{date_obj.strftime('%Y-%m-%d')}.json"
    unless @no_save
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'w') do |f|
        f.write(JSON.pretty_generate(data))
      end
      puts "Found #{data[:announcements].size} announcements for date #{data[:date]} saved to #{filename}" if @verbose
    end
  end

  # Output statistics
  puts "Processed #{dates_downloaded} dates out of #{total_dates}."
  puts "Skipped #{dates_skipped} dates due to existing data."
  puts "Total announcements downloaded: #{total_announcements}"

  puts "Announcement types:"
  unique_types.each do |type, count|
    puts "  #{type}: #{count}"
  end

rescue Watir::Wait::TimeoutError => e

  Dir.mkdir('tmp') unless File.directory?('tmp')
  filename = File.join('tmp', "error-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}.png")
  browser.screenshot.save(filename)

  raise

ensure
  puts 'Closing the browser...'
  browser.close
end
