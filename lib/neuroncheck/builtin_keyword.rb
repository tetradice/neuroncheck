require 'neuroncheck/plugin'

# 組み込みキーワードの定義

# respondable: 指定した名前のメソッドが定義されている（メソッド呼び出しに応答可能である）ことを表す。Duck Typing用
NeuronCheckSystem::Plugin.add_keyword(:respondable) do
  def on_call(*method_names)
    @method_names = method_names
  end

  def match?(value)
    @method_names.all?{|x| value.respond_to?(x)}
  end

  def expected_caption
    in_cap = NeuronCheckSystem::Utils.string_join_using_or_conjunction(@method_names.map{|x| "##{x}"})  # 複数の文字列を結合し、orを使ったフレーズの形にするUtilityメソッド。 ['A', 'B', 'C'] => "A, B or C"
    "respondable to #{in_cap}"
  end

  def expected_short_caption
    'respondable(' + @method_names.map{|x| x.inspect}.join(', ') + ')'
  end

  def get_params_as_json
    {'expected' => @method_names.map(&:to_s)}
  end

  def self.builtin_keyword?
    true
  end
end

# respond_to, res: respondableのエイリアス
NeuronCheckSystem::Plugin.alias_keyword(:res, :respondable)

# any: すべての値を受け付ける
NeuronCheckSystem::Plugin.add_keyword(:any) do
  def on_call
  end

  def match?(value)
    true # 常にtrue
  end

  def expected_caption
    "any value"
  end

  def expected_short_caption
    "any"
  end

  def get_params_as_json
    {}
  end

  def self.builtin_keyword?
    true
  end
end

# block: ブロック引数用の特殊なキーワード。[Proc, nil]と同じ
NeuronCheckSystem::Plugin.add_keyword(:block) do
  def on_call
  end

  def match?(value)
    @api.expected_value_match?(value, [Proc, nil])
  end

  def expected_caption
    "block or nil"
  end

  def self.builtin_keyword?
    true
  end
end


# except: 指定した値以外を許可 (否定 / NOT)
NeuronCheckSystem::Plugin.add_keyword(:except) do
  def on_call(target)
    @target = target
  end

  def match?(value)
    not @api.expected_value_match?(value, @target)
  end

  def expected_caption
    "any value except #{@api.get_expected_value_caption(@target)}"
  end

  def expected_short_caption
    "except(#{@api.get_expected_value_short_caption(@target)})"
  end

  def get_params_as_json
    {'target' => @api.get_expected_value_meta_info_as_json(@target)}
  end

  def self.builtin_keyword?
    true
  end
end


# array_of: 指定した種類の値のみを格納した配列であることを表す
NeuronCheckSystem::Plugin.add_keyword(:array_of) do
  def on_call(item_expected)
    @item_expected = item_expected
  end

  def match?(value)
    return false unless value.kind_of?(Array) # まずは配列であるかどうかチェック

    # 配列であれば、1つ1つの値が型どおりであるかどうかをチェック
    return value.all?{|x| @api.expected_value_match?(x, @item_expected)}
  end

  def expected_caption
    "array of #{@api.get_expected_value_caption(@item_expected)}"
  end

  def get_params_as_json
    {'item' => @api.get_expected_value_meta_info_as_json(@item_expected)}
  end

  def self.builtin_keyword?
    true
  end
end


# hash_of: 指定した種類のキーと値のみを格納した配列であることを表す
NeuronCheckSystem::Plugin.add_keyword(:hash_of) do
  def on_call(key_expected, value_expected)
    @key_expected = key_expected
    @value_expected = value_expected
  end

  def match?(value)
    return false unless value.kind_of?(Hash) # まずはHashであるかどうかチェック

    # ハッシュであれば、1つ1つのキーと値をチェック
    return value.all?{|k, v| @api.expected_value_match?(k, @key_expected) and @api.expected_value_match?(v, @value_expected)}
  end

  def expected_caption
    "hash that has keys of #{@api.get_expected_value_caption(@key_expected)} and values of #{@api.get_expected_value_caption(@value_expected)}, #{expected_short_caption}"
  end

  def expected_short_caption
    "{#{@api.get_expected_value_short_caption(@key_expected)} => #{api.get_expected_value_short_caption(@value_expected)}}"
  end

  def get_params_as_json
    {'key' => @api.get_expected_value_meta_info_as_json(@key_expected), 'value' => @api.get_expected_value_meta_info_as_json(@value_expected)}
  end

  def self.builtin_keyword?
    true
  end
end
