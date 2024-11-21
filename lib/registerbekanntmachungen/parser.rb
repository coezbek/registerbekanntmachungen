
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