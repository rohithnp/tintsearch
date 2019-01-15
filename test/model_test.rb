require_relative "test_helper"

class ModelTest < Minitest::Test
  def test_disable_callbacks_model
    store_names ["product a"]

    Product.disable_search_callbacks
    assert !Product.search_callbacks?

    store_names ["product b"]
    assert_search "product", ["product a"]

    Product.enable_search_callbacks
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end

  def test_disable_callbacks_global
    # make sure callbacks default to on
    assert Tintsearch.callbacks?

    store_names ["product a"]

    Tintsearch.disable_callbacks
    assert !Tintsearch.callbacks?

    store_names ["product b"]
    assert_search "product", ["product a"]

    Tintsearch.enable_callbacks
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end

  def test_multiple_models
    store_names ["Product A"]
    store_names ["Product B"], Store
    assert_equal Product.all + Store.all, Tintsearch.search("product", index_name: [Product, Store], order: "name").to_a
  end
end
