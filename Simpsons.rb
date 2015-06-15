module Simpsons
  module Characters
    class SimpsonsCharacter
      attr_reader :name, :description, :a_list
      def initialize(name, description)
        @name = name
        @description = description
      end
      def var_return
        x = 42
        x
      end
      def simple_return
        21
      end
      def do_something_with_items(list_of_stuff)
        newitems = list_of_stuff.collect { |item|
          item += item
        }
        @a_list ||= []
        @a_list.concat list_of_stuff
        @a_list.uniq!
        newitems
      end
    end
    class BartNames
      attr_reader :aliases
      def initialize(alias_name)
        @aliases = {}
        @aliases[alias_name] = 1
      end
      def addAlias(alias_name)
        @aliases[alias_name] = (@aliases[alias_name] || 0) + 1
      end
    end
  end

  class KWIKEMartProduct
    attr_reader :product_name, :product_price
    def initialize(product_name, product_price)
      @product_name = product_name
      @product_price = product_price
    end
    def increase_cost(increase = 2)
      @product_price = @product_price * increase
    end
    def monitored_by_magic_hat?
      true
    end
  end


end
