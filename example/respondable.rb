require 'neuroncheck'

class Foo
  extend NeuronCheck

  ndecl {
    args respondable(:each)
  }
  def foo_method(targets)
    return "hello, neuroncheck."
  end
end

foo_instance = Foo.new
foo_instance.foo_method(['a', 'b', 'c']) # => hello, neuroncheck.

foo_instance.foo_method(10)

#=> script.rb:17:in `<main>': 1st argument `targets' of `Foo#foo_method' must be respondable to #each, but was 10 (NeuronCheckError)
#             got: 10
#       signature: Foo#foo_method(targets:respondable(:each))
#     declared at: script.rb:7:in `block in <class:Foo>'
#   
