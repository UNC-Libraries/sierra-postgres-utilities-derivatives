module Sierra
  module Derivatives
    # Derive alternate system bib record from Sierra bib
    #
    # For example, take a Sierra bib and attached records and derive
    # Google Books MARC/marcxml.
    # Or combine with an Internet Archive record to derive MARC/marcxml
    # conforming to HathiTrust ingest specs.
    #
    # Generally this gets subclassed to provide alternate system-specific
    # transformations and checks.
    #
    # The major processes this class allows for are:
    #   - Modify/combine Sierra MARC into alternate marc
    #   - Allow for MARC quality-checks
    #   - Write the alternate marc to xml
    class DerivativeRecord
      attr_reader :warnings

      def initialize(bib_rec)
        @sierra = bib_rec
        @warnings = []
      end

      def bnum
        @sierra.bnum
      rescue
        return if @sierra.nil?

        "#{@sierra.record_type_code}#{@sierra.record_num}a"
      end

      # Original Sierra record's MARC
      #
      # @param [Boolean] quick (default: false) When false, uses bib's leader,
      #   controlfield, and varfield associations to create the marc. When true,
      #   uses prepared statements to retrieve the leader/etc. This is quicker
      #   retrieval but does not cache the retrieved fields, and so may
      #   be slower overall if you later need to access the varfields, etc.
      # @return [MARC::Record] Sierra record's original MARC
      def smarc(quick: false)
        return @sierra.quick_marc if quick

        @sierra.marc
      end

      # Retrieves cached alternate/transformed MARC, or derives alternate MARC
      # from Sierra MARC and caches it.
      #
      # @return [MARC::Record] transformed Sierra MARC
      def altmarc
        @altmarc ||= get_alt_marc
      end

      # Transforms Sierra's marc for a bib.
      #
      # This transformation is used for submitting MARC to HathiTrust for bibs
      # scanned and uploaded to Internet Archive. Subclasses for other processes
      # overwrite this method with their own custom transformations.
      #
      # @return [MARC::Record] transformed Sierra MARC
      def get_alt_marc
        # copy Sierra MARC
        altmarc = MARC::Record.new_from_marc(smarc.to_marc)

        # delete things
        altmarc.fields.delete_if { |f| f.tag =~ /001|003|9../ }

        # add things
        altmarc.append(
          MARC::ControlField.new('001', bnum.chop) # chop trailing 'a'
        )
        altmarc.append(MARC::ControlField.new('003', 'NcU'))
        # look for oclcnum in sierra marc; not altmarc where we may have
        # just deleted the 001
        if smarc.m035_lacks_oclcnum?
          altmarc.append(MARC::DataField.new('035', ' ', ' ',
                                             ['a', "(OCoLC)#{smarc.oclcnum}"]))
        end
        altmarc.append(my955) if my955
        altmarc.sort
      end

      # This is to be defined in subclasses (when a 955 is supposed to carry
      # item/InternetArchive/whatever details).
      def my955; end

      def warn(message)
        @warnings << message
        puts "#{bnum}\t#{message}\n"
      end

      # Stub to be overwritten by subclass to perform any necessary marc
      # (and/or record) checks
      #
      # example check:
      #   if @smarc.no_leader?
      #     warn('This bib record has no Leader. Report to cataloging staff.'
      #   end
      #
      def check_record; end

      # @return [Boolean] whether MARC/record checks passed or not
      def acceptable_marc?
        check_record
        @warnings.empty?
      end

      # Conditionally writes altmarc as xml to file.
      #
      # @param [#read] outfile open io object for marcxml output
      # @param [Boolean] strict (default: true) When true, xml is only
      #   written if #acceptable_marc? is true for the record. when false, the
      #   acceptable_marc? check is skipped and xml is written regardless.
      # @param [Boolean] strip_datafields (default: true) whether datafields
      #   (not controlfields) should have leading/trailing whitespace stripped
      # @return void
      def write_xml(outfile:, strict: true, strip_datafields: true)
        return if strict && !acceptable_marc?

        ofile =
          if outfile.respond_to?(:write)
            outfile
          else
            File.open(outfile, 'w')
          end

        ofile.write(xml(strip_datafields: strip_datafields))
        ofile.close unless outfile.respond_to?(:write)
      end

      # Uses Marc::Record extension .xml_string to transform altmarc into an xml
      # string.
      #
      # @param [Boolean] strip_datafields (default: true) whether datafields
      #   (not controlfields) should have leading/trailing whitespace stripped
      # @return [String] altmarc as xml string
      def xml(strip_datafields: true)
        altmarc.xml_string(strip_datafields: strip_datafields)
      end
    end
  end
end
