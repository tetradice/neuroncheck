require 'neuroncheck'

NeuronCheckSystem::Plugin.add_keyword(:boolean) do
  # キーワードを使用したときに呼び出されるメソッド。引数を付けてキーワードを呼んだ場合は、それもon_callメソッドの引数として渡される
  def on_call
  end

  # 実際のチェック処理を実行するメソッド。trueかfalseのいずれかを返す必要がある
  def match?(value)
    value.equal?(true) or value.equal?(false)
  end

  # そのキーワードの内容を表す文字列。エラーメッセージで使用される
  def expected_caption
    "boolean value"
  end
end

module Foo
  extend NeuronCheck
  ndecl {
    args boolean
  }
  def self.foo_func(flag: false)
  end
end


Foo.foo_func
Foo.foo_func(flag: 'invalid')

#=> script.rb:30:in `<main>': argument `flag' of `Foo.foo_func' must be boolean value, but was "invalid" (NeuronCheckError)
#             got: "invalid"
#       signature: Foo.foo_func(flag:boolean value)
#     declared at: script.rb:22:in `block in <module:Foo>'
#   
