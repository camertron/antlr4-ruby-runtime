require 'antlr4/runtime/dfa_state'

module Antlr4::Runtime

  class ATNSimulator
    SERIALIZED_VERSION = ATNDeserializer.SERIALIZED_VERSION

    SERIALIZED_UUID = ATNDeserializer.SERIALIZED_Uuid

    attr_accessor :atn

    class << self
      attr_accessor :error
      @@error = DFAState.new
      @@error.initialize_configs(ATNConfigSet.new)
      @@error.state_number = Integer::MAX
    end

    def initialize(atn, shared_context_cache)
      @atn = atn
      @shared_context_cache = shared_context_cache
    end

    def clear_dfa
      raise UnsupportedOperationException, 'This ATN simulator does not support clearing the DFA.'
    end

    attr_reader :shared_context_cache

    def cached_context(context)
      return context if @shared_context_cache.nil?

      visited = {}
      PredictionContextUtils.cached_context(context, @shared_context_cache, visited)
    end

    def self.deserialize(data)
      ATNDeserializer.new.deserialize(data)
    end

    def self.check_condition(condition, message = nil)
      ATNDeserializer.new.check_condition(condition, message)
    end

    def self.to_int(c)
      ATNDeserializer.to_int(c)
    end

    def self.to_int32(data, offset)
      ATNDeserializer.to_int32(data, offset)
    end

    def self.to_long(data, offset)
      ATNDeserializer.to_long(data, offset)
    end

    def self.to_uuid(data, offset)
      ATNDeserializer.to_uuid(data, offset)
    end

    def edge_factory(atn, type, src, trg, arg1, arg2, arg3, sets)
      ATNDeserializer.new.edge_factory(atn, type, src, trg, arg1, arg2, arg3, sets)
    end

    def state_factory(type, rule_index)
      ATNDeserializer.new.state_factory(type, rule_index)
    end
  end
end