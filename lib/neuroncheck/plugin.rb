module NeuronCheckSystem
	# 追加されたキーワード全てが動的に定義されていくモジュール
	module Keywords
	end

	module Plugin

		# NeuronCheckへ登録したキーワード(Symbol)と、それに対応するKeywordクラスの対応を格納したマップ
		KEYWORD_CLASSES = {}

		# キーワードの追加
		def self.add_keyword(name, &block)
			# すでに予約済みのキーワードであればエラー
			if KEYWORD_CLASSES[name] then
				raise PluginError, "the `#{name}' keyword has been already reserved"
			end

			# キーワードを表すクラスを作成
			keyword_class = Class.new(Keyword, &block)

			# 必要なインスタンスメソッドが全て定義されているかどうかを確認
			if not keyword_class.method_defined?(:on_call) or
			not keyword_class.method_defined?(:match?) or
			not keyword_class.method_defined?(:expected_caption) then
				raise PluginError, "##{__callee__} requires 3 method definitions - `on_call', `match?' and `expected_caption'"
			end

			# キーワードを登録
			keyword_class.instance_variable_set(:@keyword_name, name)
			KEYWORD_CLASSES[name] = keyword_class

			# キーワードメソッドを定義
			__define_keyword_method_to_module(name, keyword_class)
		end

		# キーワードの別名を定義
		def self.alias_keyword(name, original_keyword_name)
			# すでに予約済みのキーワードであればエラー
			if KEYWORD_CLASSES[name] then
				raise PluginError, "the `#{name}' keyword has been already reserved"
			end

			# 元キーワードが、自分が追加したキーワードの中になければエラー
			unless KEYWORD_CLASSES[original_keyword_name] then
				raise PluginError, "the `#{original_keyword_name}' keyword hasn't been reserved yet"
			end

			# 継承して別名クラスを作成
			keyword_class = Class.new(KEYWORD_CLASSES[original_keyword_name])
			keyword_class.instance_variable_set(:@keyword_name, name)
			KEYWORD_CLASSES[name] = keyword_class

			# キーワードメソッドを定義
			__define_keyword_method_to_module(name, keyword_class)
		end

		# キーワード用のメソッドをKeywordモジュールへ定義する
		def self.__define_keyword_method_to_module(name, keyword_class)
			Keywords.module_eval do
				define_method(name) do |*params|
					# キーワードを生成
					kw = keyword_class.new

					# そのキーワードのon_callメソッドを実行
					kw.on_call(*params)

					# キーワードを返す
					kw
				end
			end
		end

		# キーワードの削除
		def self.remove_keyword(name)
			# 自分が追加したキーワードの中になければエラー
			unless KEYWORD_CLASSES[name] then
				raise PluginError, "the `#{name}' keyword hasn't been reserved yet"
			end

			# 組み込みキーワードを削除使用とした場合はエラー
			if KEYWORD_CLASSES[name].builtin_keyword? then
				raise PluginError, "the `#{name}' keyword cannot be removed because it is NeuronCheck builtin keyword"
			end

			# キーワードを表すクラスを削除
			KEYWORD_CLASSES.delete(name)

			# キーワードメソッドの定義を削除
			Keywords.module_eval do
				remove_method(name)
			end
		end

		# キーワードクラス
		class Keyword
			attr_accessor :api

			def expected_short_caption
		    expected_caption
		  end

			def get_params_as_json
		    {}
		  end

			def self.builtin_keyword?
				false
			end
		end

		# キーワードの処理内で使用可能なAPI
		class KeywordAPI
			def initialize(declared_caller_locations, method_self_object = nil)
				@declared_caller_locations = declared_caller_locations
				@method_self_object = method_self_object
			end

			def get_appropriate_matcher(expected_value)
				NeuronCheckSystem.get_appropriate_matcher(expected_value, @declared_caller_locations)
			end

			def expected_value_match?(value, expected_value)
				get_appropriate_matcher(expected_value).match?(value, @method_self_object)
			end

			def get_expected_value_caption(expected_value)
				get_appropriate_matcher(expected_value).expected_caption

			end

			def get_expected_value_short_caption(expected_value)
				get_appropriate_matcher(expected_value).expected_short_caption

			end

			def get_expected_value_meta_info_as_json(expected_value)
				get_appropriate_matcher(expected_value).meta_info_as_json

			end
		end
	end
end

module NeuronCheck
	# プラグイン有効化
	def self.enable_plugin(plugin_name)
		require "neuroncheck/plugin/#{plugin_name}"
	end
end
