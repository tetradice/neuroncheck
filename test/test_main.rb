$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'test/unit'
require 'neuroncheck'

class BasicArgumentTest < Test::Unit::TestCase
	setup do
		@cls = Class.new
		@cls.class_eval do
			extend NeuronCheck

			ndecl {
				args String
			}
			def single_string_method(arg1)
				return ">" + arg1.to_s
			end

			ndecl {
				args String, String, String
			}
			def multiple_string_method_invalid(arg1, arg2, arg3 = nil)
				return ">#{arg1},#{arg2},#{arg3}"
			end

			ndecl {
				args String, String, [String, nil]
			}
			def multiple_string_method(arg1, arg2, arg3 = nil)
				return ">#{arg1},#{arg2},#{arg3}"
			end

			ndecl {
				args String, String, [String, nil], String
			}
			def some_string_method(arg1, arg2, arg3 = nil, *rest)
				return ">" + ([arg1, arg2, arg3] + rest).join(',')
			end

			ndecl {
				args Numeric, String, [true, false], (0..1)
			}
			def kw_method(arg1_num, *arg2_str, flag: false, rate: 1.0, **kwrest)
			end

		end

		@instance = @cls.new
	end

	test 'single String argument check is correct' do
		assert_equal(">abc", @instance.single_string_method("abc"))
		assert_equal(">", @instance.single_string_method(""))

		unexpected_values = [nil, true, 1, -1, Array, :test]
		expected_error_msg = %r|1st argument `arg1' of `#single_string_method' must be String|

		unexpected_values.each do |v|
			assert_raise_message(expected_error_msg) { @instance.single_string_method(v) }
		end
	end

	test 'multiple String arguments check is correct - basic valid' do
		assert_equal(">a,b,c", @instance.multiple_string_method("a", "b", "c"))
	end

	test 'multiple String arguments check is correct - basic invalid' do
		unexpected_values = [[nil, "", "", "1st"], ["", nil, "", "2nd"], [nil, nil, nil, "1st"]]
		unexpected_values.each do |v1, v2, v3, ord|
			expected_error_msg = %r|#{ord} argument `.+?' of `#multiple_string_method' must be String|
			assert_raise_message(expected_error_msg) { @instance.multiple_string_method(v1, v2, v3) }
		end
	end

	test 'multiple String arguments check is correct - omitted parameter check NOT skipped' do
		expected_error_msg = %r|3rd argument `.+?' of `#multiple_string_method_invalid' must be String|
		assert_raise_message(expected_error_msg) { @instance.multiple_string_method_invalid("", "") }
		assert_equal('>,,', @instance.multiple_string_method("", ""))
	end

	test 'some number String arguments check is correct' do
		expected_value = {["a", "b", "c"] => ">a,b,c", ["a", "b"] => ">a,b,", ["a", "b", "c", "d", "e"] => ">a,b,c,d,e"}
		expected_value.each do |params, expected_res|
			assert_nothing_raised { @instance.some_string_method(*params) }
			assert_equal(expected_res, @instance.some_string_method(*params))
		end
	end

	unexpected_values = {
		[nil, "", ""] => "1st",
		["", "", "", nil] => "4th",
		["", "", "", "", "", nil] => "6th",
	}
	unexpected_values.each_pair do |params, error_ord|
		test "some number String arguments check raises - #{params.inspect} => #{error_ord} argument raises " do
			expected_error_msg = %r|#{error_ord} argument `.+?' of `#some_string_method' must be String|
			assert_raise_message(expected_error_msg) { @instance.some_string_method(*params) }
		end
	end

end

# 戻り値のテスト
class ReturnValueTest < Test::Unit::TestCase

	test 'basic return value' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				returns String
			}
			def valid_method
				return 'ABC'
			end

			ndecl {
				returns String
			}
			def invalid_method
				return nil
			end
		end

		instance = cls.new
		assert_nothing_raised{ instance.valid_method }
		assert_raise(NeuronCheckError){ instance.invalid_method }
	end

	test 'returns self' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				returns :self
			}
			def valid_method
				return self
			end

			ndecl {
				returns :self
			}
			def invalid_method
				return nil
			end
		end

		instance = cls.new
		assert_nothing_raised{ instance.valid_method }
		assert_raise(NeuronCheckError){ instance.invalid_method }
	end
end

