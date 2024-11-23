# Registerbekanntmachungen

[![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Daily Scrape CI](https://github.com/coezbek/registerbekanntmachungen/actions/workflows/daily_scrape.yml/badge.svg)](https://github.com/coezbek/registerbekanntmachungen/actions/workflows/daily_scrape.yml) 

> [!IMPORTANT]
> This project is not affiliated with handelsregister.de. It is not an official source of truth. This data may be incomplete or outdated. The tool might mangle or miss entries. Use at your own risk.

This Ruby Gem provides a simple scraper for the "Registerbekanntmachungen" (notices of changes in corporate directory) announced by the German Handelsregister.

These Registerbekanntmachungen only contain officially mandated publications such as those mandated by [Handelsgesetzbuch HGB §10](https://www.gesetze-im-internet.de/hgb/__10.html). It does not contain all changes in the corporate directory, only those that are required to be published (in particular declarations to delete i.e. 'Löschungen' and 'Umwandlungen'). 

Since the data is static once published, small (only <= 200 announcements per day) and only the last 8 weeks are available at handelregister.de, this repository also hosts daily snapshots of the data in the `db` directory.

## Usage / Installation

To use the gem, best clone this repository:

```bash
git clone https://github.com/coezbek/registerbekanntmachungen
cd registerbekanntmachungen
bundle
```

Run the scraper in verbose mode for announcements published today:

```bash
bundle exec lib/registerbekanntmachungen.rb -v
```

*Note*: 
- No data is published on weekends and public holidays.
- If you run this tool in the morning you might want to use it again in the evening, because new announcements are published throughout the day.

## Data SchemaAnnouncement types

The data contains the following fields for each announcement:

- `date`: The date the announcement was published as an ISO 8601 string, e.g. "2024-10-01".
- `original_text`: The original link text of the announcement.
- `court`: The court where the announcement was published, e.g. "Amtsgericht Berlin (Charlottenburg)".
- `registernumber`: The register number of the company including the prefix (e.g. "HRB 12345" or "VR 123").
- `registerart`: The type of the register, e.g. "HRA" for Handelsregister A or "VR" for Vereinsregister.
- `company_name`: The name of the company, can include special characters.
- `type`: The type of the announcement. Possible values I have observed so far:
  - Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register
  - Löschungsankündigung
  - Sonstige Registerbekanntmachung
  - Registerbekanntmachung nach dem Umwandlungsgesetz
  - Einreichung neuer Dokumente
- `state`: The Federal State of Germany where the company is registered.
- `company_seat`: The city where the company is registered.
- `former_court`: In case the company registration was moved from another court, the name of the former court.
- `details`: The text detail message shown on the handelsregister.de website.

If an announcement is of type "Sonderregisterbekanntmachung OHNE Bezug zum elektr. Register", the available fields are different:

- `date`, `state`, `court`, `company_name`, `type`, `details`, `original_text` are equally available
- Instead of `registernumber` there is a `sonderegister_referenz`, which might be a registernumber but could be something else.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/coezbek/registerbekanntmachungen.
