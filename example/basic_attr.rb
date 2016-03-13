require 'neuroncheck'

class Foo
  extend NeuronCheck

  ndecl {
    val String
  }
  attr_accessor :name1, :name2
end

foo_instance = Foo.new

foo_instance.name2 = 'test' #=> no error
foo_instance.name2 = 1

#=> script.rb:15:in `<main>': value of attribute `Foo#name2' must be String, but set 1 (NeuronCheckError)
#             got: 1
#     declared at: script.rb:7:in `block in <class:Foo>'
#   
