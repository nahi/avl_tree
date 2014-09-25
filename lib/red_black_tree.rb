require 'thread'

class RedBlackTree
  include Enumerable

  class Node
    UNDEFINED = Object.new

    attr_reader :key, :value, :color
    attr_reader :left, :right

    def initialize(key, value, left = EMPTY, right = EMPTY, color = :RED)
      @key = key
      @value = value
      @left = left
      @right = right
      # new node is added as RED
      @color = color
    end

    def dup(left, right, color = @color)
      Node.new(@key, @value, left, right, color)
    end

    def set_root
      @color = :BLACK
    end

    def red?
      @color == :RED
    end

    def black?
      @color == :BLACK
    end

    def empty?
      false
    end

    def size
      @left.size + 1 + @right.size
    end

    # inorder
    def each(&block)
      @left.each(&block)
      yield [@key, @value]
      @right.each(&block)
    end

    def each_key
      each do |k, v|
        yield k
      end
    end

    def each_value
      each do |k, v|
        yield v
      end
    end

    def keys
      collect { |k, v| k }
    end

    def values
      collect { |k, v| v }
    end

    # returns new_root
    def insert(key, value)
      node = self
      case key <=> node.key
      when -1
        node = node.dup(node.left.insert(key, value), node.right)
        if black? and node.right.black? and node.left.red? and !node.left.children_both_black?
          node = rebalance_for_left_insert(node)
        end
      when 0
        # TODO: is it safe?
        @value = value
      when 1
        node = node.dup(node.left, node.right.insert(key, value))
        if black? and node.left.black? and node.right.red? and !node.right.children_both_black?
          node = rebalance_for_right_insert(node)
        end
      else
        raise TypeError, "cannot compare #{key} and #{node.key} with <=>"
      end
      node.pullup_red
    end

    # returns value
    def retrieve(key)
      case key <=> @key
      when -1
        @left.retrieve(key)
      when 0
        @value
      when 1
        @right.retrieve(key)
      else
        nil
      end
    end

    # returns [deleted_node, new_root, is_rebalance_needed]
    def delete(key)
      node = self
      case key <=> node.key
      when -1
        deleted, left, rebalance = node.left.delete(key)
        node = node.dup(left, node.right)
        if rebalance
          node, rebalance = rebalance_for_left_delete(node)
        end
      when 0
        deleted = self
        node, rebalance = delete_node(node)
      when 1
        deleted, right, rebalance = node.right.delete(key)
        node = node.dup(node.left, right)
        if rebalance
          node, rebalance = rebalance_for_right_delete(node)
        end
      else
        raise TypeError, "cannot compare #{key} and #{node.key} with <=>"
      end
      [deleted, node, rebalance]
    end

    def dump_tree(io, indent = '')
      @right.dump_tree(io, indent + '  ')
      io << indent << sprintf("#<%s:0x%010x %s %s> => %s", self.class.name, __id__, @color, @key.inspect, @value.inspect) << $/
      @left.dump_tree(io, indent + '  ')
    end

    def dump_sexp
      left = @left.dump_sexp
      right = @right.dump_sexp
      if left or right
        '(' + [@key, left || '-', right].compact.join(' ') + ')'
      else
        @key
      end
    end

    # for debugging
    def check_height
      lh = @left.empty? ? 0 : @left.check_height
      rh = @right.empty? ? 0 : @right.check_height
      if red?
        if @left.red? or @right.red?
          puts dump_tree(STDERR)
          raise 'red/red assertion failed'
        end
      else
        if lh != rh
          puts dump_tree(STDERR)
          raise "black height unbalanced: #{lh} #{rh}"
        end
      end
      (lh > rh ? lh : rh) + (black? ? 1 : 0)
    end

  protected

    def children_both_black?
      @right.black? and @left.black?
    end

    def color=(color)
      @color = color
    end

    def color_flip(other)
      @color, other.color = other.color, @color
    end

    def delete_min
      node = self
      if node.left.empty?
        [self, *delete_node(node)]
      else
        node = self
        deleted, left, rebalance = node.left.delete_min
        node = node.dup(left, node.right)
        if rebalance
          node, rebalance = rebalance_for_left_delete(node)
        end
        [deleted, node, rebalance]
      end
    end

    # trying to rebalance when the left sub-tree is 1 level lower than the right
    def rebalance_for_left_delete(node)
      rebalance = false
      if node.black?
        if node.right.black?
          if node.right.children_both_black?
            # make whole sub-tree 1 level lower and ask rebalance
            node.right.color = :RED
            rebalance = true
          else
            # move 1 black from the right to the left by single/double rotation
            node = balanced_rotate_left(node)
          end
        else
          # flip this sub-tree into another type of 3-children node
          node = rotate_left(node)
          # try to rebalance in sub-tree
          left, rebalance = rebalance_for_left_delete(node.left)
          raise 'should not happen' if rebalance
          node = node.dup(left, node.right)
        end
      else # red
        if node.right.children_both_black?
          # make right sub-tree 1 level lower
          node.color_flip(node.right)
        else
          # move 1 black from the right to the left by single/double rotation
          node = balanced_rotate_left(node)
        end
      end
      [node, rebalance]
    end

    # trying to rebalance when the right sub-tree is 1 level lower than the left
    # See rebalance_for_left_delete.
    def rebalance_for_right_delete(node)
      rebalance = false
      if node.black?
        if node.left.black?
          if node.left.children_both_black?
            node.left.color = :RED
            rebalance = true
          else
            node = balanced_rotate_right(node)
          end
        else
          node = rotate_right(node)
          right, rebalance = rebalance_for_right_delete(node.right)
          raise 'should not happen' if rebalance
          node = node.dup(node.left, right)
        end
      else # red
        if node.left.children_both_black?
          node.color_flip(node.left)
        else
          node = balanced_rotate_right(node)
        end
      end
      [node, rebalance]
    end

    # move 1 black from the right to the left by single/double rotation
    def balanced_rotate_left(node)
      if node.right.left.red? and node.right.right.black?
        node = node.dup(node.left, rotate_right(node.right))
      end
      node = rotate_left(node)
      node.right.color = node.left.color = :BLACK
      node
    end

    # move 1 black from the left to the right by single/double rotation
    def balanced_rotate_right(node)
      if node.left.right.red? and node.left.left.black?
        node = node.dup(rotate_left(node.left), node.right)
      end
      node = rotate_right(node)
      node.right.color = node.left.color = :BLACK
      node
    end

    # Right single rotation
    # (b a (D c E)) where D and E are RED --> (d (B a c) E)
    #
    #   b              d
    #  / \            / \
    # a   D    ->    B   E
    #    / \        / \
    #   c   E      a   c
    #
    def rotate_left(node)
      left = node.dup(node.left, node.right.left, node.right.color)
      node.right.dup(left, node.right.right, node.color)
    end

    # Left single rotation
    # (d (B A c) e) where A and B are RED --> (b A (D c e))
    #
    #     d          b
    #    / \        / \
    #   B   e  ->  A   D
    #  / \            / \
    # A   c          c   e
    #
    def rotate_right(node)
      right = node.dup(node.left.right, node.right, node.left.color)
      node.left.dup(node.left.left, right, node.color)
    end

    # Pull up red nodes
    # (b (A C)) where A and C are RED --> (B (a c))
    #
    #   b          B
    #  / \   ->   / \
    # A   C      a   c
    #
    def pullup_red
      if black? and @left.red? and @right.red?
        @left.color = @right.color = :BLACK
        self.color = :RED
      end
      self
    end

  private

    # trying to rebalance when the left sub-tree is 1 level higher than the right
    # precondition: self is black and @left is red
    def rebalance_for_left_insert(node)
      # move 1 black from the left to the right by single/double rotation
      if node.left.right.red?
        node = node.dup(rotate_left(node.left), node.right)
      end
      rotate_right(node)
    end

    # trying to rebalance when the right sub-tree is 1 level higher than the left
    # See rebalance_for_left_insert.
    def rebalance_for_right_insert(node)
      if node.right.left.red?
        node = node.dup(node.left, rotate_right(node.right))
      end
      rotate_left(node)
    end

    def delete_node(node)
      rebalance = false
      if node.left.empty? and node.right.empty?
        # just remove this node and ask rebalance to the parent
        node = EMPTY
        if black?
          rebalance = true
        end
      elsif node.left.empty? or node.right.empty?
        # pick the single children
        node = node.left.empty? ? node.right : node.left
        if black?
          # keep the color black
          raise 'should not happen' unless node.red?
          color_flip(node)
        else
          # just remove the red node
        end
      else
        # pick the minimum node from the right sub-tree and replace self with it
        deleted, right, rebalance = node.right.delete_min
        node = deleted.dup(node.left, right, node.color)
        if rebalance
          node, rebalance = rebalance_for_right_delete(node)
        end
      end
      [node, rebalance]
    end

    def collect
      pool = []
      each do |key, value|
        pool << yield(key, value)
      end
      pool
    end

    class EmptyNode < Node
      def initialize
        @value = nil
        @color = :BLACK
      end

      def empty?
        true
      end

      def size
        0
      end

      def each(&block)
        # intentionally blank
      end

      # returns new_root
      def insert(key, value)
        Node.new(key, value)
      end

      # returns value
      def retrieve(key)
        UNDEFINED
      end

      # returns [deleted_node, new_root, is_rebalance_needed]
      def delete(key)
        [self, self, false]
      end

      def dump_tree(io, indent = '')
        # intentionally blank
      end

      def dump_sexp
        # intentionally blank
      end
    end
    EMPTY = Node::EmptyNode.new.freeze
  end

  DEFAULT = Object.new

  attr_accessor :default
  attr_reader :default_proc

  def initialize(default = DEFAULT, &block)
    if block && default != DEFAULT
      raise ArgumentError, 'wrong number of arguments'
    end
    @root = Node::EMPTY
    @default = default
    @default_proc = block
    @writer_lock = Mutex.new
  end

  def empty?
    @root == Node::EMPTY
  end

  def size
    @root.size
  end
  alias length size

  def each(&block)
    if block_given?
      @root.each(&block)
      self
    else
      Enumerator.new(@root)
    end
  end
  alias each_pair each

  def each_key
    if block_given?
      @root.each do |k, v|
        yield k
      end
      self
    else
      Enumerator.new(@root, :each_key)
    end
  end

  def each_value
    if block_given?
      @root.each do |k, v|
        yield v
      end
      self
    else
      Enumerator.new(@root, :each_value)
    end
  end

  def keys
    @root.keys
  end

  def values
    @root.values
  end

  def clear
    @root = Node::EMPTY
  end

  def []=(key, value)
    @writer_lock.synchronize do
      @root = @root.insert(key, value)
      @root.set_root
    end
    @root.check_height if $DEBUG
  end
  alias insert []=

  def key?(key)
    @root.retrieve(key) != Node::UNDEFINED
  end
  alias has_key? key?

  def [](key)
    value = @root.retrieve(key)
    if value == Node::UNDEFINED
      default_value
    else
      value
    end
  end

  def delete(key)
    @writer_lock.synchronize do
      deleted, @root, rebalance = @root.delete(key)
      unless empty?
        @root.set_root
        @root.check_height if $DEBUG
      end
      deleted.value
    end
  end

  def dump_tree(io = '')
    @root.dump_tree(io)
    io << $/
    io
  end

  def dump_sexp
    @root.dump_sexp || ''
  end

  def to_hash
    inject({}) { |r, (k, v)| r[k] = v; r }
  end

private

  def default_value
    if @default != DEFAULT
      @default
    elsif @default_proc
      @default_proc.call
    else
      nil
    end
  end
end
