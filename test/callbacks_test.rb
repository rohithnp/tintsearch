require_relative "test_helper"

class CallbacksTest < Minitest::Test
  def test_true_create
    Tintsearch.callbacks(true) do
      store_names ["Product A", "Product B"]
    end
    Product.tintsearch_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_false_create
    Tintsearch.callbacks(false) do
      store_names ["Product A", "Product B"]
    end
    Product.tintsearch_index.refresh
    assert_search "product", []
  end

  def test_bulk_create
    Tintsearch.callbacks(:bulk) do
      store_names ["Product A", "Product B"]
    end
    Product.tintsearch_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end
end
