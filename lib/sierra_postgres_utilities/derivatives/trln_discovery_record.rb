module Sierra
  module Derivatives
    class TRLNDiscoveryRecord < DerivativeRecord
      def altmarc(orig_marc = smarc(quick: true))
        @altmarc ||= get_alt_marc(orig_marc)
      end

      def get_alt_marc(orig_marc)
        # If we wanted to keep @smarc unchanged, we'd need to make a deep copy.
        # We have no further use for @smarc with TRLNDiscovery, so to be quick
        # and lazy, use @smarc as the base for altmarc and then dereference
        # @sierra.marc, and thereby @smarc, so we cannot access changed copies later.
        #altmarc = smarc.dup
        altmarc = MARC::Record.new_from_marc(orig_marc.to_marc)
        #@sierra.marc = nil
        # Normally we make a deep copy something like this:
        #   altmarc = MARC::Record.new_from_marc(@smarc.to_marc)

        # keep 919, drop other 9xx fields
        altmarc.fields.delete_if { |f| f.tag =~ /^9(?!19)/ }

        # Insert 907 with bnum_trunc in $a. Not all records export with a 907.
        altmarc.append(MARC::DataField.new(
          '907', ' ', ' ', ['a', @sierra.bnum_trunc]
        ))

        # Get unsuppressed items.
        items = @sierra.items.reject { |i| i.suppressed? }
        items.each { |item| altmarc.append(item_m999(item)) }

        # Get unsuppressed holdings.
        holdings = @sierra.holdings.reject { |h| h.suppressed? }
        holdings.each do |holding|
          # A holdings record can have multiple location entries, so for those
          # cases we're doing:
          #   store hrec1's hf_m999s
          #   write hrec1_loc1 m999
          #   write hrec1's hf_m999s due to loc1
          #   write hrec1_loc2 m999
          #   write hrec1's hf_m999s due to loc2
          #   write hrec2_loc1 m999
          #   write hrec2's hf_m999s
          #   ...
          hf_m999s = hf_m999s(holding)
          hrec_m999s(holding).each do |hrec_m999|
            altmarc.append(hrec_m999)
            hf_m999s.each { |hf_m999| altmarc.append(hf_m999) }
          end
        end

        # Get unsuppressed orders if no items.
        unless items.any?
          orders = @sierra.orders.reject { |o| o.suppressed? }
          orders.each { |order| altmarc.append(order_m999(order)) }
        end

        # Add bib's catdate/created_date/updated_date
        altmarc.append(bib_m999)

        altmarc
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

        if item.due_date
          m999.append(MARC::Subfield.new('d', item.due_date.strftime('%Y%m%d')))
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
