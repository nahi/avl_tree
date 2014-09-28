require 'atomic'

class RedBlackTree
  include Enumerable

  class Node
    UNDEFINED = Object.new
    # direction: ~LEFT == RIGHT, ~RIGHT == LEFT
    LEFT = -1
    RIGHT = 0

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
      case key <=> @key
      when -1
        dir = LEFT
      when 0
        node = new_value(value)
      when 1
        dir = RIGHT
      else
        raise TypeError, "cannot compare #{key} and #{@key} with <=>"
      end
      if dir
        new_child = link(dir).insert(key, value)
        node = new_link(dir, new_child)
        if black? and link(~dir).black? and new_child.red? and !new_child.children_both_black?
          node = node.rebalance_for_insert(dir)
        end
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
      case key <=> @key
      when -1
        dir = LEFT
      when 0
        deleted = self
        node, rebalance = delete_node
      when 1
        dir = RIGHT
      else
        raise TypeError, "cannot compare #{key} and #{@key} with <=>"
      end
      if dir
        deleted, new_child, rebalance = link(dir).delete(key)
        node = new_link(dir, new_child)
        if rebalance
          node, rebalance = node.rebalance_for_delete(dir)
        end
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
      lh = @left.nil? || @left.empty? ? 0 : @left.check_height
      rh = @right.nil? || @right.empty? ? 0 : @right.check_height
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

    def new_links(dir, node, other, color = @color)
      dir == LEFT ? 
        Node.new(@key, @value, node, other, color) :
        Node.new(@key, @value, other, node, color)
    end

    def new_link(dir, node, color = @color)
      dir == LEFT ? 
        Node.new(@key, @value, node, @right, color) :
        Node.new(@key, @value, @left, node, color)
    end

    def new_color(color)
      Node.new(@key, @value, @left, @right, color)
    end

    def new_value(value)
      Node.new(@key, value, @left, @right, @color)
    end

    def link(dir)
      dir == LEFT ? @left : @right
    end

    def children_both_black?
      @right.black? and @left.black?
    end

    def delete_min
      if @left.empty?
        [self, *delete_node]
      else
        deleted, left, rebalance = @left.delete_min
        node = new_link(LEFT, left)
        if rebalance
          node, rebalance = node.rebalance_for_delete(LEFT)
        end
        [deleted, node, rebalance]
      end
    end

    # rebalance when the left/right sub-tree is 1 level lower than the right/left
    def rebalance_for_delete(dir)
      other = link(~dir)
      rebalance = false
      if black?
        if other.black?
          if other.children_both_black?
            # make whole sub-tree 1 level lower and ask rebalance
            node = new_link(~dir, other.new_color(:RED))
            rebalance = true
          else
            # move 1 black from the right to the left by single/double rotation
            node = balanced_rotate(dir)
          end
        else
          # flip this sub-tree into another type of 3-children node
          node = rotate(dir)
          # try to rebalance in sub-tree
          new_child, rebalance = node.link(dir).rebalance_for_delete(dir)
          raise 'should not happen' if rebalance
          node = node.new_links(dir, new_child, node.link(~dir))
        end
      else # red
        if other.children_both_black?
          # make right sub-tree 1 level lower
          node = new_link(~dir, other.new_color(@color), other.color)
        else
          # move 1 black from the right to the left by single/double rotation
          node = balanced_rotate(dir)
        end
      end
      [node, rebalance]
    end

    # move 1 black from the right/left to the left/right by single/double rotation
    def balanced_rotate(dir)
      other = link(~dir)
      if other.link(dir).red? and other.link(~dir).black?
        node = new_link(~dir, other.rotate(~dir))
      else
        node = self
      end
      node = node.rotate(dir)
      node.new_links(dir, node.link(dir).new_color(:BLACK), node.link(~dir).new_color(:BLACK))
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
    # Left single rotation
    # (d (B A c) e) where A and B are RED --> (b A (D c e))
    #
    #     d          b
    #    / \        / \
    #   B   e  ->  A   D
    #  / \            / \
    # A   c          c   e
    #
    def rotate(dir)
      rev = ~dir
      node = new_link(rev, link(rev).link(dir), link(rev).color)
      link(rev).new_links(dir, node, link(rev).link(rev), @color)
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
        new_links(LEFT, @left.new_color(:BLACK), @right.new_color(:BLACK), :RED)
      else
        self
      end
    end

    # rebalance when the left/right sub-tree is 1 level higher than the right/left
    # move 1 black from the left to the right by single/double rotation
    #
    # precondition: self is black and @left/@right is red
    def rebalance_for_insert(dir)
      node = self
      if link(dir).link(~dir).red?
        node = new_link(dir, link(dir).rotate(dir))
      end
      node.rotate(~dir)
    end

  private

    def delete_node
      rebalance = false
      if @left.empty? and @right.empty?
        # just remove this node and ask rebalance to the parent
        new_node = EMPTY
        if black?
          rebalance = true
        end
      elsif @left.empty? or @right.empty?
        # pick the single children
        new_node = @left.empty? ? @right : @left
        if black?
          # keep the color black
          raise 'should not happen' unless new_node.red?
          new_node = new_node.new_color(@color)
        else
          # just remove the red node
        end
      else
        # pick the minimum node from the right sub-tree and replace self with it
        deleted, right, rebalance = @right.delete_min
        new_node = deleted.new_links(LEFT, @left, right, @color)
        if rebalance
          new_node, rebalance = new_node.rebalance_for_delete(RIGHT)
        end
      end
      [new_node, rebalance]
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
    @root = Atomic.new(Node::EMPTY)
    @default = default
    @default_proc = block
  end

  def empty?
    @root.get == Node::EMPTY
  end

  def size
    @root.get.size
  end
  alias length size

  def each(&block)
    if block_given?
      @root.get.each(&block)
      self
    else
      Enumerator.new(@root.get)
    end
  end
  alias each_pair each

  def each_key
    if block_given?
      @root.get.each do |k, v|
        yield k
      end
      self
    else
      Enumerator.new(@root.get, :each_key)
    end
  end

  def each_value
    if block_given?
      @root.get.each do |k, v|
        yield v
      end
      self
    else
      Enumerator.new(@root.get, :each_value)
    end
  end

  def keys
    @root.get.keys
  end

  def values
    @root.get.values
  end

  def clear
    @root.set(Node::EMPTY)
  end

  def []=(key, value)
    @root.update { |root|
      root = root.insert(key, value)
      root.set_root
      root.check_height if $DEBUG
      root
    }
  end
  alias insert []=

  def key?(key)
    @root.get.retrieve(key) != Node::UNDEFINED
  end
  alias has_key? key?

  def [](key)
    value = @root.get.retrieve(key)
    if value == Node::UNDEFINED
      default_value
    else
      value
    end
  end

  def delete(key)
    deleted = nil
    @root.update { |root|
      deleted, root, rebalance = root.delete(key)
      unless root == Node::EMPTY
        root.set_root
        root.check_height if $DEBUG
      end
      root
    }
    deleted.value
  end

  def dump_tree(io = '')
    @root.get.dump_tree(io)
    io << $/
    io
  end

  def dump_sexp
    @root.get.dump_sexp || ''
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
