require 'spec_helper'

module Sierra
  module Derivatives
    RSpec.describe GoogleBooksRecord do
      let(:metadata_b) { build(:metadata_b) }
      let(:data_b) { build(:data_b) }
      let(:bib) do
        b = newrec(Sierra::Data::Bib, metadata_b, data_b)
        b.set_data(:items, [item])
        b
      end

      let(:metadata_i) { build(:metadata_i) }
      let(:data_i) { build(:data_i) }
      let(:item) { newrec(Sierra::Data::Item, metadata_i, data_i) }

      describe 'my955' do
        let(:m955) do
          GoogleBooksRecord.new(
            bib,
            item.set_data(
              :varfields,
              [build(:varfield_i_b), build(:varfield_i_c), build(:varfield_i_f),
               build(:varfield_i_j), build(:varfield_i_m), build(:varfield_i_v),
               build(:varfield_i_x), build(:varfield_i_z), build(:varfield_i_b)]
            )
          ).my955
        end

        it 'sets $b as barcode' do
          sftag = 'b'
          expect(m955[sftag]).to eq('00050035567')
        end

        it 'sets $v as volume' do
          sftag = 'v'
          expect(m955[sftag]).to eq('Suppl.')
        end

        it 'sets $a as callnum (without subfield delimiters)' do
          sftag = 'a'
          expect(m955[sftag]).to eq('TR655.H66 2015')
        end

        it 'sets $z as public_notes' do
          sftag = 'z'
          expect(m955[sftag]).to eq('Second nature ; Reflections')
        end

        it 'sets $i as inum_trunc' do
          sftag = 'i'
          expect(m955[sftag]).to eq('i2661010')
        end

        it 'sets $l as location code' do
          sftag = 'l'
          expect(m955[sftag]).to eq('trln')
        end

        it 'sets $s as status _description_' do
          sftag = 's'
          expect(m955[sftag]).to eq('Available')
        end

        it 'sets $t as itype _description_' do
          sftag = 't'
          expect(m955[sftag]).to eq('Book')
        end

        it 'sets $c as copy number as string' do
          sftag = 'c'
          expect(m955[sftag]).to eq('1')
        end
      end

      describe 'check_marc' do
        let(:grec) { GoogleBooksRecord.new(bib, item) }

        it 'false when item is suppressed' do
          item.is_suppressed = true
          item.item_status_code = '-'
          expect(grec.acceptable_marc?).to be false
        end

        it 'false when item withdrawn' do
          item.is_suppressed = false
          item.item_status_code = 'w'
          expect(grec.acceptable_marc?).to be false
        end

        context 'when item is not suppressed or withdrawn' do
          it 'has no warnings' do
            item.is_suppressed = false
            item.item_status_code = '-'
            expect(grec.acceptable_marc?).to be true
          end
        end
      end
    end
  end
end
