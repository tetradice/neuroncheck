$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'test/unit'
require 'neuroncheck'

class KeywordPluginTest < Test::Unit::TestCase
	def setup
		NeuronCheckSystem::Plugin.add_keyword(:boolean) do
		  def on_call
		  end

		  def match?(value)
		    value.equal?(true) or value.equal?(false)
		  end

		  def expected_caption
		    "boolean value"
		  end
		end

		NeuronCheckSystem::Plugin.add_keyword(:sized_array) do
			def on_call(size)
				@expected_size = size
			end

			def match?(value)
				value.kind_of?(Array) and value.size == @expected_size
			end

			def expected_caption
				"#{@expected_size} items array"
			end
		end
	end

	def teardown
		NeuronCheckSystem::Plugin.remove_keyword(:boolean)
		NeuronCheckSystem::Plugin.remove_keyword(:sized_array)
	end


	test "usable added keyword (boolean)" do
		cls = Class.new do
			extend NeuronCheck

			ndecl {
				args boolean
			}

			def test_method(flag = false)
			end
		end

		inst = cls.new
		assert_nothing_raised{ inst.test_method }
		assert_nothing_raised{ inst.test_method(false) }
		assert_nothing_raised{ inst.test_method(true) }
		assert_raise_message(/must be boolean value/){ inst.test_method('1') }
	end

	test "usable added keyword (sized_array)" do
		cls = Class.new do
			extend NeuronCheck

			ndecl {
				args sized_array(3)
			}

			def test_method(tags)
			end
		end

		inst = cls.new
		assert_nothing_raised{ inst.test_method(['a', 'b', 'c']) }
		assert_raise_message(/must be 3 items array/){ inst.test_method(nil) }
		assert_raise_message(/must be 3 items array/){ inst.test_method(['1']) }
	end
end


class InvalidKeywordTest < Test::Unit::TestCase

	test "builtin keyword cannot be overriden" do
		assert_raise(NeuronCheckSystem::PluginError){
			NeuronCheckSystem::Plugin.add_keyword(:array_of) do
			end
		}
	end
end
