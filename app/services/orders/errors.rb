module Orders
  module Errors
    class InvalidTier < StandardError; end
    class UnknownTier < StandardError; end
    class PriceMismatch < StandardError; end
    class StockMismatch < StandardError; end
  end
end
