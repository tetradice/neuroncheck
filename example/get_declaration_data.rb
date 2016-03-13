require 'neuroncheck'
require 'yaml'

module BarMod
  extend NeuronCheck

  ndecl {val String}
  attr_accessor :attr1, :attr2

  module_function
  ndecl {
    args String, [true, false]
  }
  def barfunc(name, flg)
  end
end

class Foo
  extend NeuronCheck

  ndecl {val String}
  attr_accessor :attr3
  ndecl {val String}
  attr_writer :attr4, :attr5
  ndecl {val String}
  attr_reader :attr6, :attr7
  ndecl {val String}
  attr :attr8, true
  ndecl {val String}
  attr :attr9, false

  ndecl {
    args String
  }
  def self.singleton_func(v)
  end

  ndecl {
    args String, Numeric, 100, :a12, respondable(:each), ['yes', 'no'], array_of(String), any
    returns String
  }
  def foo_method(a1, a2, a3, a4, a5, a6, a7, a8, a_blank1, a_blank2)
    return "hello, neuroncheck."
  end
end

puts NeuronCheck.get_declarations_as_json.to_yaml # =>

#=> ---
#   instance_methods:
#     BarMod:
#       barfunc:
#         args:
#         - type: KindOfMatcher
#           expected: String
#         - type: OrMatcher
#           expected: 
#           child_matchers:
#           - type: ObjectIdenticalMathcer
#             expected: true
#           - type: ObjectIdenticalMathcer
#             expected: false
#         returns: 
#         signature_caption: BarMod#barfunc(name:String, flg:[true, false])
#         signature_caption_name_only: BarMod#barfunc
#         precond_source_location: 
#         postcond_source_location: 
#     Foo:
#       foo_method:
#         args:
#         - type: KindOfMatcher
#           expected: String
#         - type: KindOfMatcher
#           expected: Numeric
#         - type: ValueEqualMatcher
#           expected: 100
#         - type: ValueEqualMatcher
#           expected: :a12
#         - type: KeywordPluginMatcher
#           keyword: respondable
#           expected_caption: 'respondable to #each'
#           expected:
#           - each
#         - type: OrMatcher
#           expected: 
#           child_matchers:
#           - type: ValueEqualMatcher
#             expected: 'yes'
#           - type: ValueEqualMatcher
#             expected: 'no'
#         - type: KeywordPluginMatcher
#           keyword: array_of
#           expected_caption: array of String
#           item:
#             type: KindOfMatcher
#             expected: String
#         - type: KeywordPluginMatcher
#           keyword: any
#           expected_caption: any value
#         returns:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#foo_method(a1:String, a2:Numeric, a3:100, a4::a12, a5:respondable(:each),
#           a6:["yes", "no"], a7:array of String, a8:any, a_blank1:any, a_blank2:any)
#           -> String
#         signature_caption_name_only: Foo#foo_method
#         precond_source_location: 
#         postcond_source_location: 
#   singleton_methods:
#     Foo:
#       singleton_func:
#         args:
#         - type: KindOfMatcher
#           expected: String
#         returns: 
#         signature_caption: Foo.singleton_func(v:String)
#         signature_caption_name_only: Foo.singleton_func
#         precond_source_location: 
#         postcond_source_location: 
#   attributes:
#     BarMod:
#       attr1:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: BarMod#attr2 -> String
#         signature_caption_name_only: BarMod#attr2
#         precond_source_location: 
#         postcond_source_location: 
#       attr2:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: BarMod#attr2 -> String
#         signature_caption_name_only: BarMod#attr2
#         precond_source_location: 
#         postcond_source_location: 
#     Foo:
#       attr3:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr3 -> String
#         signature_caption_name_only: Foo#attr3
#         precond_source_location: 
#         postcond_source_location: 
#       attr4:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr5 -> String
#         signature_caption_name_only: Foo#attr5
#         precond_source_location: 
#         postcond_source_location: 
#       attr5:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr5 -> String
#         signature_caption_name_only: Foo#attr5
#         precond_source_location: 
#         postcond_source_location: 
#       attr6:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr7 -> String
#         signature_caption_name_only: Foo#attr7
#         precond_source_location: 
#         postcond_source_location: 
#       attr7:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr7 -> String
#         signature_caption_name_only: Foo#attr7
#         precond_source_location: 
#         postcond_source_location: 
#       attr8:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr8 -> String
#         signature_caption_name_only: Foo#attr8
#         precond_source_location: 
#         postcond_source_location: 
#       attr9:
#         value:
#           type: KindOfMatcher
#           expected: String
#         signature_caption: Foo#attr9 -> String
#         signature_caption_name_only: Foo#attr9
#         precond_source_location: 
#         postcond_source_location: 
