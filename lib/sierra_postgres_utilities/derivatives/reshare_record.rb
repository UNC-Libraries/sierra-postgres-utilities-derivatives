module Sierra
  module Derivatives
    # A derivative record for TRLN Reshare.
    # TRLNDiscoveryRecords are Reshare-compliant, but they are not compliant
    # with POD. A ReshareRecord derives a POD-compliant record from using
    # a TRLNDiscoveryRecord as the base.
    #
    # POD requires a unique / ILS system number in the 001
    # (https://github.com/pod4lib/aggregator/wiki/Data-requirements).
    #
    # There are several other modifications that follow or are related to that,
    # though they may not be POD requirements:
    #  - use NcU as the 003 to clarify the meaning of the 001
    #  - if the 001 is an OCLC number, copy it to an 035 (which is a standard
    #    place to look for it) if there is no 035 oclc number
    #  - in every case, write the original 001 and 003 to a local 9xx field to
    #    retain the data (e.g. so we can use existing logic to extract sersol
    #    and oclc identifiers directly from the original 001/003)
    class ReshareRecord < DerivativeRecord
      def initialize(bib_rec, tdetl_rec: nil)
        unless tdetl_rec
          raise StandardError, 'Requires tdetl_rec for initialization'
        end

        super(bib_rec)

        @tdetl_rec = tdetl_rec
      end

      def altmarc
        # We use TRLN Discovery / tdetl marc as the "original"/base marc rather
        # than sierra marc
        @altmarc ||= get_alt_marc(@tdetl_rec.modifiable_altmarc)
      end

      def get_alt_marc(base_marc)
        altmarc = base_marc

        # We need to check for the OCLC# here before replacing the 001/003 since
        # the check depends on the 001/003 and, unlike other derivative records,
        # we are modifying the base_marc
        if altmarc.m035_lacks_oclcnum?
          altmarc.append(MARC::DataField.new('035', ' ', ' ',
                                             ['a', "(OCoLC)#{base_marc.oclcnum}"]))
        end

        # Copy the 001 and 003 to 908$a and $b
        orig001 = altmarc.fields('001').first&.value
        orig003 = altmarc.fields('003').first&.value
        m908 = MARC::DataField.new('908', ' ', ' ')
        m908.append(MARC::Subfield.new('a', orig001 || ''))
        m908.append(MARC::Subfield.new('b', orig003)) if orig003
        altmarc.append(m908)

        # delete things
        # we've already deleted undesirable 9xx fields  (and also added
        # desirable 9xx fields) in the base marc
        altmarc.fields.delete_if { |f| f.tag =~ /001|003/ }

        # add things
        altmarc.append(
          MARC::ControlField.new('001', @sierra.bnum_trunc) # chop trailing 'a'
        )
        altmarc.append(MARC::ControlField.new('003', 'NcU'))

        altmarc.sort
      end
    end
  end
end
