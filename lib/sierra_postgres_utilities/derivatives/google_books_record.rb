module Sierra
  module Derivatives
    class GoogleBooksRecord < DerivativeRecord
      attr_reader :item, :inum

      def initialize(sierra_bib, sierra_item)
        super(sierra_bib)
        @item = sierra_item
        @inum = @item.inum
      end

      def my955
        m955 = MARC::DataField.new('955', ' ', ' ')
        m955.add_subfields!('b', @item.barcodes)
        m955.add_subfields!('v', @item.volumes)
        m955.add_subfields!('a', @item.callnos)
        m955.add_subfields!('z', @item.public_notes)

        m955.add_subfields!('i', @item.inum_trunc) # drop trailing 'a'
        m955.add_subfields!('l', @item.location_code)
        m955.add_subfields!('s', @item.status_desc)
        m955.add_subfields!('t', @item.itype_desc)
        m955.add_subfields!('c', @item.copy_num.to_s)

        return nil if m955.subfields.empty?
        return m955
      end

      # perform any necessary marc (or record) checks
      def check_record
        # todo any checks? multiple barcode/volume/callno fields in item
        # any bib problems? non-existent LDR?
        warn('Item record is suppressed') if @item.suppressed?
        warn('Item record is withdrawn') if @item.status_code == 'w'
      end
    end
  end
end
