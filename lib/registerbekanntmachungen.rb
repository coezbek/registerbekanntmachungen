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
@headless = true # Default to headless mode
@oldest_mode = false
@merge = false

# Add this method to determine the oldest unsaved date in the last 8 weeks
def oldest_unsaved_date
  # Calculate the range of the last 8 weeks
  max_date = Date.today - 7 * 8
  date_range = (max_date..(Date.today - 1)).to_a

  # Find the oldest date without a JSON file
  date_range.each do |date|
    filename = "db/#{date.strftime('%Y-%m')}/registerbekanntmachungen-#{date.strftime('%Y-%m-%d')}.json"
    return date unless File.exist?(filename)
  end

  nil # Return nil if all dates are already saved
end

def file_name(date)
  "db/#{date.strftime('%Y-%m')}/registerbekanntmachungen-#{date.strftime('%Y-%m-%d')}.json"
end

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

  opts.on('--no-save', 'Do not save any data just print to stdout') do
    @no_save = true
  end

  opts.on('--start-date DATE', 'Start date in format DD.MM.YYYY or YYYY-MM-DD') do |date|
    @start_date = date
  end

  opts.on('--end-date DATE', 'End date in format DD.MM.YYYY or YYYY-MM-DD') do |date|
    @end_date = date
  end

  # Update the OptionParser block for the `-o` option
  opts.on('-o', '--oldest', 'Download oldest available data not already saved') do
    @oldest_mode = true
  end

  opts.on('-y', '--yesterday', 'Download yesterday\'s data') do
    @start_date = @end_date = (Date.today - 1).strftime('%d.%m.%Y')
  end

  opts.on('-a', '--all', 'Download all data from the last 8 weeks') do
    @all = true
  end

  opts.on('-m', '--merge', 'Merge new data with existing data') do
    @merge = true
  end

  opts.on('--no-headless', 'Don\'t run browser in headless mode') do
    @headless = false
  end

  opts.on('--headless', 'Run in headless mode (default)') do
    # @headless == true is the default
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

if @oldest_mode && @all
  puts 'Cannot use --oldest and --all options together.'.red
  exit(1)
end

if @merge
  @reload = true # Ensure data is reloaded/overriden when merging
end

if @oldest_mode
  if @start_date || @end_date
    puts "Can't specify a date range when using '--oldest' option.".red
    exit(1)
  end
  
  oldest_date = oldest_unsaved_date
  puts "Oldest unsaved date in the last 8 weeks: #{oldest_date.strftime('%Y-%m-%d')}" if oldest_date && @verbose
  if oldest_date
    @start_date = @end_date = oldest_date.strftime('%Y-%m-%d')
  else
    puts "No unsaved data found in the last 8 weeks.".red
    exit(1)
  end
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
  puts "Start date #{start_date_obj} is earlier than the earliest allowed date #{max_date}, adjusting.".red
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
  File.exist?(file_name(date)) && !@reload
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

# Extend timeout of Watir
Watir.default_timeout = 60

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

  navigation_mode = :from_homepage # :direct 

  case navigation_mode 
  when :from_homepage

    # Navigate to the Handelsregister homepage
    puts 'Navigating to the Handelsregister homepage...' if @verbose
    browser.goto('https://www.handelsregister.de/rp_web/welcome.xhtml')

    # Wait for the Registerbekanntmachungen section to load
    puts 'Waiting for the "Registerbekanntmachungen" section to load...' if @verbose
    browser.wait_until { browser.a(title: 'Registerbekanntmachungen').exists? }

    puts 'Accessing the "Registerbekanntmachungen" section...'
    attempts_to_find_section = 3
    while attempts_to_find_section > 0
      found = false
      browser.as(title: 'Registerbekanntmachungen').each_with_index do |link, index|
        if link.present?
          link.click
          puts "Clicked Link ##{index + 1}: Title: #{link.title}, Href: #{link.href}"
          found = true
          break
        else
          puts "Link not present ##{index + 1}: Title: #{link.title}, Href: #{link.href}"
        end
      end
      break if found
      attempts_to_find_section -= 1
      sleep 3
    end

    # Wait for the page to load
    puts "Waiting for the 'Registerbekanntmachungen' title to be set..." if @verbose
    browser.wait_until { browser.title.include?('Registerbekanntmachungen') }

    # Wait until pop-up disappears
    puts 'Waiting for the pop-up to disappear...' if @verbose
    browser.wait_until { !browser.div(text: "Ihre Anfrage wird bearbeitet").present? }
  
  when :direct
    # Navigate to the Handelsregister homepage
    puts 'Navigating to the Bekanntmachungen page...' if @verbose
    browser.goto('https://www.handelsregister.de/rp_web/xhtml/bekanntmachungen.xhtml')
  else
    raise "Invalid navigation mode: #{navigation_mode}"
  end

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
    if File.exist?(file_name(date_obj)) && !@reload
      puts "Data for #{date_text} already exists, skipping." if @verbose
      dates_skipped += 1
      next
    end

    existing_data = { 'announcements' => [] }
    if @merge && File.exist?(file_name(date_obj))
      # Load existing data
      existing_data = JSON.parse(File.read(file_name(date_obj)))

      puts "Merging with #{existing_data['announcements'].size} existing announcements for date #{date_text}..." if @verbose
    end

    announcements.each_with_index do |a, index|

      puts "Processing announcement ##{index + 1} of ##{announcements.size} for date #{date_text}..." if @verbose
      label = a.label
      onclick = a.attribute_value('onclick')
      text = label.text.strip
      lines = text.split("\n").map(&:strip)

      announcement = parse_announcement(lines, onclick)

      # Prepend 'date' to each announcement
      announcement = { date: date_text }.merge!(announcement)

      # Check if this announcement is already in the existing data
      existing_announcements = existing_data['announcements'].select { |e|
        (e['id'] == nil || e['id'] == announcement[:id]) &&
        e['type'] == announcement[:type] && 
        e['amtsgericht'] == announcement[:amtsgericht] && 
        e['registernummer'] == announcement[:registernummer]
      }

      if @merge && existing_announcements.size == 1

        announcement[:details] = existing_announcements.first['details']
        
      else

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
          total_announcements += 1
        else
          puts "WARN: Failed to find link to click for announcement details #{index} on #{date_text}: #{onclick}"
        end
      end

      announcements_data << announcement
      unique_types[announcement[:type]] += 1      
    end

    data_by_date[date_obj] = {
      date: date_text,
      # Add date+time of scrape in JSON format, e.g. 2012-04-23T18:25:43.511Z
      date_of_scrape: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
      tool_version: Registerbekanntmachungen::VERSION,
      number_of_announcements: announcements_data.size,
      announcements: announcements_data.sort_by { |a| a[:id] }
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
      number_of_announcements: 0,
      announcements: []
    }
    dates_downloaded += 1
  end

  # Save data per date
  data_by_date.each do |date_obj, data|
    filename = "db/#{date_obj.strftime('%Y-%m')}/registerbekanntmachungen-#{date_obj.strftime('%Y-%m-%d')}.json"
    if @no_save
      puts "Data for date #{data[:date]} not saved to file (no-save option enabled)." if @verbose
      puts JSON.pretty_generate(data)
    else
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'w') do |f|
        f.write(JSON.pretty_generate(data))
      end
      puts "Found #{data[:announcements].size} announcements for date #{data[:date]} and saved to #{filename}" if @verbose
    end
  end

  # Output statistics
  puts "Processed #{dates_downloaded} dates out of #{total_dates}."
  puts "Skipped #{dates_skipped} dates due to existing data."
  puts "Total announcements newly downloaded: #{total_announcements}"

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
