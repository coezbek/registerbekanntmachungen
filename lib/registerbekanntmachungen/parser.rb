
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

def parse_announcement(lines)
  # Initialize variables
  type = ''
  state = ''
  amtsgericht = ''
  registernummer = ''
  company_name = ''
  company_seat = ''
  former_amtsgericht = ''

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

  # Create and send the POST request
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, headers)
  request.set_form_data(post_data)
  response = http.request(request)

  # Parse the response
  response.body
end