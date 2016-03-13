require 'neuroncheck'
using NeuronCheckSyntax

class Foo
	ndecl String, Numeric, respondable(:each), ['yes', 'no'] => String
	def foo_method(value, rate, targets, type)
	  return "hello, neuroncheck."
	end
end

foo_instance = Foo.new
foo_instance.foo_method('Value', 0.8, (1..4), 'yes') #=> no error

foo_instance.foo_method('Value', '0.8', (1..4), 'yes')

#=> script.rb:14:in `<main>': 2nd argument `rate' of `Foo#foo_method' must be Numeric, but was "0.8" (NeuronCheckError)
#             got: "0.8"
#       signature: Foo#foo_method(value:String, rate:Numeric, targets:respondable(:each), type:["yes", "no"]) -> String
#     declared at: script.rb:5:in `<class:Foo>'
#   
