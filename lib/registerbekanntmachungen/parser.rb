
require 'net/http'
require 'uri'
require 'nokogiri'

def parse_announcement_response(response_body)
  # Parse the XML response
  doc = Nokogiri::XML(response_body)

  # Find the CDATA section containing the announcement HTML
  cdata = doc.xpath('//update').text

  # Parse the HTML content
  html_doc = Nokogiri::HTML(cdata)

  # Extract the desired text
  # For example, get the text within specific labels or divs
  announcement_text = html_doc.css('#rrbPanel_content').text.strip

  if announcement_text.empty?
    # Try Sonderregisterbekanntmachung
    announcement_text = html_doc.css('#srbPanel_content').text.strip
  end

  # Remove leading/trailing whitespace
  announcement_text = announcement_text.split("\n").map(&:strip).join("\n")

  # Merge three or more consecutive newlines into two
  announcement_text = announcement_text.gsub(/\n{3,}/, "\n\n")

  announcement_text
end

#
# Parse the announcement details from the given text lines and onclick attribute
#
# <a id="bekanntMachungenForm:datalistId:0:j_idt116:2:j_idt117" href="#" class="ui-commandlink ui-widget"
# onclick="fireBekanntmachung2('Sat Nov 30 00:00:00 CET 2024', '95064');;PrimeFaces.ab({s:&quot;bekanntMachungenForm:datalistId:0:j_idt116:2:j_idt117&quot;,f:&quot;bekanntMachungenForm&quot;});return false;">
#   <label id="bekanntMachungenForm:datalistId:0:j_idt116:2:j_idt118" class="ui-outputlabel ui-widget"> 
#     Cancellation announcement under the Transformation Act <br> 
#     Bavaria District court Regensburg HRB 16226 <br> 
#     Bachner Holding GmbH – Mainburg
#   </label>
# </a>
#
def parse_announcement(lines, onclick)
  # Initialize variables
  type = ''
  state = ''
  amtsgericht = ''
  registernummer = ''
  company_name = ''
  company_seat = ''
  former_amtsgericht = ''
  id = ''

  # Extract ID from the onclick attribute
  # fireBekanntmachung2('Sat Nov 30 00:00:00 CET 2024', '95064');
  match = onclick.match(/fireBekanntmachung\d+\('[^']*',\s*'(?<id>\d+)'\);/)
  if match
    id = match[:id]
  else
    puts "Failed to extract ID from the onclick attribute: #{onclick}" if @verbose
    # raise "Failed to extract ID from the onclick attribute: #{onclick}"
  end

  # Extract Type from the first line
  type = lines[0]
  if type == "– gelöscht –"
    lines.shift
    type = lines[0]
  end

  # Parse the second line to extract State, Amtsgericht, and Registernummer
  line2 = lines[1]

  if type.start_with?("Sonderregisterbekanntmachung")
    match = line2.match(/^(?<state>.*?)\s+Amtsgericht\s+(?<court>.*?)$/)
    if match
      state = match[:state]
      amtsgericht = "Amtsgericht #{match[:court]}"
    else
      raise "Failed to parse the second line '#{line2}': #{lines.inspect}"
    end

    sonderegister_referenz = lines[2]
    company_name = lines[3]

    return {
      id: id,
      original_text: lines.join("\n"),
      type: type,
      state: state,
      amtsgericht: amtsgericht,
      company_name: company_name,
      sonderegister_referenz: sonderegister_referenz
    }
  end

  match = line2.match(/^(?<state>.*?)\s+Amtsgericht\s+(?<court>.*?)\s+(?<registerart>(HRA|HRB|GnR|GsR|PR|VR))\s+(?<register_number>\d+(?:\s+\w+)?)(?:\s+früher Amtsgericht\s+(?<former_court>.*))?$/)
  if match
    state = match[:state]
    amtsgericht = "Amtsgericht #{match[:court]}"
    registernummer = "#{match[:registerart]} #{match[:register_number]}"
    former_amtsgericht = match[:former_court]
    registerart = match[:registerart]
  else
    state = amtsgericht = registernummer = nil
    sonderbekanntmachung_referenz = line2
  end

  # Extract Company Name and Seat from the third line
  line3 = lines[2]
  company_parts = line3.split('–').map(&:strip)
  company_name = company_parts[0]
  company_seat = company_parts[1]

  announcement = {
    id: id,
    original_text: lines.join("\n"),
    type: type,
    state: state,
    amtsgericht: amtsgericht,
    registernummer: registernummer,
    registerart: registerart,
    company_name: company_name,
    company_seat: company_seat
  }

  # Include 'former_amtsgericht' only if it's not nil or empty
  unless former_amtsgericht.nil? || former_amtsgericht.strip.empty?
    announcement[:former_amtsgericht] = former_amtsgericht
  end

  return announcement

end

def get_detailed_announcement(datum, id, view_state, cookies)
  uri = URI('https://www.handelsregister.de/rp_web/xhtml/bekanntmachungen.xhtml')

  # Prepare the POST data
  post_data = {
    'javax.faces.partial.ajax' => 'true',
    'javax.faces.source' => 'bekanntMachungenForm:j_idt114',
    'javax.faces.partial.execute' => 'bekanntMachungenForm',
    'javax.faces.partial.render' => 'bekanntMachungenForm',
    'bekanntMachungenForm:j_idt114' => 'bekanntMachungenForm:j_idt114',
    'datum' => datum,
    'id' => id,
    'bekanntMachungenForm' => 'bekanntMachungenForm',
    'javax.faces.ViewState' => view_state
    # Include other necessary form data if required
  }

  headers = {
    'Cookie' => cookies,
    'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8',
    'Faces-Request' => 'partial/ajax',
    'User-Agent' => 'Your User Agent'
  }

  response = nil
  3.times do
    break if response
  
    # Create and send the POST request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.set_form_data(post_data)
    response = http.request(request)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    puts "Timeout error: #{e.message}"
  end

  # Parse the response
  response.body
end