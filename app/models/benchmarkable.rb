module Benchmarkable
  delegate :logger, to: :Rails
  include ActiveSupport::Benchmarkable
end