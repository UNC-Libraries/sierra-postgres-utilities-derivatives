require 'sierra_postgres_utilities'

module Sierra
  # Logic to transform/supplement Sierra bib into bib records for other
  # systems (e.g. HathiTrust, GoogleBooks, TRLN Discovery).
  module Derivatives
    autoload :VERSION, 'sierra_postgres_utilities/derivatives/version'
    autoload :DerivativeRecord, 'sierra_postgres_utilities/derivatives/derivative_record'

    autoload :GoogleBooksRecord, 'sierra_postgres_utilities/derivatives/google_books_record'
    autoload :HathitrustRecord, 'sierra_postgres_utilities/derivatives/hathitrust_record'
    autoload :ReshareRecord, 'sierra_postgres_utilities/derivatives/reshare_record'
    autoload :TRLNDiscoveryRecord, 'sierra_postgres_utilities/derivatives/trln_discovery_record'

    require_relative 'data/records/bib'
  end
end
