require 'antlr4/runtime/empty_prediction_context'

module Antlr4::Runtime

  class PredictionContextCache
    def initialize
      @cache = {}
    end

    def add(ctx)
      return EmptyPredictionContext::EMPTY if ctx == EmptyPredictionContext::EMPTY

      existing = @cache[ctx]
      return existing unless existing.nil?

      @cache[ctx] = ctx
      ctx
    end

    def get(ctx)
      @cache[ctx]
    end

    def size
      @cache.size
    end
  end
end