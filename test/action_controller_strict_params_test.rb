class ArticlesController < ActionController::Base
  def create
    params[:author].strict(:name)
    head :ok
  end
end

class ActionControllerStrongParamsTest < ActionController::TestCase
  tests ArticlesController

  test "missing strict parameters will raise exception" do
    post :create, { author: { pet: "Toby" } }
    assert_response :bad_request
  end

  test "strict parameters that are present will not raise" do
    post :create, { author: { name: "David" } }
    assert_response :ok
  end

  test "extra parameters will be mentioned in the return" do
    post :create, { author: { password: "rails" } }
    assert_equal "Parameters forbidden: password", response.body
  end
end

