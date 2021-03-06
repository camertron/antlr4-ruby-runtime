require 'antlr4/runtime/object_equality_comparator'
require 'antlr4/runtime/murmur_hash'

module Antlr4::Runtime

  class Array2DHashSet
    INITIAL_CAPACITY = 16 # must be power of 2
    INITIAL_BUCKET_CAPACITY = 8
    LOAD_FACTOR = 0.75

    def initialize(comparator = nil, initial_capacity = INITIAL_CAPACITY, initial_bucket_capacity = INITIAL_BUCKET_CAPACITY)
      comparator.nil? ? @comparator = ObjectEqualityComparator.instance : @comparator = comparator

      @n_elements = 0
      @initial_bucket_capacity = initial_bucket_capacity
      @threshold = (initial_bucket_capacity * LOAD_FACTOR).floor # when to expand
      @current_prime = 1 # jump by 4 primes each expand or whatever
      @buckets = create_buckets(initial_capacity)
    end

    def get_or_add(o)
      expand if @n_elements > @threshold
      get_or_add_impl(o)
    end

    def get_or_add_impl(o)
      b = get_bucket(o)
      bucket = @buckets[b]

      if bucket.nil?
        bucket = create_bucket(@initial_bucket_capacity)
        bucket[0] = o
        @buckets[b] = bucket
        @n_elements += 1
        return o
      end

      # LOOK FOR IT IN BUCKET
      i = 0
      while i < bucket.length
        existing = bucket[i]
        if existing.nil? # empty slot not there, add.
          bucket[i] = o
          @n_elements += 1
          return o
        end
        if @comparator.equals(existing, o)
          return existing # found existing, quit
        end

        i += 1
      end

      # FULL BUCKET, add to end
      @buckets[b] = bucket
      bucket << o # add to end
      @n_elements += 1
      o
    end

    def get(o)
      return o if o.nil?

      b = get_bucket(o)
      bucket = @buckets[b]
      if bucket.nil?
        return nil # no bucket
      end

      i = 0
      while i < bucket.length
        e = bucket[i]
        if e.nil?
          return nil # empty slot not there
        end
        return e if @comparator.equals(e, o)
        i += 1
      end
      nil
    end

    def get_bucket(o)
      hash = @comparator.hash(o)
      hash & (@buckets.length - 1) # assumes len is power of 2
    end

    def hash
      objs = []
      i = 0
      while i < @buckets.length
        bucket = @buckets[i]
        if bucket.nil?
          i += 1
          next
        end

        j = 0
        while j < bucket.length
          o = bucket[j]
          break if o.nil?

          objs << o
          j += 1
        end
        i += 1
      end

      hash_code = MurmurHash.hash_objs(objs)

      if !@_hash.nil?
        if hash_code == @_hash
          puts 'Same hash_code for Array2DHashSet'
        else
          puts 'Different hash_code for Array2DHashSet'
        end
      end
      @_hash = hash_code
    end

    def equals(o)
      return true if o == self
      return false unless o.is_a? Array2DHashSet

      other = o
      return false if other.size != size

      contains_all(other)
    end

    def add(t)
      existing = get_or_add(t)
      existing == t
    end

    def size
      @n_elements
    end

    def empty?
      @n_elements == 0
    end

    def contains(o)
      contains_fast(o)
    end

    def contains_fast(obj)
      return false if obj.nil?

      !get(obj).nil?
    end

    def iterator
      a = to_a
      a.sort(@comparator) unless @comparator.nil?
      SetIterator.new(a, self)
    end

    def to_a
      a = create_bucket(size)
      i = 0
      j = 0
      while j < @buckets.length
        bucket = @buckets[j]
        if bucket.nil?
          j += 1
          next
        end

        k = 0
        while k < bucket.length
          o = bucket[k]
          break if o.nil?

          a[i] = o
          i += 1
          k += 1
        end
        j += 1
      end
      a
    end

    def remove(o)
      remove_fast(o)
    end

    def remove_fast(obj)
      return false if obj.nil?

      b = get_bucket(obj)
      bucket = @buckets[b]
      if bucket.nil?
        # no bucket
        return false
      end

      i = 0
      while i < bucket.length
        e = bucket[i]
        if e.nil?
          # empty slot not there
          return false
        end

        if @comparator.eql?(e, obj) # found it
          bucket[i] = nil
          return true
        end
        i += 1
      end

      false
    end

    def contains_all(collection)
      if collection.is_a? Array2DHashSet
        s = collection
        i = 0
        while i < s.buckets.length
          bucket = s.buckets[i]
          if bucket.nil?
            i += 1
            next
          end

          j = 0
          while j < bucket.length
            o = bucket[j]
            break if o.nil?
            return false unless contains_fast(o)
            j += 1
          end
          i += 1
        end
      else
        i = 0
        while i < collection.length
          o = collection[i]
          return false unless contains_fast(o)
          i += 1
        end
      end
      true
    end

    def add_all(c)
      changed = false
      i = 0
      while i < c.length
        o = c[i]
        existing = get_or_add(o)
        changed = true if existing != o
        i += 1
      end
      changed
    end

    def retain_all(c)
      newsize = 0
      k = 0
      while k < @buckets.length
        bucket = @buckets[k]
        if bucket.nil?
          k += 1
          next
        end

        i = 0
        j = 0
        while i < bucket.length
          break if bucket[i].nil?

          if c.contains(bucket[i])
            # keep
            bucket[j] = bucket[i] if i != j

            j += 1
            newsize += 1
          end

          i += 1
        end

        newsize += j

        while j < i
          bucket[j] = nil
          j += 1
        end
        k += 1
      end

      changed = newsize != @n_elements
      @n_elements = newsize
      changed
    end

    def remove_all(c)
      changed = false
      i = 0
      while i < c.length
        o = c[i]
        changed |= remove_fast(o)
        i += 1
      end

      changed
    end

    def clear
      @buckets = create_buckets(INITIAL_CAPACITY)
      @n_elements = 0
      @threshold = (INITIAL_CAPACITY * LOAD_FACTOR).floor
    end

    def to_s
      return '{}' if size == 0

      buf = ''
      buf << '{'
      first = true
      i = 0
      while i < @buckets.length
        bucket = @buckets[i]
        if bucket.nil?
          i += 1
          next
        end

        j = 0
        while j < bucket.length
          o = bucket[j]
          break if o.nil?

          if first
            first = false
          else
            buf << ', '
            buf << o.to_s
          end
          j += 1
        end
        i += 1
      end
      buf << '}'
      buf
    end

    def to_table_string
      buf = ''
      i = 0
      while i < @buckets.length
        bucket = @buckets[i]
        if bucket.nil?
          buf << "null\n"
        else
          buf << '['
          first = true
          j = 0
          while j < bucket.length
            o = bucket[j]
            if first
              first = false
            else
              buf << ' '
            end
            buf << if o.nil?
                     '_'
                   else
                     o.to_s
                   end
            j += 1
          end
          buf << "]\n"
        end
        i += 1
      end
      buf
    end

    def create_buckets(capacity)
      Array.new(capacity)
    end

    def create_bucket(capacity)
      Array.new(capacity)
    end

    class SetIterator
      def initialize(data, parent)
        @data = data
        @parent = parent
        @next_index = 0
        @removed = true
      end

      def has_next
        @next_index < @data.length
      end

      def next
        raise StandardError unless has_next

        @removed = false
        result = @data[@next_index]
        @next_index += 1
        result
      end

      def remove
        raise IllegalStateException if @removed

        parent.remove(@data[@next_index - 1])
        @removed = true
      end
    end

    def expand
      old = @buckets
      @current_prime += 4
      new_capacity = @buckets.length * 2
      new_table = create_buckets(new_capacity)
      new_bucket_lengths = Array.new(new_table.length, 0)
      @buckets = new_table
      @threshold = (new_capacity * LOAD_FACTOR).floor

      old_size = size
      j = 0
      while j < old.length
        bucket = old[j]
        if bucket.nil?
          j += 1
          next
        end

        k = 0
        while k < bucket.length
          o = bucket[k]
          break if o.nil?

          b = get_bucket(o)
          bucket_length = new_bucket_lengths[b]
          if bucket_length == 0
            new_bucket = create_bucket(@initial_bucket_capacity)
            new_table[b] = new_bucket
          else
            new_bucket = new_table[b]
            if bucket_length == new_bucket.length
              tmp = Array.new(new_bucket.length * 2)
              i = 0
              while i < new_bucket.length
                tmp[i] = new_bucket[i]
                i += 1
              end
              new_bucket = tmp
              new_table[b] = new_bucket
            end
          end

          new_bucket[bucket_length] = o
          new_bucket_lengths[b] += 1
          k += 1
        end
        j += 1
      end

      raise StandardError, '@nElements != oldSize' if @n_elements != old_size
    end
  end
end