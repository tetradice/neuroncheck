require 'neuroncheck'

class Foo
  extend NeuronCheck

  ndecl {
    args Numeric, String
  }
  def kw_method(rate, *values, opt1: false, opt2: nil, **kwrest)
    # Main process...

    return "OK. (rate = #{rate}, values = #{values.inspect}, opt1 = #{opt1.inspect}, opt2 = #{opt2.inspect})"
  end
end

foo_instance = Foo.new
foo_instance.kw_method(1.0) # => OK. (rate = 1.0, values = [], opt1 = false, opt2 = nil)
foo_instance.kw_method(1.0, 'value A') # => OK. (rate = 1.0, values = ['value A'], opt1 = false, opt2 = nil)
foo_instance.kw_method(1.0, 'value A', 'value B') # => OK. (rate = 1.0, values = ['value A', 'value B'], opt1 = false, opt2 = nil)

foo_instance.kw_method(1.0, opt1: true) # => OK. (rate = 1.0, values = [], opt1 = true, opt2 = nil)

foo_instance.kw_method(1.0, 1, 2)

#=> script.rb:23:in `<main>': 2nd argument `values' of `Foo#kw_method' must be String, but was 1 (NeuronCheckError)
#             got: 1
#       signature: Foo#kw_method(rate:Numeric, values:String, opt1:any, opt2:any, kwrest:any)
#     declared at: script.rb:7:in `block in <class:Foo>'
#   