# 可変長引数とキーワード引数の混在パターン
class ComplexArgumentTest < Test::Unit::TestCase
	setup do
		@cls = Class.new
		@cls.class_eval do
			extend NeuronCheck

			ndecl {
				args Numeric, [String, nil], String, [true, false], (0..1), String
			}
			def kw_method(arg1_num, arg2_optional_str = nil, *arg3_str, flag: false, rate: 1.0, **kwrest)
			end

		end

		@instance = @cls.new
	end

	test "complex argument valid pattern" do
		assert_nothing_raised{ @instance.kw_method(100) }
		assert_nothing_raised{ @instance.kw_method(100, "A", "B") }
		assert_nothing_raised{ @instance.kw_method(100, "A", "B", flag: true) }
		assert_nothing_raised{ @instance.kw_method(100, "A", "B", rate: 0.7) }
		assert_nothing_raised{ @instance.kw_method(100, "A", "B", some_arg: "some") }
		assert_nothing_raised{ @instance.kw_method(100, "A", flag: true) }
		assert_nothing_raised{ @instance.kw_method(100, flag: true) }
	end

	patterns = []
	patterns << ["1st argument `arg1_num'", "Numeric", [""], {}]
	patterns << ["2nd argument `arg2_optional_str'", "String or nil", [20, 0], {}]
	patterns << ["6th argument `arg3_str'", "String", [20, "op", "A", "B", "C", nil], {}]
	patterns << ["argument `flag'", "true or false", [20, "op", "A", "B", "C"], {flag: nil}]
	patterns << ["argument `kwrest'", "String", [20, "op", "A", "B", "C"], {flag: true, some_arg1: '', some_arg2: 100}]

	patterns.each do |expected_arg_context, expected, args, kwargs|
		test "complex argument invalid pattern (args=#{args.inspect}, kwargs=#{kwargs.inspect})" do
			expected_error_msg = %r|#{expected_arg_context} of `#kw_method' must be #{expected}|
			assert_raise_message(expected_error_msg){
				@instance.kw_method(*args, **kwargs)
			}
		end
	end
end

