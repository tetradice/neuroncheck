require 'neuroncheck/matcher'
require 'neuroncheck/plugin'
require 'neuroncheck/syntax'
require 'neuroncheck/builtin_keyword'

module NeuronCheckSystem
  # 宣言用のメソッドやメソッド追加時の処理を定義したモジュール。NeuronCheckを行いたい対象のモジュールやクラスにextendすることで使用する
  module DeclarationMethods
    # 宣言を実行
    def ndecl(*expecteds, &block)
      # 未初期化の場合、NeuronCheck用の初期化を自動実行
      unless @__neuron_check_initialized then
        NeuronCheckSystem.initialize_module_for_neuron_check(self)
      end

      # メイン処理実行
      __neuroncheck_ndecl_main(expecteds, block, caller(1, 1))
    end

    # ndeclのエイリアス
    alias ncheck ndecl
    alias ndeclare ndecl
    alias nsig ndecl
    alias ntypesig ndecl

    # ndeclのメイン処理
    def __neuroncheck_ndecl_main(expecteds, block, declared_caller_locations)
      # 2回連続で宣言された場合はエラー
      if @__neuron_check_last_declaration then
        raise DeclarationError, "repeated declarations - Declaration block and method definition must correspond one-to-one"
      end

      # ブロックが渡されたかどうかで処理を分岐
      if block then
        # ブロックが渡された場合
        __neuroncheck_ndecl_main_with_block(block, declared_caller_locations)
      else
        # 短縮記法はNeuronCheckSyntax使用可能時のみ
        unless defined?(NeuronCheckSyntax) then
          raise DeclarationError, "NeuronCheck shorthand syntax (without block) can be used only in Ruby 2.1 or later"
        end

        # ブロックが渡されていない場合 (短縮記法)
        __neuroncheck_ndecl_main_without_block(expecteds, declared_caller_locations)
      end
    end

    # ndeclの通常記法
    def __neuroncheck_ndecl_main_with_block(block, declared_caller_locations)
      # 宣言ブロック実行用のコンテキストを作成
      context = NeuronCheckSystem::DeclarationContext.new

      # 宣言ブロックの内容を実行
      context.instance_eval(&block)

      # 呼び出し場所を記憶
      context.declaration.declared_caller_locations = declared_caller_locations

      # 宣言の内容を「最後の宣言」として保持
      @__neuron_check_last_declaration = context.declaration
    end

    # ndeclの短縮記法
    def __neuroncheck_ndecl_main_without_block(expecteds, declared_caller_locations)
      # 宣言ブロック実行用のコンテキストを作成
      context = NeuronCheckSystem::DeclarationContext.new

      # 引数の解釈
      expected_args = nil
      expected_return = nil
      if expecteds.last.kind_of?(Hash) and expecteds.last.size == 1 then
        # expectedsの最後が、値が1つだけ格納されたHashであれば、キーを最後の引数、値を戻り値と解釈する
        # 例: String, String => Numeric
        last_hash = expecteds.pop
        expected_args = expecteds.concat([last_hash.keys.first])
        expected_return = last_hash.values.first
      else
        # 上記以外の場合はすべて引数と見なす
        expected_args = expecteds
      end

      # 引数1つで、かつ空配列が渡された場合は、「引数なし」と宣言されたとみなす
      if expected_args[0].kind_of?(Array) and expected_args.size == 1 then
        expected_args = []
      end

      # 簡易宣言を実行
      context.instance_eval do
        unless expected_args.empty? then
          args *expected_args
        end

        if expected_return then
          returns expected_return
        end
      end

      # 短縮記法フラグON
      context.declaration.shorthand = true

      # 呼び出し場所を記憶
      context.declaration.declared_caller_locations = declared_caller_locations
      context.declaration.arg_matchers.each do |matcher|
        matcher.declared_caller_locations = context.declaration.declared_caller_locations
      end
      if context.declaration.return_matcher then
        context.declaration.return_matcher.declared_caller_locations = context.declaration.declared_caller_locations
      end

      # 宣言の内容を「最後の宣言」として保持 (通常のndeclと同じ)
      @__neuron_check_last_declaration = context.declaration
    end
  end

  class DeclarationContext
    include Keywords
    attr_reader :declaration

    def initialize
      @declaration = Declaration.new
    end

    def args(*expecteds)
      declared_caller_locations = caller(1, 1)
      @declaration.arg_matchers = expecteds.map{|x| NeuronCheckSystem.get_appropriate_matcher(x, declared_caller_locations)}
    end

    def returns(expected)
      declared_caller_locations = caller(1, 1)
      @declaration.return_matcher = NeuronCheckSystem.get_appropriate_matcher(expected, declared_caller_locations)
    end

    def precond(allow_instance_method: false, &cond_block)
      @declaration.precond = cond_block
      @declaration.precond_allow_instance_method = allow_instance_method
    end

    def postcond(allow_instance_method: false, &cond_block)
      @declaration.postcond = cond_block
      @declaration.postcond_allow_instance_method = allow_instance_method
    end

    def val(expected)
      declared_caller_locations = caller(1, 1)
      @declaration.attr_matcher = NeuronCheckSystem.get_appropriate_matcher(expected, declared_caller_locations)
    end
    alias must_be val
    alias value val
  end

  class Declaration
    attr_accessor :arg_matchers
    attr_accessor :return_matcher
    attr_accessor :attr_matcher

    attr_accessor :precond
    attr_accessor :precond_allow_instance_method
    attr_accessor :postcond
    attr_accessor :postcond_allow_instance_method

    attr_accessor :assigned_class_or_module
    attr_accessor :assigned_method
    attr_accessor :assigned_singleton_original_class
    attr_accessor :assigned_attribute_name
    attr_accessor :shorthand
    attr_accessor :declared_caller_locations


    def initialize
      @arg_matchers = []
      @return_matcher = nil
      @attr_matcher = nil
      @precond = nil
      @precond_allow_instance_method = false
      @postcond = nil
      @postcond_allow_instance_method = false

      @assigned_class_or_module = nil
      @assigned_method = nil
      @assigned_singleton_original_class = nil
      @assigned_attribute_name = nil

      @shorthand = false
      @declared_caller_locations = nil
    end

    def attribute?
      (@assigned_attribute_name ? true : false)
    end

    def assinged_to_toplevel_method?
      @assigned_class_or_module == Object
    end
    def assinged_to_singleton_method?
      @assigned_singleton_original_class
    end

    # メソッド名/属性名の表記文字列を取得
    def signature_caption_name_only
      if @assigned_class_or_module and (@assigned_method or attribute?) then
        ret = ""

        # 属性、特異メソッド、インスタンスメソッドのそれぞれで処理を分岐
        if attribute? then
          if @assigned_class_or_module.name then
            ret << @assigned_class_or_module.name
          end

          # 属性名出力
          ret << "##{@assigned_attribute_name}"

        elsif assinged_to_toplevel_method? then
          # メソッド名出力
          ret << "#{@assigned_method.name}"

        elsif assinged_to_singleton_method? then
          if @assigned_singleton_original_class.name then
            ret << @assigned_singleton_original_class.name
          end

          # メソッド名出力
          ret << ".#{@assigned_method.name}"
        else
          if @assigned_class_or_module.name then
            ret << @assigned_class_or_module.name
          end

          # メソッド名出力
          ret << "##{@assigned_method.name}"
        end
      else
        nil
      end
    end

    # メソッド名/属性名＋引数＋戻り値の表記文字列を取得
    def signature_caption
      ret = signature_caption_name_only
      if ret then
        if attribute? then

          if @attr_matcher then
            ret << " -> #{@attr_matcher.expected_short_caption}"
          end
        else

          # 引数出力
          unless @assigned_method.parameters.empty? then
            ret << "("
            @assigned_method.parameters.each_with_index do |param_info, i|
              _, param_name = param_info
              if i >= 1 then
                ret << ", "
              end

              if (matcher = @arg_matchers[i]) then
                ret << "#{param_name}:#{matcher.expected_short_caption}"
              else
                ret << "#{param_name}:any"
              end
            end
            ret << ")"
          end

          if @return_matcher then
            ret << " -> #{@return_matcher.expected_short_caption}"
          end
        end

        return ret
      else
        nil
      end
    end

    def meta_info_as_json
      re = {}

      if attribute? then
        re['value'] = (@attr_matcher ? @attr_matcher.meta_info_as_json : nil)
        re['signature_caption'] = signature_caption
        re['signature_caption_name_only'] = signature_caption_name_only
      else
        re['args'] = @arg_matchers.map{|x| x.meta_info_as_json}
        re['returns'] = (@return_matcher ? @return_matcher.meta_info_as_json : nil)
        re['signature_caption'] = signature_caption
        re['signature_caption_name_only'] = signature_caption_name_only
      end
      re['precond_source_location'] = (@precond ? @precond.source_location : nil)
      re['postcond_source_location'] = (@postcond ? @postcond.source_location : nil)

      re
    end
  end
end
