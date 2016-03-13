$LOAD_PATH << File.join(File.dirname(__FILE__), '../lib')
require 'test/unit'
require 'neuroncheck'
using NeuronCheckSyntax

# NeuronCheckSyntaxの標準テスト
class SyntaxStandardTest < Test::Unit::TestCase

  test 'standard syntax use' do
    cls = Class.new
    cls.class_eval do
      ndecl String
      def met1(val)
        return 'ABC'
      end

      ndecl String => String
      def met2(val)
        return 'A'
      end

      ndecl String => String
      def met2_invalid(val)
        return nil
      end

      ndecl any
      def met3_any(val)
        return nil
      end

      ndecl except(nil)
      def met4_not_nil(val)
        return nil
      end

      ndecl [] => nil
      def met5_no_arg
        return nil
      end

      ndecl [] => :self
      def met6_returns_self(passed)
        return passed
      end
    end

    instance = cls.new
    assert_nothing_raised{ instance.met1('A') }
    assert_raise(NeuronCheckError){ instance.met1(nil) }
    assert_nothing_raised{ instance.met2('A') }
    assert_raise(NeuronCheckError){ instance.met2(nil) }
    assert_raise(NeuronCheckError){ instance.met2_invalid('A') }
    assert_nothing_raised{ instance.met3_any(nil) }

    assert_raise(NeuronCheckError){ instance.met4_not_nil(nil) }
    assert_nothing_raised{ instance.met4_not_nil(1) }
    assert_nothing_raised{ instance.met5_no_arg }

    assert_raise(NeuronCheckError){ instance.met6_returns_self(1) }
    assert_raise(NeuronCheckError){ instance.met6_returns_self(cls.new) }
    assert_nothing_raised{ instance.met6_returns_self(instance) }

  end

  # トップレベルでもなく、モジュールでもクラスでもない場所でndeclを使ったらエラー
  test 'ndecl is usable only in module or toplevel' do
    assert_raise do
      Object.new.instance_eval do
        ndecl
      end
    end

    assert_raise do
      cls = Class.new do
        def test_met
          ndecl
        end
      end

      cls.new.test_met
    end
  end

  # ブロックの不正宣言エラーが同じように発生するかのチェック
  test 'invalid block argument decl' do
    assert_raise_message(/`block' of `#method_arg0' is block argument/) do
      Class.new do
        ndecl {
          args String
        }
        def method_arg0(&block)
        end
      end
    end

    assert_raise_message(/`block' of `#method_arg0' is block argument/) do
      Class.new do
        ndecl {
          args String, String
        }
        def method_arg0(v1, &block)
        end
      end
    end
  end
end

# 継承時のチェック_Syntax版
class InheritanceWithSyntaxTest < Test::Unit::TestCase
  def setup
    parent_cls = Class.new do

      ndecl /a/ => /A/
      def test1(name, ret)
        ret
      end

      ndecl /c/ => /C/
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

      ndecl String
      attr_accessor :attr1
    end

    child_cls = Class.new(parent_cls) do

      ndecl /b/ => /B/
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

# 親と子でそれぞれ別々にextendした場合_Syntax版
class InheritanceOtherExtendWithSyntaxTest < Test::Unit::TestCase

  # 親のみextend
  test 'extend only Parent' do
    par_cls = Class.new do
      ndecl String
      def foo_method(str1)
      end
    end

    chd_cls = Class.new(par_cls) do
      ndecl String
      def bar_method(str2)
      end
    end

    chd = chd_cls.new
    assert_raise(NeuronCheckError){ chd.foo_method(1) }
    assert_raise(NeuronCheckError){ chd.bar_method(2) }
  end
end
