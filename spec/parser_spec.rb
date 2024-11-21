# spec/parser_spec.rb

require 'rspec'
require_relative '../lib/registerbekanntmachungen'

RSpec.describe 'Announcement Parser' do
  it 'parses entries with "früher Amtsgericht" correctly' do
    lines = [
      "Löschungsankündigung",
      "Niedersachsen Amtsgericht Braunschweig HRB 100634 früher Amtsgericht Wolfsburg",
      "AGENTUR ASMEDIC Vermittlung und Vertrieb medizinischer und zahnmedizinischer Ausstattungen GmbH – Helmstedt"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Löschungsankündigung")
    expect(result[:state]).to eq("Niedersachsen")
    expect(result[:amtsgericht]).to eq("Amtsgericht Braunschweig")
    expect(result[:registernummer]).to eq("HRB 100634")
    expect(result[:former_amtsgericht]).to eq("Wolfsburg")
    expect(result[:company_name]).to eq("AGENTUR ASMEDIC Vermittlung und Vertrieb medizinischer und zahnmedizinischer Ausstattungen GmbH")
    expect(result[:company_seat]).to eq("Helmstedt")
  end

  it 'parses entries where line2 is an announcement type' do
    lines = [
      "– gelöscht –",
      "Löschungsankündigung",
      "Hessen Amtsgericht Offenbach am Main HRB 42719",
      "Klassische Immobilien Deutschland Beteiligungs GmbH – Neu-Isenburg"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Löschungsankündigung")
    expect(result[:state]).to eq("Hessen")
    expect(result[:amtsgericht]).to eq("Amtsgericht Offenbach am Main")
    expect(result[:registernummer]).to eq("HRB 42719")
    expect(result[:company_name]).to eq("Klassische Immobilien Deutschland Beteiligungs GmbH")
    expect(result[:company_seat]).to eq("Neu-Isenburg")
  end

  it 'parses entries without registration numbers' do
    lines = [
      "Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register",
      "Sachsen-Anhalt Amtsgericht Stendal",
      "65 AR 99/21",
      "Stadtgruppe der Kleingärtner im Reichsbund der Kleingärtner und Kleinsiedler Deutschlands e.V."
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register")
    expect(result[:state]).to eq("Sachsen-Anhalt")
    expect(result[:amtsgericht]).to eq("Amtsgericht Stendal")
    expect(result[:sonderegister_referenz]).to eq("65 AR 99/21")
    expect(result[:company_name]).to eq("Stadtgruppe der Kleingärtner im Reichsbund der Kleingärtner und Kleinsiedler Deutschlands e.V.")
  end

  it 'parses entries with missing registration details' do
    lines = [
      "Einreichung neuer Dokumente",
      "Niedersachsen Amtsgericht Lüneburg HRB 120469 früher Amtsgericht Dannenberg (Elbe)",
      "Uelzener Allgemeine Versicherungs-Gesellschaft a.G. – Uelzen"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Einreichung neuer Dokumente")
    expect(result[:state]).to eq("Niedersachsen")
    expect(result[:amtsgericht]).to eq("Amtsgericht Lüneburg")
    expect(result[:registernummer]).to eq("HRB 120469")
    expect(result[:former_amtsgericht]).to eq("Dannenberg (Elbe)")
    expect(result[:company_name]).to eq("Uelzener Allgemeine Versicherungs-Gesellschaft a.G.")
    expect(result[:company_seat]).to eq("Uelzen")
  end

  it 'parses entries with special characters in company names' do
    lines = [
      "Registerbekanntmachung nach dem Umwandlungsgesetz",
      "Nordrhein-Westfalen Amtsgericht Arnsberg VR 40327 früher Amtsgericht Menden",
      "DJK (Deutsche Jugendkraft) Saxonia Lendringsen eingetragener Verein – Menden"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Registerbekanntmachung nach dem Umwandlungsgesetz")
    expect(result[:state]).to eq("Nordrhein-Westfalen")
    expect(result[:amtsgericht]).to eq("Amtsgericht Arnsberg")
    expect(result[:registernummer]).to eq("VR 40327")
    expect(result[:former_amtsgericht]).to eq("Menden")
    expect(result[:company_name]).to eq("DJK (Deutsche Jugendkraft) Saxonia Lendringsen eingetragener Verein")
    expect(result[:company_seat]).to eq("Menden")
  end

  it 'parses entries with alternative formats' do
    lines = [
      "Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register",
      "Brandenburg Amtsgericht Neuruppin",
      "HRB 745 NP",
      "Hennigsdorfer Wohnungsbaugesellschaft mbH"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register")
    expect(result[:state]).to eq("Brandenburg")
    expect(result[:amtsgericht]).to eq("Amtsgericht Neuruppin")
    expect(result[:sonderegister_referenz]).to eq("HRB 745 NP")
    expect(result[:company_name]).to eq("Hennigsdorfer Wohnungsbaugesellschaft mbH")
  end

  it 'parses entries with only company name in line2' do
    lines = [
      "Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register",
      "Berlin Amtsgericht Berlin (Charlottenburg)",
      "HRB 17289 B (gelöscht 1996)",
      "E.V.C. Immobilien GMBH"
    ]
    result = parse_announcement(lines)
    expect(result[:type]).to eq("Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register")
    expect(result[:state]).to eq("Berlin")
    expect(result[:amtsgericht]).to eq("Amtsgericht Berlin (Charlottenburg)")
    expect(result[:sonderegister_referenz]).to eq("HRB 17289 B (gelöscht 1996)")
    expect(result[:company_name]).to eq("E.V.C. Immobilien GMBH")
  end
end