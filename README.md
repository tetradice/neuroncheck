# NeuronCheck
Library for checking parameters, return value, preconditions and postconditions with declarative syntax.

## Requirement

Ruby 2.0.0 or later

## Example

~~~ ruby
require 'neuroncheck'

class Converter
  # Activate NeuronCheck on Converter class
  extend NeuronCheck

  # NeuronCheck check declaration block
  ndecl {
    # Arguments declaration (this method receives 3 arguments - 1st is String, 2nd is any object has #each method, and 3rd is Numeric or nil.)
    args String, respondable(:each), [Numeric, nil]

    # Return value declaration (this method returns self)
    returns :self

    # Precondition check
    precond do
      assert(threshold >= 0)
    end
  }

  # Actual method definition
  def convert(text, keywords, threshold = nil)
    # (main process)
  end
end

conv = Converter.new
conv.convert(100, ['Blog', 'Learning'], 0.5)

# => main.rb:28:in `<main>': 1st argument `text' of `Converter#convert' must be String, but was 100 (NeuronCheckError)
#            got: 100
#      signature: Converter#convert(text:String, keywords:respondable(:each), threshold:[Numeric, nil]) -> self
#    declared at: main.rb:10:in `block in <class:Converter>'
#                 from D:/work/neuroncheck/lib/neuroncheck/kernel.rb:25:in `instance_eval'
#                 from D:/work/neuroncheck/lib/neuroncheck/kernel.rb:25:in `ndecl'
#                 from main.rb:8:in `<class:Converter>'
#                 from main.rb:3:in `<main>'
~~~

## Documents and more information

<http://ruby.morphball.net/neuroncheck/> (Japanese only)