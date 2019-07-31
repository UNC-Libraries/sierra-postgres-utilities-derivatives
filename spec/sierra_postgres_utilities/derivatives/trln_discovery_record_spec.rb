require 'spec_helper'

module Sierra
  module Derivatives
    RSpec.describe TRLNDiscoveryRecord do
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

      let(:metadata_i) { build(:metadata_i) }
      let(:data_i) { build(:data_i) }
      let(:item) { newrec(Sierra::Data::Item, metadata_i, data_i) }

      let(:metadata_c) { build(:metadata_c) }
      let(:data_c) { build(:data_c) }
      let(:hrec) { newrec(Sierra::Data::Holdings, metadata_c, data_c) }

      let(:metadata_o) { build(:metadata_o) }
      let(:data_o) { build(:data_o) }
      let(:order) { newrec(Sierra::Data::Order, metadata_o, data_o) }


      describe 'get_alt_marc' do
        let(:alt_marc) { trln.get_alt_marc(marc) }

        it 'retains 919 field' do
          expect(alt_marc.fields('919').count).to eq(1)
        end

        it 'drops 9xx fields except 919' do
          expect(alt_marc.fields('915').count).to eq(0)
        end

        it 'adds 907 using bnum trunc' do
          expect(alt_marc.fields('907').first).to eq(
            MARC::DataField.new('907', ' ', ' ', ['a', 'b2661010'])
          )
        end

        it 'does not write m999s for suppressed items' do
          item.is_suppressed = true
          m = trln.get_alt_marc(marc)
          expect(m.fields.select { |f|
            f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '1'
          }.empty?).to be true
        end

        it 'does not write m999s for suppressed holdings' do
          hrec.is_suppressed = true
          bib.set_data(:holdings, [hrec])

          m = trln.get_alt_marc(marc)
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


          m = trln.get_alt_marc(marc)
          expect(m.fields.select { |f|
              f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '4'
          }.empty?).to be true

        end
      end

      describe 'bib_m999' do
        let(:bib_m999) { trln.bib_m999 }

        it 'sets $a to cat date' do
          expect(bib_m999['a']).to eq('2005-07-13 00:00:00-04')
        end

        it 'sets $c to created date' do
          expect(bib_m999['c']).to eq('2004-11-04 12:55:00-05')
        end

        it 'sets $u to updated date' do
          expect(bib_m999['u']).to eq('2018-10-11 07:30:34-04')
        end

        it 'sets $m to material type' do
          expect(bib_m999['m']).to eq ('a')
        end
      end

      describe 'item_m999' do
        let(:item_m999) {
          item.set_data(
            :varfields,
            [build(:varfield_i_b), build(:varfield_i_c), build(:varfield_i_f),
            build(:varfield_i_j), build(:varfield_i_m), build(:varfield_i_v),
            build(:varfield_i_x), build(:varfield_i_z), build(:varfield_i_b)]
          )
          trln.item_m999(item)
        }

        it 'field is 99991' do
          expect(
            "#{item_m999.tag}#{item_m999.indicator1}#{item_m999.indicator2}"
          ).to eq('99991')
        end

        it 'sets $i to inum_trunc' do
          expect(
            item_m999['i']).to eq('i2661010')
        end

        it 'sets $l (ell) to location code' do
          expect(
            item_m999['l']).to eq('trln')
        end

        it 'sets $s to status code' do
          expect(item_m999['s']).to eq('-')
        end

        it 'sets $t to itype code' do
          expect(item_m999['t']).to eq('0')
        end

        it 'sets $c to copy num as string' do
          expect(item_m999['c']).to eq('1')
        end

        it 'sets $o to checkout total' do
          expect(item_m999['o']).to eq('19')
        end

        context 'when item is checked out' do
          it 'sets $d to due date (YYYMMDD)' do
            item.set_data(:checkout, build(:checkout))
            item_m999 = trln.item_m999(item)
            expect(item_m999['d']).to eq('2019-01-02 00:00:00-05')
          end
        end

        context 'when item is not checked out' do
          it 'skips writing $d' do
            item.set_data(:checkout, nil)
            item_m999 = trln.item_m999(item)
            expect(item_m999['d']).to be_nil
          end
        end

        it 'sets $b to barcode' do
          expect(item_m999['b']).to eq('00050035567')
        end

        it 'sets $p to call number tag' do
          expect(item_m999['p']).to eq('090##')
        end

        it 'uses # for blank indicators in call number tag' do
          expect(item_m999['p']).to eq('090##')
        end

        it 'sets $q to call number content' do
          expect(item_m999['q']).to eq('|aTR655|b.H66 2015')
        end

        it 'sets $v to volume' do
          expect(item_m999['v']).to eq('Suppl.')
        end

        # note: we write public note (varfield type == z) to subfield n
        it 'sets $n to public note' do
          expect(item_m999['n']).to eq('Second nature ; Reflections')
        end

        # todo allows repeatable varfields
        it 'writes multiple subfields of a type when multiple varfields exist' do
          expect(item_m999.subfields.select { |sf| sf.code == 'b' }.length ).
            to eq(2)
        end
      end

      describe 'order_m999' do
        let(:order_m999) { trln.order_m999(order) }

        it 'field is 99991' do
          expect(
            "#{order_m999.tag}#{order_m999.indicator1}#{order_m999.indicator2}"
          ).to eq('99994')
        end

        it 'sets $a to onum trunc' do
          expect(
            order_m999['a']).to eq('o1732046')
        end

        it 'sets $b to ocode3' do
          expect(order_m999['b']).to eq('-')
        end

        it 'sets $c to number copies as string' do
          expect(order_m999['c']).to eq('1')
        end

        it 'sets $d to received date (YYY-MM-DD)' do
          expect(order_m999['d']).to eq('2015-07-02')
        end

        it 'sets $e to cat date (YYYYMMDD)' do
          expect(order_m999['e']).to eq('2015-07-10')
        end

        it 'sets $f to location' do
          expect(order_m999['f']).to eq('ua')
        end

        it 'sets $g to status code' do
          expect(order_m999['g']).to eq('a')
        end

        context 'when items are present' do
          it 'order m999 is not written' do
            bib.set_data(:orders, [order])
            bib.set_data(:items, [item])
            m = trln.get_alt_marc(marc)
            expect(m.fields.select { |f|
              f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '4'
            }.empty?).to be true
          end
        end

        context 'when no items are present' do
          it 'order m999 is written for orders' do
            bib.set_data(:orders, [order])
            bib.set_data(:items, [])
            m = trln.get_alt_marc(marc)
            expect(m.fields.select { |f|
              f.tag == '999' && f.indicator1 == '9' && f.indicator2 == '4'
            }.empty?).to be false
          end
        end

      end

      describe 'hrec_m999s' do
        let(:hrec_m999) { trln.hrec_m999s(hrec).first }

        it 'returns array' do
          expect(trln.hrec_m999s(hrec).is_a?(Array)).to be true
        end

        it 'sets $a to cnum trunc' do
          expect(hrec_m999['a']).to eq(hrec.rnum_trunc)
        end

        it 'sets $b to location' do
          expect(hrec_m999['b']).to eq('nohr')
        end

        it 'sets $c to hcard_ct as string' do
          expect(hrec_m999['c']).to eq('1')
        end
      end

      describe 'hf_m999s' do
        let(:hf_m999_001) { trln.hf_m999s(hrec).first }

        it 'sets $0 to cnum_trunc' do
          expect(hf_m999_001['0']).to eq(hrec.rnum_trunc)
        end

        it 'sets $2 to marc_tag' do
          expect(hf_m999_001['2']).to eq('852')
        end

        it 'sets $3 to iii_tag (field group tag)' do
          expect(hf_m999_001['3']).to eq('c')
        end

        it 'writes each subfield to correspoding m999 subfield' do
          expect(hf_m999_001).to eq(
            MARC::DataField.new(
              '999', '9', '3', ['0', 'c10149688'], ['2', '852'], ['3', 'c'],
              ['h', 'QV 704'], ['i', 'R388'], ['z', 'Earlier editions in stacks']
            )
          )
        end
      end

      describe 'xml' do
        let(:marc) do
          MARC::Reader.new('spec/data/b1841152a.mrc').to_a.first
        end

        it 'returns altmarc as xml' do
          trln.altmarc(marc)
          expect(trln.xml).to eq(File.read('spec/data/b1841152a.tdetl.xml'))
        end
      end
    end
  end
end