# ブロック引数パターン
class BlockArgPattern < Test::Unit::TestCase
	setup do
		@cls = Class.new do
			extend NeuronCheck

			ndecl {
				args any
			}
			def method_arg0(&block)
			end

			ndecl {
				args String, any
			}
			def method_arg1(val1, &block)
			end

			ndecl {
				args String
			}
			def method_arg1_without_block_decl(val1, &block)
			end

			ndecl {
				args String, block
			}
			def method_arg1_with_block_type(val1, &block)
			end
		end

		@instance = @cls.new
	end

	test "block arg check is corrent" do
		assert_nothing_raised{ @instance.method_arg0 }
		assert_nothing_raised{ @instance.method_arg0{ 1 }  }
		assert_nothing_raised{ @instance.method_arg1('') }
		assert_nothing_raised{ @instance.method_arg1(''){ 1 } }
		assert_nothing_raised{ @instance.method_arg1_without_block_decl('') }
		assert_nothing_raised{ @instance.method_arg1_without_block_decl(''){ 1 } }
		assert_nothing_raised{ @instance.method_arg1_with_block_type('') }
		assert_nothing_raised{ @instance.method_arg1_with_block_type(''){ 1 } }
	end

	test "block arg invalid declarations" do
		assert_raise_message(/`block' of `#method_arg0' is block argument/) do
			Class.new do
				extend NeuronCheck

				ndecl {
					args String
				}
				def method_arg0(&block)
				end
			end
		end

		assert_raise_message(/`block' of `#method_arg0' is block argument/) do
			Class.new do
				extend NeuronCheck

				ndecl {
					args String, String
				}
				def method_arg0(v1, &block)
				end
			end
		end
	end
end


# 属性パターン
class AttrTest < Test::Unit::TestCase
	setup do
		@cls = Class.new do
			extend NeuronCheck

			ndecl {
				val String
			}
			attr_accessor :name1, :name2

		end

		@instance = @cls.new
	end

	test "name is settable only String" do
		assert_nothing_raised{ @instance.name1 = '' }
		assert_nothing_raised{ @instance.name2 = '' }
		assert_raise_message(/value of attribute `#name1' must be String/){ @instance.name1 = 11 }
		assert_raise_message(/value of attribute `#name2' must be String/){ @instance.name2 = 11 }
	end

	test "checked to get attribute" do
		assert_raise_message(/value of attribute `#name1' must be String/){ @instance.name1 }
		assert_raise_message(/value of attribute `#name2' must be String/){ @instance.name2 }
		@instance.name1 = ''
		@instance.name2 = ''
		assert_nothing_raised{ @instance.name1 }
		assert_nothing_raised{ @instance.name2 }
	end
end

# 属性パターン＋モジュール
class AttrModTest < Test::Unit::TestCase
	setup do
		module AttrModTest_Mod
			extend NeuronCheck

			ndecl {
				val String
			}
			attr_accessor :name1, :name2
		end

		class AttrModTest_Class
			include AttrModTest_Mod
		end

		@instance = AttrModTest_Class.new
	end

	test "module attribute is included" do
		assert_nothing_raised{ @instance.name1 = '' }
		assert_nothing_raised{ @instance.name2 = '' }
		assert_raise_message(/value of attribute `\S*#name1' must be String/){ @instance.name1 = 11 }
		assert_raise_message(/value of attribute `\S*#name2' must be String/){ @instance.name2 = 11 }
	end
end



# 各種特殊マッチャのテスト
class AdvancedMatcherTest < Test::Unit::TestCase
	test "except matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args except(nil)
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method([]) }
		assert_nothing_raised(){ inst.test_method(1) }
		assert_raise_message(%r|must be any value except nil|){ inst.test_method(nil) }
	end

	test "array_of matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args array_of(String)
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method([]) }
		assert_nothing_raised(){ inst.test_method(['1', '2', '5']) }
		assert_raise_message(%r|must be array of String|){ inst.test_method(['1', '2', 3]) }
		assert_raise_message(%r|must be array of String|){ inst.test_method(['1', '2', nil]) }
	end

	test "hash_of matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args hash_of(String, Integer)
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method('A' => 1) }
		assert_nothing_raised(){ inst.test_method({}) }
		assert_raise_message(%r|must be hash that has keys of String and values of Integer|){ inst.test_method(2 => 1) }
		assert_raise_message(%r|must be hash that has keys of String and values of Integer|){ inst.test_method(2 => 'V') }
		assert_raise_message(%r|must be hash that has keys of String and values of Integer|){ inst.test_method('a') }
		assert_raise_message(%r|must be hash that has keys of String and values of Integer|){ inst.test_method(nil) }
	end

	test "Range matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args 1..100
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method(1) }
		assert_nothing_raised(){ inst.test_method(100) }
		assert_raise_message(%r|must be included in 1\.\.100|){ inst.test_method(0) }
		assert_raise_message(%r|must be included in 1\.\.100|){ inst.test_method(101) }
		assert_raise_message(%r|must be included in 1\.\.100|){ inst.test_method('') }
	end

	test "Regexp matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args /[a]+/
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method('baac') }
		assert_nothing_raised(){ inst.test_method('a') }
		assert_raise_message(%r|must be String that matches with /\[a\]\+/|){ inst.test_method('d') }
		assert_raise_message(%r|must be String that matches with /\[a\]\+/|){ inst.test_method('') }
	end

	test "Any matcher" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args any
			}
			def test_method(arg1)
			end
		end

		inst = cls.new

		assert_nothing_raised(){ inst.test_method('baac') }
		assert_nothing_raised(){ inst.test_method('a') }
		assert_nothing_raised(){ inst.test_method(1) }
		assert_nothing_raised(){ inst.test_method(nil) }
	end
end

