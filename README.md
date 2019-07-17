# SierraPostgresUtilities::Derivatives

[sierra_postgres_utilities gem](https://github.com/UNC-Libraries/sierra-postgres-utilities) addon with logic to transform/supplement Sierra bib into bib records for ingest into other systems (e.g. HathiTrust, GoogleBooks, TRLN Discovery), and to assist with MARC/record quality checks and exporting the derivative records as MARC/MARC-XML.

For example:

- HathiTrust - we combine Sierra bib MARC with Internet Archive (the digitization source) item data into a record that represents a bib-item pair
  - IA item data is written into a 955
  - various other MARC changes (e.g. remove other 9XX fields, set 003 to 'NcU', etc.)
  - check that the MARC/record meets HathiTrust specifications (e.g. has exactly one 245 field, contains a 300, etc.)
- TRLN Discovery - we do similar kinds of things but are largely taking Sierra bib MARC and supplementing it with MARC fields containing data from attached item/holdings/order data in Sierra (so resulting in one TRLN Discovery record per bib, where we are getting one HathiTrust record per bib-IA_item pair).

## Installation

```bash
bundle install
bundle exec rake install
```

## Usage

```ruby
require 'sierra_postgres_utilities/derivatives'

bib = Sierra::Data::Bib.first
trln = bib.trln_discovery_record
trln.acceptable_marc?
  #=> true

# Print the transformed marc-xml string
puts trln.xml
  #=> <record>
  #     <leader>00546cam  2200193Ii 4500</leader>
  #     <controlfield tag='001'>2141793</controlfield>
  #     ...

# Write transformed marc-xml for one record to a file
trln.write_xml(outfile: 'one_record.xml')

# Or write xml for many records to a file
File.open('many_records.xml') do |ofile|
  ofile << MARC::XMLHelper::HEADER # document header
  records.each { |rec| rec.write_xml(outfile: ofile) }
  ofile << MARC::XMLHelper::FOOTER # document footer
end
```
