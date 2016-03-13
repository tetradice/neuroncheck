$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'test/unit'
require 'neuroncheck'

# スクリプトエラーのチェック
class ScriptErrorTest < Test::Unit::TestCase
  # 二重に定義することはできない
  test 'double declaration' do
    assert_raise(NeuronCheckSystem::DeclarationError) do
      module Foo2
        extend NeuronCheck

        ndecl {
        }

        ndecl {
        }
      end
    end
  end
end

# ndeclを複数回定義してもエラーにならないことと、1回しか呼ばれないことをチェック
class MultipleDeclareTest <  Test::Unit::TestCase
  def self.counter; @counter; end
  def self.counter=(v); @counter = v; end
  test "" do
    cls = Class.new
    MultipleDeclareTest.counter = 0

    assert_nothing_raised(NeuronCheckSystem::DeclarationError){
      cls.class_eval do
        extend NeuronCheck

        3.times do
          ndecl {
            args String
          }

          def foo_method(arg)
            MultipleDeclareTest.counter += 1
          end
        end
      end
    }

    cls.new.foo_method('')
    assert_equal(1, MultipleDeclareTest.counter)

    assert_raise(NeuronCheckError){
      cls.new.foo_method(1)
    }
  end
end

# もともとmethod_addedが定義されていたときに両方とも呼ばれるかどうかのチェック
class MethodAddedPreservedTest < Test::Unit::TestCase
  test 'define method_added -> extend NeuronCheck' do
    class Foo3
      def self.original_method_added_called; @original_method_added_called; end
      def self.method_added(name)
        super
        @original_method_added_called = true
      end
      extend NeuronCheck

      ndecl {
        args String
      }
      def foo3_method(arg1)
      end
    end

    assert(Foo3.original_method_added_called)

    assert_raise(NeuronCheckError) do
      Foo3.new.foo3_method(nil)
    end
  end
end


# もともとsingleton_method_addedが定義されていたときに呼ばれるかどうかのチェック
class SingletonMethodAddedPreservedTest < Test::Unit::TestCase
  test 'define method_added -> extend NeuronCheck' do
    class Foo1
      def self.original_singleton_method_added_called; @original_singleton_method_added_called; end
      def self.original_singleton_method_added_called=(v); @original_singleton_method_added_called = v; end

      def self.singleton_method_added(name)
        @original_singleton_method_added_called = true
      end

      extend NeuronCheck

      ndecl {
        args String
      }
      def foo1_method(arg1)
      end
    end

    Foo1.original_singleton_method_added_called = false
    def Foo1.test1
      p 1
    end
    assert{ Foo1.original_singleton_method_added_called }

    assert_raise(NeuronCheckError) do
      Foo1.new.foo1_method(nil)
    end
  end
end

# 複数回extendしても例外は発生しないか？
class MultipleExtendTest < Test::Unit::TestCase
  test 'define method_added -> extend NeuronCheck' do
     assert_nothing_raised do
      module Foo3
        extend NeuronCheck
        extend NeuronCheck
      end
    end
  end
end
