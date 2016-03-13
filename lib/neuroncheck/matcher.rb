require 'neuroncheck/error'
require 'neuroncheck/utils'
require 'neuroncheck/plugin'

module NeuronCheckSystem
  # 期待する値に対応する、適切なマッチャを取得
  def self.get_appropriate_matcher(expected, declared_caller_locations)
    case expected
    when DeclarationContext # 誤って「self」と記載した場合
      raise DeclarationError, "`self` cannot be used in declaration - use `:self` instead"
    when :self # self
      SelfMatcher.new(declared_caller_locations) # 値がselfであるかどうかチェック

    when String, Symbol, Integer
      ValueEqualMatcher.new(expected, declared_caller_locations) # 値が等しいかどうかをチェック
    when true, false, nil
      ObjectIdenticalMathcer.new(expected, declared_caller_locations) # オブジェクトが同一かどうかをチェック
    when Class, Module
      KindOfMatcher.new(expected, declared_caller_locations) # 所属/継承しているかどうかをチェック
    when Range
      RangeMatcher.new(expected, declared_caller_locations) # 範囲チェック
    when Regexp
      RegexpMatcher.new(expected, declared_caller_locations) # 正規表現チェック
    # when Encoding
    #   EncodingMatcher.new(expected, declared_caller_locations) # エンコーディングチェック

    when Array
      OrMatcher.new(expected, declared_caller_locations) # ORチェック

    when Plugin::Keyword # プラグインによって登録されたキーワードの場合
      KeywordPluginMatcher.new(expected, declared_caller_locations)

    else
      raise DeclarationError, "#{expected.class.name} cannot be usable for NeuronCheck check parameter\n  value: #{expected.inspect}"
    end

  end

  class MatcherBase
    attr_accessor :declared_caller_locations

    def initialize(expected, declared_caller_locations)
      @expected = expected
      @declared_caller_locations = declared_caller_locations
    end

    def match?(value, self_object)
      raise NotImplementedError
    end

    def get_error_message(signature_decl, context_caption, value, phrase_after_but: 'was')
      locs = Utils.backtrace_locations_to_captions(@declared_caller_locations)

      ret = ""
      ret.concat(<<MSG)
#{context_caption} must be #{expected_caption}, but #{phrase_after_but} #{Utils.truncate(value.inspect, 40)}
          got: #{value.inspect}
MSG

      if signature_decl and signature_decl.assigned_method then
        ret.concat(<<MSG)
    signature: #{signature_decl.signature_caption}
MSG
      end

      if locs.size >= 1 then
        ret.concat(<<MSG)
  declared at: #{locs.join("\n" + ' ' * 15)}

MSG
      end

      ret
    end

    def expected_caption
      raise NotImplementedError
    end

    def expected_short_caption
      @expected.inspect
    end

    def meta_info_as_json
      re = {}
      re['type'] = self.class.name.split('::')[-1]
      re['expected'] = @expected

      re
    end
  end

  # 値が == で等しいことを判定する
  class ValueEqualMatcher < MatcherBase
    def match?(value, self_object)
      @expected == value
    end

    def expected_caption
      @expected.inspect
    end
  end

  # オブジェクトとして同一であることを判定する
  class ObjectIdenticalMathcer < MatcherBase
    def match?(value, self_object)
      @expected.equal?(value)
    end

    def expected_caption
      @expected.inspect
    end
  end

  # 値が指定されたClass / Moduleに所属していることを判定する (kind_of?判定)
  class KindOfMatcher < MatcherBase
    def match?(value, self_object)
      value.kind_of?(@expected)
    end

    def expected_caption
      @expected.name
    end

    def meta_info_as_json
      super.update('expected' => @expected.name)
    end
  end


  # 指定した範囲に含まれている値であることを判定する
  class RangeMatcher < MatcherBase
    def match?(value, self_object)
      @expected.include?(value)
    end

    def expected_caption
      "included in #{@expected.inspect}"
    end
  end

  # 指定した正規表現にマッチする文字列であることを判定する
  class RegexpMatcher < MatcherBase
    def match?(value, self_object)
      (value.kind_of?(String) and @expected =~ value)
    end

    def expected_caption
      "String that matches with #{@expected.inspect}"
    end
  end

  # # 指定したエンコーディングを持つ文字列であることを判定する
  # class EncodingMatcher < MatcherBase
  #   def match?(value, self_object)
  #     (value.kind_of?(String) and Encoding.compatible?(value, @expected))
  #   end
  #
  #   def expected_caption
  #     "String that is compatible #{@expected.name} encoding"
  #   end
  #
  #   def expected_short_caption
  #     "String compatible to #{@expected.name}"
  #   end
  #
  # end

  # OR条件。渡されたマッチャ複数のうち、どれか1つでも条件を満たせばOK
  class OrMatcher < MatcherBase
    def initialize(child_expecteds, declared_caller_locations)
      @child_matchers = child_expecteds.map{|x| NeuronCheckSystem.get_appropriate_matcher(x, declared_caller_locations)}
      @declared_caller_locations = declared_caller_locations
    end

    def match?(value, self_object)
      # どれか1つにマッチすればOK
      @child_matchers.any?{|x| x.match?(value, self_object)}
    end

    def expected_caption
      captions = @child_matchers.map{|x| x.expected_caption}

      Utils.string_join_using_or_conjunction(captions)
    end
    def expected_short_caption
      '[' + @child_matchers.map{|x| x.expected_short_caption}.join(', ') + ']'
    end

    def meta_info_as_json
      super.update('child_matchers' => @child_matchers.map{|x| x.meta_info_as_json})
    end
  end


  # selfであるかどうかを判定 (通常はreturns用)
  class SelfMatcher < MatcherBase
    def initialize(declared_caller_locations)
      @declared_caller_locations = declared_caller_locations
    end

    def match?(value, self_object)
      self_object.equal?(value)
    end

    def expected_caption
      "self"
    end
    def expected_short_caption
      "self"
    end
  end

  # プラグインで追加されたキーワード用
  class KeywordPluginMatcher < MatcherBase
    def initialize(keyword, declared_caller_locations)
      @keyword = keyword
      @declared_caller_locations = declared_caller_locations
    end

    def match?(value, self_object)
      @keyword.api = Plugin::KeywordAPI.new(@declared_caller_locations, self_object)
      @keyword.match?(value)
    end

    def expected_caption
      @keyword.api = Plugin::KeywordAPI.new(@declared_caller_locations)
      @keyword.expected_caption
    end

    def expected_short_caption
      @keyword.api = Plugin::KeywordAPI.new(@declared_caller_locations)
      @keyword.expected_short_caption
    end

    def meta_info_as_json
      @keyword.api = Plugin::KeywordAPI.new(@declared_caller_locations)
      super.update('keyword' => keyword_name, 'expected_caption' => expected_caption).tap{|x| x.delete('expected')}.update(@keyword.get_params_as_json)
    end

    def keyword_name
      (@keyword.class).instance_variable_get(:@keyword_name).to_s
    end
  end
end
