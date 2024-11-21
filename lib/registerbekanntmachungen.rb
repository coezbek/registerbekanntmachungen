require 'watir'
require 'webdrivers'
require 'colorize'
require_relative 'registerbekanntmachungen_parser'

return if $0 != __FILE__

opts = OptionParser.new

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

# Initialize the headless browser
browser = Watir::Browser.new :chrome, options: {prefs: {'intl' => {'accept_languages' => 'DE'}}}, headless: true

# Site is responsive and doesn't work if Window is too small
browser.window.maximize

begin
  puts 'Navigating to the Handelsregister homepage...' if @verbose
  browser.goto('https://www.handelsregister.de/rp_web/welcome.xhtml')

  # Wait for the Registerbekanntmachungen section to load
  puts 'Waiting for the "Registerbekanntmachungen" section to load...'
  browser.wait_until { browser.a(title: 'Registerbekanntmachungen').exists? }

  puts 'Accessing the "Registerbekanntmachungen" section...'
  browser.as(title: 'Registerbekanntmachungen').each_with_index do |link, index|
    puts "Link ##{index + 1}: Title: #{link.title}, Href: #{link.href}, Present? #{link.present?}"

    link.click if link.present?
  end

  # browser.a(title: 'Registerbekanntmachungen').click_no_wait

  # Wait for the page to load
  puts "Waiting for the 'Registerbekanntmachungen' title to be set..."
  browser.wait_until { browser.title.include?('Registerbekanntmachungen') }

  # Wait until pop-up disappears
  puts 'Waiting for the pop-up to disappear...'
  browser.wait_until { !browser.div(text: "Ihre Anfrage wird bearbeitet").present? }

  # Input the date range
  start_date = '01.10.2024' # Format: DD.MM.YYYY
  end_date = '31.10.2024'   # Format: DD.MM.YYYY

  # start_date and end_date can be at most 8 weeks before today
  if start_date != nil && Date.parse(start_date) < Date.today - 7 * 8
    start_date = (Date.today - 7 * 8).strftime('%d.%m.%Y')
  end

  if end_date != nil && Date.parse(end_date) < Date.today - 7 * 8
    end_date = (Date.today - 7 * 8).strftime('%d.%m.%Y')
  end
  
  puts "Setting the date range from #{start_date} to #{end_date}..."
  if start_date != nil
    browser.text_field(id: 'bekanntMachungenForm:datum_von_input').set(start_date) 
    # Exit text field
    browser.text_field(id: 'bekanntMachungenForm:datum_von_input').send_keys(:escape)
  end
  if end_date != nil
    browser.text_field(id: 'bekanntMachungenForm:datum_bis_input').set(end_date)
    # Exit text field
    browser.text_field(id: 'bekanntMachungenForm:datum_bis_input').send_keys(:escape)
  end

  if start_date != nil && end_date != nil
    puts 'Submitting the search form...'
    browser.button(id: 'bekanntMachungenForm:rrbSuche').click
  end

  # Wait until pop-up disappears
  puts 'Waiting for the pop-up to disappear...'
  browser.wait_until { !browser.div(text: "Ihre Anfrage wird bearbeitet").present? }

  # It takes a bit for the announcements to be present
  sleep 5
  puts 'Retrieving the announcements...'

  # Extract data from dl elements
  dl = browser.dl(id: 'bekanntMachungenForm:datalistId_list')
  dts = dl.dts
  dds = dl.dds
  
  if dts.empty?
    puts 'No announcements found for the specified date range.'
    return
  else
    data = []
    dts.each_with_index do |dt, index|
      date = dt.text.strip
      puts "Date: #{date}"
      dd = dds[index]
      announcements = dd.as
      announcements_data = []
  
      announcements.each do |a|
        label = a.label
        text = label.text.strip
        lines = text.split("\n").map(&:strip)

        announcement = parse_announcement(lines)
        
        announcements_data << announcement
 
        # Output the extracted data
        #puts "  Type: #{type}"
        #puts "  State: #{state}"
        #puts "  Amtsgericht: #{amtsgericht}"
        #puts "  Registernummer: #{registernummer}"
        #puts "  Company Name: #{company_name}"
        #puts "  Company Seat: #{company_seat}"
        #puts "  ---"
      end
  
      data << {
        date: date,
        announcements: announcements_data
      }
    end
  
    # Now 'data' contains all the extracted information
    # You can use 'data' as needed

    # Output the unique announcement types
    puts "Unique announcement types:"
    puts data.map { |d| d[:announcements].map do |a| a[:type] end }.flatten.uniq.inspect
    puts "Registerarten:"
    puts data.map { |d| d[:announcements].map do |a| a[:registerart] end }.flatten.uniq.inspect    
    puts "States:"
    puts data.map { |d| d[:announcements].map do |a| a[:state] end }.flatten.uniq.inspect
    puts "Amtsgerichte:"
    puts data.map { |d| d[:announcements].map do |a| a[:amtsgericht] end }.flatten.uniq.inspect

  end

ensure
  puts 'Closing the browser...'
  browser.close
end
