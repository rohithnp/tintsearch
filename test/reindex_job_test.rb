require_relative "test_helper"

class ReindexJobTest < Minitest::Test
  def setup
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
    Tintsearch::ReindexJob.new("Product", product.id.to_s).perform
    Product.tintsearch_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Tintsearch::ReindexJob.new("Product", product.id.to_s).perform
    Product.tintsearch_index.refresh
    assert_search "*", []
  end
end
