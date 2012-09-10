require 'test_helper'
require 'action_controller/parameters'

class ParametersStrictTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new({ person: {
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    }})
  end

  test 'raises ParameterForbidden when we have extra parameters' do
    e = assert_raises(ActionController::ParameterForbidden) do
      @params[:person].strict!.permit(:age)
    end
  end

  test 'doesnt raise ParameterForbidden when the parameter are exact' do
    assert_nothing_raised do
      @params[:person].strict!.permit(:age, :name)
    end
  end

  test 'doesnt raise ParameterForbidden when the parameter are exact using nesting' do
    assert_nothing_raised do
      @params[:person].strict!.permit(:age, name: [:first, :last])
    end
  end

  test 'raises ParameterForbidden when we have extra nested parameters' do
    e = assert_raises(ActionController::ParameterForbidden) do
      @params[:person].strict!.permit(:age, name: [:first, :third])
    end
  end

  test 'raises ParameterForbidden when we have extra deep nested parameters' do
    e = assert_raises(ActionController::ParameterForbidden) do
      @params.strict!.permit(person: [ :age, name: [:first, :third]])
    end
  end

  test 'doesnt raise ParameterForbidden when the parameter are exact using deep nesting' do
    assert_nothing_raised do
      @params.strict!.permit(person: [ :age, name: [:first, :last]])
    end
  end

  test 'the strict params are permitted' do
    assert @params[:person].strict!.permit(:age, :name).permitted?
  end

  test 'works with embedded hashes' do
    nested_hash_params = ActionController::Parameters.new(
      email: "test@example.com", profile: {person_description: { age: 35, sex: 'f'}}
    )

    e = assert_raises(ActionController::ParameterForbidden) do
      nested_hash_params.strict!.permit( :email, profile: { person_description: []})
    end
  end

  test 'raises when enabled from class config' do
    ActionController::Parameters.strict_config = true
    e = assert_raises(ActionController::ParameterForbidden) do
      @params[:person].permit(:age)
    end
  end

  test 'its disabled by default' do
    assert_nothing_raised do
      @params[:person].permit(:age)
    end
  end

  test "strict! fields_for_style_nested_params with negative numbers" do
    params    = ActionController::Parameters.new({
      book: {
        authors_attributes: {
          :'-1' => {name: 'William Shakespeare', age_of_death: '52'},
          :'-2' => {name: 'Unattributed Assistant'}
        }
      }
    })
    permitted = params.strict!.permit book: {authors_attributes: [:name, :age_of_death]}

    assert_not_nil permitted[:book][:authors_attributes]['-1']
    assert_not_nil permitted[:book][:authors_attributes]['-2']
    assert_not_nil permitted[:book][:authors_attributes]['-1'][:age_of_death]
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['-1'][:name]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['-2'][:name]
  end
end
