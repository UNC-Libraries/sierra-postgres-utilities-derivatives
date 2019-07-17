module Sierra
  module Data
    class Bib
      def trln_discovery_record
        @trln_discovery_record ||= Derivatives::TRLNDiscoveryRecord.new(self)
      end
    end
  end
end
