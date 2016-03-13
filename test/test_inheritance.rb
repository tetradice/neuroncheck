$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'test/unit'
require 'neuroncheck'

# 継承時のチェック
class InheritanceTest < Test::Unit::TestCase
	def setup
		parent_cls = Class.new do
			extend NeuronCheck

			ndecl {
				args /a/
				returns /A/
			}
			def test1(name, ret)
				ret
			end

			ndecl {
				args /c/
				returns /C/
			}
			def test2_only_parent(name, ret)
				ret
			end


			ndecl {
				precond do
					assert{arg1 =~ /a/}
				end

				postcond do |ret|
					assert{ret =~ /A/}
				end
			}
			def cond_test1(arg1, ret1)
				ret1
			end

			ndecl {
				val String
			}
			attr_accessor :attr1
		end

		child_cls = Class.new(parent_cls) do
			extend NeuronCheck

			ndecl {
				args /b/
				returns /B/
			}
			def test1(name, ret = 'ABC')
				super

				ret
			end

			ndecl {
				precond do
					assert{ arg1 =~ /b/ }
				end

				postcond do |ret|
					assert{ ret =~ /B/ }
				end
			}
			def cond_test1(arg1, ret1 = 'ABC')
				super

				ret1
			end
		end

		@parent_inst = parent_cls.new
		@inst = child_cls.new
	end

	# 親の引数チェックを引き継ぐ
	test 'arguments check inherited by superclass' do
		assert_raise(NeuronCheckError){ @inst.test1(nil) }
		assert_raise(NeuronCheckError){ @inst.test1('') }
		assert_raise(NeuronCheckError){ @inst.test1('a123') }
		assert_raise(NeuronCheckError){ @inst.test1('b123') }
		assert_nothing_raised{ @inst.test1('a123b') }
	end

	# 親の引数チェックを引き継ぐ (子で再定義されていない場合)
	test 'arguments check inherited by superclass (without child overridding)' do
		assert_raise(NeuronCheckError){ @inst.test2_only_parent('c', 10) }
		assert_raise(NeuronCheckError){ @inst.test2_only_parent('a', 'C') }
		assert_nothing_raised{ @inst.test2_only_parent('c', 'C') }
	end

	# 親の戻り値チェックを引き継ぐ
	test 'results check inherited by superclass' do
		assert_raise(NeuronCheckError){ @inst.test1('ab', 'AC') }
		assert_raise(NeuronCheckError){ @inst.test1('ab', 'BC') }
		assert_nothing_raised{ @inst.test1('ab', 'aaABC') }
	end
	# 親の事前条件チェックを引き継ぐ
	test 'precond check inherited by superclass' do
		assert_raise(NeuronCheckError){ @inst.cond_test1(nil) }
		assert_raise(NeuronCheckError){ @inst.cond_test1('') }
		assert_raise(NeuronCheckError){ @inst.cond_test1('a123') }
		assert_raise(NeuronCheckError){ @inst.cond_test1('b123') }
		assert_nothing_raised{ @inst.cond_test1('a123b') }
	end

	# 親の事後条件チェックを引き継ぐ
	test 'postcond check inherited by superclass' do
		assert_raise(NeuronCheckError){ @inst.cond_test1('ab', 'AC') }
		assert_raise(NeuronCheckError){ @inst.cond_test1('ab', 'BC') }
		assert_nothing_raised{ @inst.cond_test1('ab', 'aaABC') }
	end

	# 親の属性チェックを引き継ぐ
	test 'attribute check inherited by superclass' do
		assert_raise(NeuronCheckError){ @inst.attr1 = 30 }
		assert_nothing_raised{ @inst.attr1 = '1s' }
	end
end

# 親と子でそれぞれ別々にextendした場合
class InheritanceOtherExtendTest < Test::Unit::TestCase

	# 親のみextend
	test 'extend only Parent' do
		par_cls = Class.new do
			extend NeuronCheck

			ndecl {
				args String
			}
			def foo_method(str1)
			end
		end

		chd_cls = Class.new(par_cls) do
			ndecl {
				args String
			}
			def bar_method(str2)
			end
		end

		chd = chd_cls.new
		assert_raise(NeuronCheckError){ chd.foo_method(1) }
		assert_raise(NeuronCheckError){ chd.bar_method(2) }
	end

end
