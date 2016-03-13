require 'neuroncheck'

ndecl {
  args String
}
def foo_func(value)
  return "hello, neuroncheck."
end

class Bar
  def test_method
    foo_func(1)
  end
end

Bar.new.test_method

#=> script.rb:12:in `test_method': 1st argument `value' of `foo_func' must be String, but was 1 (NeuronCheckError)
#             got: 1
#       signature: foo_func(value:String)
#     declared at: script.rb:4:in `block in <main>'
#   
#     from script.rb:16:in `<main>'
