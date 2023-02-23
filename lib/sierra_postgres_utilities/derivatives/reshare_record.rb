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



        return altmarc.sort
      end

      # create  m999 for given item rec
      def item_m999(item)
        m999 = MARC::DataField.new('999', '9', '1')
        m999.append(MARC::Subfield.new('i', item.inum_trunc))
        m999.append(MARC::Subfield.new('l', item.location_code))
        m999.append(MARC::Subfield.new('s', item.status_code))
        m999.append(MARC::Subfield.new('t', item.itype_code))
        m999.append(MARC::Subfield.new('c', item.copy_num.to_s))
        m999.append(MARC::Subfield.new('o', item.checkout_total.to_s))
        m999.append(MARC::Subfield.new('h', item.holds.length.to_s))

        if item.due_date
          m999.append(MARC::Subfield.new('d', item.due_date.strftime('%F %T%:::z')))
        end

        item.barcodes.each do |barcode|
          m999.append(MARC::Subfield.new('b', barcode))
        end
        item.callnos(value_only: false).each do |f|
          # write [marc_tag][ind1][ind2] with indicator blanks => '#'
          if f[:marc_tag]
            tag = f[:marc_tag]
            ind1 = f[:marc_ind1].tr(' ', '#')
            ind2 = f[:marc_ind2].tr(' ', '#')
            m999.append(MARC::Subfield.new('p', "#{tag}#{ind1}#{ind2}"))
          end
          m999.append(MARC::Subfield.new('q', f[:field_content]))
        end
        item.volumes.each do |volume|
          m999.append(MARC::Subfield.new('v', volume))
        end
        # this writes public notes (tag==z) to subfield n
        item.public_notes.each do |public_note|
          m999.append(MARC::Subfield.new('n', public_note))
        end
        m999
      end

      # create holding rec m999s for given holdings rec
      # each of a holdings rec's holdings_locations will be represented by
      # a marc 99992 field
      def hrec_m999s(holding)
        m999s = []
        hcard_ct = holding.card_count
        holding.locations.each do |loc|
          m999 = MARC::DataField.new('999', '9', '2')
          m999.append(MARC::Subfield.new('a', holding.rnum_trunc))
          m999.append(MARC::Subfield.new('b', loc.code))
          m999.append(MARC::Subfield.new('c', hcard_ct.to_s))
          m999s << m999
        end
        m999s
      end

      # create holding field m999s for given holdings rec
      # each of select 85x/86x fields will be represented by a
      # marc 99993 field.
      # each non-[0-4] subfield in the original is also present in the m999
      def hf_m999s(holding)
        m999s = []
        fields = holding.varfields.select { |f|
          f.marc_tag =~ /^85[2-5]/ ||
          (f.marc_tag =~ /^86[3-8]/ && f.varfield_type_code == 'h')
        }
        fields.each do |field|
          m999 = MARC::DataField.new('999', '9', '3')
          m999.append(MARC::Subfield.new('0', holding.rnum_trunc))
          m999.append(MARC::Subfield.new('2', field.marc_tag))
          m999.append(MARC::Subfield.new('3', field.varfield_type_code))
          Sierra::Data::Varfield.subfield_arry(field.field_content).
                  reject { |sf| sf[0].match(/[0-4]/) }.
                  each { |sf| m999.append(MARC::Subfield.new(sf[0], sf[1])) }
          m999s << m999
        end
        m999s
      end

      # create m999 for given order rec
      def order_m999(order)
        m999 = MARC::DataField.new('999', '9', '4')
        m999.append(MARC::Subfield.new('a', order.rnum_trunc))
        m999.append(MARC::Subfield.new('b', order.ocode3))
        m999.append(MARC::Subfield.new('c', order.number_copies.first.to_s))
        m999.append(MARC::Subfield.new('d',
                                        order.received_date&.strftime('%Y-%m-%d')))
        m999.append(MARC::Subfield.new('e',
                                        order.cat_date&.strftime('%Y-%m-%d')))
        m999.append(MARC::Subfield.new('f', order.location.first))
        m999.append(MARC::Subfield.new('g', order.status_code))
        m999
      end

      def bib_m999
        m999 = MARC::DataField.new('999', '0', '0')
        m999.append(MARC::Subfield.new(
          'a', @sierra.cat_date&.strftime('%F %T%:::z')
        ))
        m999.append(MARC::Subfield.new(
          'c', @sierra.creation_date_gmt&.strftime('%F %T%:::z')
        ))
        m999.append(MARC::Subfield.new(
          'u', @sierra.record_last_updated_gmt&.strftime('%F %T%:::z')
        ))
        m999.append(MARC::Subfield.new(
          'm', @sierra.mat_type
        ))
        m999
      end
    end
  end
end
