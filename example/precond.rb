require 'neuroncheck'

class Foo
  extend NeuronCheck

  def initialize
    @file_loaded = false
  end

  ndecl {
    args String

    # 事前条件
    precond do
      # 引数「name」の文字数が10を超えていないかかどうかを判定。10を超えていればエラー
      #  (引数チェックをクリアしているため、Stringであることは保証されている)
      assert{ name.length <= 10 }

      # インスタンス変数「@file_loaded」がtrueであるかどうかを判定。falseやnilであればエラー
      assert{ @file_loaded }
    end

    # 事後条件
    postcond do |ret|
      # 戻り値が
    end
  }
  def foo_method(name)
    # メイン処理
  end
end

inst1 = Foo.new
inst1.foo_method('therubyracer')  # 引数nameが10文字を超えているためエラーとなる
inst1.foo_method('rubyracer')     # 引数nameは10文字以内に収まっているが、この時点で@file_loadedがfalseのため、やはりエラーとなる

#=> script.rb:34:in `<main>': precond assertion failed (NeuronCheckError)
#     asserted at: script.rb:17:in `block (2 levels) in <class:Foo>'
#   
