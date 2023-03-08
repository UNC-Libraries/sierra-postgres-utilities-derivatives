require 'spec_helper'

module Sierra
  module Derivatives
    RSpec.describe ReshareRecord do
      let(:metadata_b) { build(:metadata_b) }
      let(:data_b) { build(:data_b) }
      let(:bib) {
        b = newrec(Sierra::Data::Bib, metadata_b, data_b)
        b.set_data(:items, [item])
        b
      }

      let(:marc) {
        MARC::Record.new_from_hash(
          {'leader' => '00000cam  2200145Ia 4500', 'fields' => [
            {'001' => '8671134'},
            {'003' => 'OCoLC'},
            {'005' => '19820807000000.0'},
            {'008' => '820807s1981    enk           000 1 eng d'},
            {'100' => {'ind1' => '1', 'ind2' => ' ', 'subfields' => [
              {'a' => 'Fassnidge, Virginia.'}
            ]}},
            {'245' => {'ind1' => '1', 'ind2' => '0', 'subfields' => [
              {'a' => 'Something else :'},
              {'b' => 'a novel /'},
              {'c' => 'Virginia Fassnidge.'}
            ]}},
            {'915' => {'ind1' => ' ', 'ind2' => ' ', 'subfields' => [
              {'9' => 'Baseline 09_2013'},
              {'9' => 'Under Authority Control'}
            ]}},
            {'919' => {'ind1' => ' ', 'ind2' => ' ', 'subfields' => [
              {'a' => 'Some 919 field'}
            ]}},
            {'935' => {'ind1' => ' ', 'ind2' => ' ', 'subfields' => [
              {'a' => 'ADH-2114'}
            ]}}
          ]}
        )
      }

      let(:trln) {
        trln = TRLNDiscoveryRecord.new(bib)
        bib.marc = marc
        trln
      }

      let(:reshare) {
        reshare = ReshareRecord.new(bib, tdetl_rec: trln)
        bib.marc = marc
        reshare
      }

      let(:metadata_i) { build(:metadata_i) }
      let(:data_i) { build(:data_i) }
      let(:item) { newrec(Sierra::Data::Item, metadata_i, data_i) }

      let(:metadata_c) { build(:metadata_c) }
      let(:data_c) { build(:data_c) }
      let(:hrec) do
        h = newrec(Sierra::Data::Holdings, metadata_c, data_c)
        h.set_data(:cards, [build(:holdings_card)])
        h.set_data(:locations, [build(:loc_ddda)])
        h.set_data(:varfields, [build(:varfield_852)])
        h
      end

      let(:metadata_o) { build(:metadata_o) }
      let(:data_o) { build(:data_o) }
      let(:order) { newrec(Sierra::Data::Order, metadata_o, data_o) }


      it 'requires tdetl_rec for initialization', :aggregate_failures do
        expect { ReshareRecord.new(bib) }.to raise_error(StandardError)
        expect { ReshareRecord.new(bib, tdetl_rec: trln) }.not_to raise_error(
          StandardError
        )
      end

      describe 'get_alt_marc' do
        let(:tdetl_marc) { trln.get_alt_marc(marc) }
        let(:alt_marc) { reshare.get_alt_marc(tdetl_marc) }

        describe 'deviations from TRLN Discovery Record' do
          it 'writes bnum_trunc to 001' do
            expect(alt_marc['001'].value).to eq(bib.bnum_trunc)
          end

          it 'writes an 001 oclcnumber to the 035' do
            expect(alt_marc['035'].value).to eq('(OCoLC)8671134')
          end

          it 'writes "NcU" to 003' do
            expect(alt_marc['003'].value).to eq('NcU')
          end

          it 'writes original 001 to 908$a' do
            expect(alt_marc.fields('908').first['a']).to eq('8671134')
          end

          it 'writes original 003 to 908$b' do
            expect(alt_marc.fields('908').first['b']).to eq('OCoLC')
          end
        end

        #
        # RETAINS TRLN DISCOVERY RECORD MODIFICATIONS
        #

        it 'retains TRLNDiscovery 999 fields' do
          expect(alt_marc.fields('999').count).to be > 3
        end

        it 'retains 919 field' do
          expect(alt_marc.fields('919').count).to eq(1)
        end

        it 'drops original 9xx fields except 919' do
          expect(alt_marc.fields('915').count).to eq(0)
        end

        it 'adds 907 using bnum trunc' do
          expect(alt_marc.fields('907').first).to eq(
            MARC::DataField.new('907', ' ', ' ', ['a', 'b2661010'])
          )
        end

        it 'does not write m999s for suppressed items' do
          item.is_suppressed = true
          m = reshare.get_alt_marc(trln.get_alt_marc(marc))
          expect(m.fields.select { |f|
            f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '1'
          }.empty?).to be true
        end

        it 'does not write m999s for suppressed holdings' do
          hrec.is_suppressed = true
          bib.set_data(:holdings, [hrec])

          m = reshare.get_alt_marc(trln.get_alt_marc(marc))
          expect(m.fields.select { |f|
            f.tag == '999' && f.indicator1 == '9' &&
            (f.indicator2 == '2' || f.indicator2 == '3')
          }.empty?).to be true
        end

        it 'does not write m999s for suppressed orders' do
          order.is_suppressed = true
          # remove any attached items (which would also prevent an order m999)
          bib.set_data(:items, [])
          bib.set_data(:orders, [order])


          m = reshare.get_alt_marc(trln.get_alt_marc(marc))
          expect(m.fields.select { |f|
            f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '4'
          }.empty?).to be true
        end
      end

      describe 'xml' do
        let(:marc) do
          MARC::Reader.new('spec/data/b1841152a.mrc').to_a.first
        end

        it 'returns altmarc as xml' do
          trln.altmarc(marc)
          expect(reshare.xml).to eq(File.read('spec/data/b1841152a.reshare.xml'))
        end
      end
    end
  end
end
