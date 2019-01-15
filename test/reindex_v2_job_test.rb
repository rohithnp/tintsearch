require_relative "test_helper"

class ReindexV2JobTest < Minitest::Test
  def setup
    skip unless defined?(ActiveJob)
    super
    Tintsearch.disable_callbacks
  end

  def teardown
    Tintsearch.enable_callbacks
  end

  def test_create
    product = Product.create!(name: "Boom")
    Product.tintsearch_index.refresh
    assert_search "*", []
    Tintsearch::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.tintsearch_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Tintsearch::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.tintsearch_index.refresh
    assert_search "*", []
  end
end
