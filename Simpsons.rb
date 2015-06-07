
class SimpsonsCharacter
  attr_reader :name, :description
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


