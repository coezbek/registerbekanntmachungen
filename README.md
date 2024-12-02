# Registerbekanntmachungen

[![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Daily Scrape CI](https://github.com/coezbek/registerbekanntmachungen/actions/workflows/daily_scrape.yml/badge.svg)](https://github.com/coezbek/registerbekanntmachungen/actions/workflows/daily_scrape.yml) 

> [!IMPORTANT]
> This project is not affiliated with handelsregister.de. It is not an official source of truth. This data may be incomplete or outdated. The tool might mangle or miss entries. Use at your own risk.

This Ruby Gem provides a simple scraper for the "Registerbekanntmachungen" (notices of changes in corporate directory) announced by the [German Handelsregister on their page](https://www.handelsregister.de/rp_web/xhtml/bekanntmachungen.xhtml).

These Registerbekanntmachungen only contain officially mandated publications such as those mandated by [Handelsgesetzbuch HGB §10](https://www.gesetze-im-internet.de/hgb/__10.html). It does not contain all changes in the corporate directory, only those that are required to be published (in particular declarations to delete i.e. 'Löschungen' and 'Umwandlungen'). 

Since the data is static once published, small (only <= 200 announcements per day) and only the last 8 weeks are available at handelregister.de, this repository also hosts [daily snapshots](./db) of the data sorted by month in the `db` directory. In most cases, running the scraper yourself it thus unnecessary. 

> [!IMPORTANT]
> Handelsregister.de's Terms & Conditions mandates that users should not perform more than 60 'searches' or 'retrievals' per hour. Both terms are not defined it is thus not clear what constitutes either. It is unclear on what legal basis Handelsregister.de believes they have a right to impose such limits, since HGB makes no restrictions on an individuals ability to access these publically available information for the purpose of information. Since information on the handelsregister can be updated on a daily basis and there are no means of bulk 'retrievals', it could be argued that individuals must be able to perform as many accesses as are necessary to obtain all company information once per day. For the Registerbekanntmachungen this means on the order of 200 accesses per day per user.
> Handelsregister.de also claims that material is copyrighted unless otherwise noted. Since all material which is available for access is provided by the register courts to handelsregister.de to ensure retrieval, it is unclear to what material they really claim copyright and why.

## Related projects

https://github.com/bundesAPI/handelsregister provides a Python CLI for accessing the Handelsregister itself. 

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

All available option:

```bash
$ bundle exec lib/registerbekanntmachungen.rb --help
Usage: registerbekanntmachungen [options]
    -v, --verbose                    Enable verbose/debug output
    -r, --reload                     Reload data and skip cache
        --no-save                    Do not save any data just print to stdout
        --start-date DATE            Start date in format DD.MM.YYYY or YYYY-MM-DD
        --end-date DATE              End date in format DD.MM.YYYY or YYYY-MM-DD
    -o, --oldest                     Download oldest available data not already saved
    -y, --yesterday                  Download yesterday's data    
    -a, --all                        Download all data from the last 8 weeks
    -m, --merge                      Merge new data with existing data
        --no-headless                Don't run browser in headless mode
    -h, --help                       Displays Help
```

*Note*: 
- Data usually isn't published on weekends, but sometimes it is.
- If you run this tool in the morning you might want to use it again in the evening/night, because new announcements are published throughout the day.
- Data is only available for the last 8 weeks (7*8 = 56 days) on handelsregister.de. Use '-o' to obtain the data from the oldest available date.
- There might be multiple announcements for the same company and announcement type on the same day. The `detail` text might differ.

## Data SchemaAnnouncement types

The data contains the following fields for each announcement:

- `date`: The date the announcement was published as an ISO 8601 string, e.g. "2024-10-01".
- `id`: An additional identifier to distinguish multiple announcements for the same company on the same day of the same type. It is provided by Handelsregister.de and it might not really be unique. As this an implementation detail of the website, there is no guarantee that this is unique and or continuous. 
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