# initializeに対する定義のテスト
class InitializeDeclarationTest < Test::Unit::TestCase
	test "initialize declare" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args String
			}
			def initialize(arg1 = '')
			end
		end

		assert_nothing_raised(){ cls.new() }
		assert_nothing_raised(){ cls.new('a') }
		assert_raise_message(%r|1st argument `arg1' of `#initialize' must be String|){ cls.new(3) }
	end

	test "returns cannot be used in initialize declaration" do
		assert_raise(NeuronCheckSystem::DeclarationError) do
			cls = Class.new
			cls.class_eval do
				extend NeuronCheck

				ndecl {
					returns String
				}
				def initialize(arg1)
				end
			end
		end
	end
end

# 無効化テスト
class DisableTest < Test::Unit::TestCase
	def setup
		@cls = Class.new
		@cls.class_eval do
			extend NeuronCheck
			ndecl{
				args String
			}
			def foo_method(arg1)
			end
		end

		NeuronCheck.disable
		@instance = @cls.new
	end

	def teardown
		NeuronCheck.enable
	end

	test "enabled NeuronCheck raises nothing" do
		NeuronCheck.enable
		assert_raise(NeuronCheckError) do
			@instance.foo_method(:invalid)
		end
	end
	test "disabled NeuronCheck raises nothing" do
		assert_nothing_raised do
			@instance.foo_method(:invalid)
		end
	end
end

# 簡易宣言のテスト
# class ShortDeclarationTest < Test::Unit::TestCase
# 	test "short decl - args only" do
# 		cls = Class.new
# 		cls.class_eval do
# 			extend NeuronCheck
#
# 			ndecl String, String
# 			def test_method(arg1, arg2 = '')
# 			end
# 		end
#
# 		inst = cls.new
#
# 		assert_nothing_raised(){ inst.test_method('baac') }
# 		assert_nothing_raised(){ inst.test_method('a', '42') }
# 		assert_raise(NeuronCheckError){ inst.test_method('a', 1) }
# 	end
#
# 	test "short decl - args and returns" do
# 		cls = Class.new
# 		cls.class_eval do
# 			extend NeuronCheck
#
# 			ndecl String, String => /a/
# 			def test_method(arg1, arg2 = '')
# 				return arg1
# 			end
# 		end
#
# 		inst = cls.new
#
# 		assert_nothing_raised(){ inst.test_method('baac') }
# 		assert_nothing_raised(){ inst.test_method('a', '42') }
# 		assert_raise(NeuronCheckError){ inst.test_method('a', 1) }
# 		assert_raise(NeuronCheckError){ inst.test_method('b', 'a') }
# 	end
# end

# モジュールへの定義のテスト
class ModuleTest < Test::Unit::TestCase
	test 'module instance method' do
		module ModuleTest_Mod1
			extend NeuronCheck

			# インスタンスメソッド
			ndecl {
				args String
			}
			def test_method(name)
			end
		end

		class ModuleTest_Class1
			include ModuleTest_Mod1
		end

		instance = ModuleTest_Class1.new
		assert_nothing_raised{ instance.test_method('') }
		assert_raise_message(/ModuleTest_Mod1#test_method'/){ instance.test_method(1) }
	end

	test 'module function' do
		module ModuleTest_ModuleFunction_Mod
			extend NeuronCheck

			# モジュール関数
			module_function
			ndecl {
				args String
			}
			def test_func(name)
			end
		end

		class ModuleTest_ModuleFunction_Class
			include ModuleTest_ModuleFunction_Mod
		end

		instance = ModuleTest_ModuleFunction_Class.new
		assert_nothing_raised{ ModuleTest_ModuleFunction_Mod.test_func('') }
		assert_raise_message(/ModuleTest_ModuleFunction_Mod#test_func'/){ ModuleTest_ModuleFunction_Mod.test_func(1) }
		assert_nothing_raised{ instance.instance_eval{ test_func('') } }
		assert_raise_message(/ModuleTest_ModuleFunction_Mod#test_func'/){ instance.instance_eval{ test_func(1) } }
	end
end

# 特異メソッドのテスト
class SingletonTest < Test::Unit::TestCase
	test 'singleton method checkable with instance method' do
		class SingletonTestClass1
			extend NeuronCheck

			# 特異メソッド
			ndecl {
				args Numeric
			}
			def self.test_method(threshold)
			end

			# 同名のインスタンスメソッド
			ndecl {
				args String
			}
			def test_method(name)
			end
		end

		assert_nothing_raised{ SingletonTestClass1.test_method(1) }
		assert_raise_message(/SingletonTestClass1\.test_method'/){ SingletonTestClass1.test_method('') }

		instance = SingletonTestClass1.new
		assert_nothing_raised{ instance.test_method('') }
		assert_raise_message(/SingletonTestClass1#test_method'/){ instance.test_method(1) }
	end
end

# エイリアスのテスト
class AliasTest < Test::Unit::TestCase
	test 'aliasing will copy method body and NeuronCheck declaration' do
		cls = Class.new do
			extend NeuronCheck

			ndecl {
				args Numeric
			}
			def test_method1(threshold)
			end

			alias test_method2 test_method1
			alias test_method3 test_method1
		end

		instance = cls.new
		assert_nothing_raised{ instance.test_method1(1) }
		assert_raise(NeuronCheckError){ instance.test_method1('') }
		assert_nothing_raised{ instance.test_method2(1) }
		assert_raise(NeuronCheckError){ instance.test_method2('') }
		assert_nothing_raised{ instance.test_method3(1) }
		assert_raise(NeuronCheckError){ instance.test_method3('') }
	end
end

# 事前条件、事後条件のテスト
class PrePostCondTest < Test::Unit::TestCase
	test 'argument precond' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args Numeric
				precond do
					assert{ threshold >= 0 }
				end
			}
			def cond_method(threshold = 0)
			end
		end

		instance = cls.new
		assert_nothing_raised{ instance.cond_method }
		assert_raise(NeuronCheckError){ instance.cond_method(-1.2) }
	end

	test 'instance variable precond' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck
			attr_accessor :counter


			def initialize
				@counter = 0
			end

			ndecl {
				precond do
					assert{ @counter >= 1 }
				end
			}
			def cond_method
			end

			def counter_increment
				@counter += 1
			end
		end

		instance = cls.new

		# チェックエラー
		assert_raise(NeuronCheckError){ instance.cond_method }

		# 正常
		instance.counter_increment
		assert_nothing_raised{ instance.cond_method }
	end

	test 'result postcond' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				postcond do |ret|
					assert{ ret.kind_of?(String) }
				end
			}
			def postcond_method(arg1)
				return arg1
			end
		end

		instance = cls.new
		assert_nothing_raised{ instance.postcond_method('') }
		assert_raise(NeuronCheckError){ instance.postcond_method(-1.2) }
	end

	test 'instance variable postcond' do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck
			attr_accessor :counter


			def initialize
				@counter = 0
			end

			ndecl {
				postcond do |ret|
					# 2回目の実行の後であれば通るメソッド
					assert{ @counter >= 2 }
				end
			}
			def counter_increment
				@counter += 1
			end
		end

		instance = cls.new

		# チェックエラー (1回目)
		assert_raise(NeuronCheckError){ instance.counter_increment }

		# 正常
		assert_nothing_raised{ instance.counter_increment }
	end

	test 'instance method call forbidden in precond' do
		cls = Class.new do
			extend NeuronCheck

			ndecl {
				precond do
					counter_increment
				end
			}
			def cond_method
			end

			ndecl {
				precond(allow_instance_method: true) do
					counter_increment
				end
			}
			def cond_method2
			end

			ndecl {
				precond do
					unknown_meth
				end
			}
			def cond_method3
			end

			ndecl {
				precond(allow_instance_method: true) do
					unknown_meth
				end
			}
			def cond_method4
			end


			def counter_increment
				@counter ||= 0
				@counter += 1
			end
		end

		instance = cls.new

		# チェックエラー
		assert_raise_message(%r|instance method `counter_increment' cannot be called|){ instance.cond_method }
		assert_nothing_raised{ instance.cond_method2 }
		assert_raise_message(%r|undefined local variable or method `unknown_meth'|){ instance.cond_method3 }
		assert_raise_message(%r|undefined local variable or method `unknown_meth'|){ instance.cond_method4 }
	end
end

# 不正な宣言のテスト
class InvalidDeclarationTest < Test::Unit::TestCase
	# test "insufficient argument declaration" do
	# 	assert_raise(NeuronCheckSystem::ExceptionBase) do
	# 		class Foo1
	# 			extend NeuronCheck
	#
	# 			ndecl {
	# 				args String
	# 			}
	# 			def args_insuff(arg1, arg2)
	# 			end
	# 		end
	# 	end
	# end

	test "over argument declaration" do
		assert_raise(NeuronCheckSystem::DeclarationError) do
			class Foo2
				extend NeuronCheck

				ndecl {
					args String, String, String
				}
				def args_over(arg1, arg2)
				end
			end
		end
	end

	test "over argument complex declaration" do
		assert_nothing_raised do
			class Foo4
				extend NeuronCheck

				ndecl {
					args String, String, Numeric, [true, false]
					returns :self
				}
				def foo_method(arg1, arg2, *arg3, flag1: false)
					return self
				end
			end
		end
	end

	test "over argument declaration (with rest)" do
		assert_raise(NeuronCheckSystem::DeclarationError) do
			class Foo3
				extend NeuronCheck

				ndecl {
					args String, String, String
				}
				def args_over(arg1, *arg2)
				end
			end
		end
	end


end

# 2016年3月に発生した原因不明の不具合のテスト
class Bug201603Test < Test::Unit::TestCase
	test "return value become nil" do
		cls = Class.new
		cls.class_eval do
			extend NeuronCheck

			ndecl {
				args String, String, Numeric, [true, false]
				returns :self

				precond do
					assert{ arg2.length == 1 }
				end

				postcond do |ret|
					assert(ret)
				end
			}
			def foo_method(arg1, arg2 = 20, *arg3, flag1: false)
				return self
			end
		end

		inst = cls.new
		assert_raise(NeuronCheckSystem::DeclarationError){
			inst.foo_method("1", "2", 1, 2, 3, flag1: true)
		}
	end
end
