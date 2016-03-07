require 'neuroncheck/version'
require 'neuroncheck/utils'
require 'neuroncheck/declaration'
require 'neuroncheck/cond_block'
require 'neuroncheck/plugin'
require 'neuroncheck/syntax'

module NeuronCheckSystem
	# メソッド追加時のフック処理や、属性宣言メソッドのオーバーライドなどを定義したメインモジュール
	# NeuronCheckを行いたい対象のモジュールやクラスにextendすることで使用する
	module Kernel
		# 属性定義
		def attr(name, assignable = false)
			@__neuron_check_method_added_hook_enabled = false
			begin
				# 元処理を呼ぶ
				super

				# NeuronCheck用の属性定義時処理を呼ぶ
				__neuron_check_attr_defined(__method__, [name], use_reader: true, use_writer: assignable)
			ensure
				@__neuron_check_method_added_hook_enabled = true
			end
		end

		def attr_reader(*names)
			@__neuron_check_method_added_hook_enabled = false
			begin
				# 元処理を呼ぶ
				super

				# NeuronCheck用の属性定義時処理を呼ぶ
				__neuron_check_attr_defined(__method__, names, use_reader: true, use_writer: false)
			ensure
				@__neuron_check_method_added_hook_enabled = true
			end
		end

		def attr_writer(*names)
			@__neuron_check_method_added_hook_enabled = false
			begin
				# 元処理を呼ぶ
				super

				# NeuronCheck用の属性定義時処理を呼ぶ
				__neuron_check_attr_defined(__method__, names, use_reader: false, use_writer: true)
			ensure
				@__neuron_check_method_added_hook_enabled = true
			end
		end

		def attr_accessor(*names)
			@__neuron_check_method_added_hook_enabled = false
			begin
				# 元処理を呼ぶ
				super

				# NeuronCheck用の属性定義時処理を呼ぶ
				__neuron_check_attr_defined(__method__, names, use_reader: true, use_writer: true)
			ensure
				@__neuron_check_method_added_hook_enabled = true
			end
		end

		def __neuron_check_attr_defined(used_method_name, names, use_reader: false, use_writer: false)
			# 直前にNeuronCheck宣言部があれば、その宣言内容を各メソッドへ登録する
			if (declaration = @__neuron_check_last_declaration) then
				# 短縮記法による宣言かどうかで分岐
				if declaration.shorthand then
					# 短縮記法の場合は、引数が2つ以上宣言されている、もしくは戻り値が宣言されている場合にエラーとする
					if declaration.arg_matchers.size >= 2 or declaration.return_matcher then
						raise NeuronCheckSystem::DeclarationError, "expected value must be one for `#{used_method_name}'", declaration.declared_caller_locations
					end

					# 引数1用のマッチャを属性用のマッチャとみなす
					target_attr_matcher = declaration.arg_matchers[0]
				else
					# 通常の宣言の場合、引数、戻り値の宣言がされている場合はエラーとする
					if declaration.arg_matchers.size >= 1 or declaration.return_matcher then
						raise NeuronCheckSystem::DeclarationError, "`args' or `returns' declaration can be used only for method definition, but used for `#{used_method_name}'", declaration.declared_caller_locations
					end

					target_attr_matcher = declaration.attr_matcher
				end

				# 属性チェック用モジュールに対する処理
				@__neuron_check_attr_check_module.module_eval do

					# 属性1つごとに処理
					names.each do |attr_name|
						# 属性チェック用モジュールに、readerチェック用のラッパーメソッドを追加する
						if use_reader then
							define_method(attr_name) do
								# 通常の処理を呼び出す
								val = super()

								# 属性宣言があればチェック処理
								if target_attr_matcher then
									unless target_attr_matcher.match?(val, self) then
										context_caption = "value of attribute `#{self.class.name}##{attr_name}'"
										raise NeuronCheckError, target_attr_matcher.get_error_message(declaration, context_caption, val), caller(1)
									end
								end
							end
						end

						# 属性チェック用モジュールに、writerチェック用のラッパーメソッドを追加する
						if use_writer then
							define_method("#{attr_name}=") do |val|
								# 属性宣言があればチェック処理
								if target_attr_matcher then
									unless target_attr_matcher.match?(val, self) then
										context_caption = "value of attribute `#{self.class.name}##{attr_name}'"
										raise NeuronCheckError, target_attr_matcher.get_error_message(declaration, context_caption, val, phrase_after_but: 'set'), caller(1)
									end
								end

								# 通常の処理を呼び出す
								super(val)
							end
						end

					end
				end

				# 属性1つごとに処理
				names.each do |attr_name|
					# 登録実行
					NeuronCheckSystem::ATTR_DECLARATIONS[self][attr_name] = declaration
					declaration.assigned_class_or_module = self
					declaration.assigned_attribute_name = attr_name
				end

				# チェック処理の追加が完了したら、「最後に宣言した内容」を表すクラスインスタンス変数をnilに戻す
				@__neuron_check_last_declaration = nil
			end
		end


		# インスタンスメソッド定義を追加したときの処理
		def method_added(name)
			# まずは親処理を呼ぶ
			super

			# メイン処理をコール
			__neuron_check_method_added_hook(self, name, self.instance_method(name))
		end

		# 特異メソッド定義を追加したときの処理
		def singleton_method_added(name)
			# まずは親処理を呼ぶ
			super

			# メイン処理をコール
			__neuron_check_method_added_hook(self.singleton_class, name, self.singleton_class.instance_method(name), self)
		end

		# メソッド/特異メソッドを定義したときの共通処理
		def __neuron_check_method_added_hook(target_cls_or_mod, method_name, met, singleton_original_class = nil)
			singleton = !(singleton_original_class.nil?)

			# メソッド定義時のフックが無効化されている場合は何もしない
			return unless @__neuron_check_method_added_hook_enabled

			# 直前にNeuronCheck宣言部があれば、その宣言内容を登録する
			if (declaration = @__neuron_check_last_declaration) then

				# あらかじめ登録と、メソッドやクラスとの紐付けを行っておく
				# この処理を先に行わないと正しく名前を取得できない
				NeuronCheckSystem::METHOD_DECLARATIONS[target_cls_or_mod][method_name] = declaration
				declaration.assigned_class_or_module = target_cls_or_mod
				declaration.assigned_method = met
				declaration.assigned_singleton_original_class = singleton_original_class


				# 宣言に引数チェックが含まれている場合、宣言部の引数の数が、実際のメソッドの引数の数を超えていないかをチェック
				# 超えていれば宣言エラーとする
				if declaration.arg_matchers.size > met.parameters.size then
					raise NeuronCheckSystem::DeclarationError, "given arguments number of ##{method_name} greater than method definition - expected #{met.parameters.size} args, but #{declaration.arg_matchers.size} args were declared"
				end

				# パラメータの中にブロック型の引数が含まれているが
				# そのパラメータが、anyでもblockでもない型である場合はエラー
				met.parameters.each_with_index do |param_info, def_param_index|
					param_type, param_name = param_info
					if param_type == :block and (matcher = declaration.arg_matchers[def_param_index]) then
						next if matcher.respond_to?(:keyword_name) and matcher.keyword_name == 'any'
						next if matcher.respond_to?(:keyword_name) and matcher.keyword_name == 'block'

						context_caption = "#{NeuronCheckSystem::Utils.ordinalize(def_param_index + 1)} argument `#{param_name}' of `#{declaration.signature_caption_name_only}'"
						raise NeuronCheckSystem::DeclarationError, "#{context_caption} is block argument - it can be specified only keyword `any' or `block'"
					end
				end

				# 特異メソッドでなく、メソッド名が「initialize」であるにもかかわらず、returns宣言が含まれている場合はエラー
				if not singleton and method_name == :initialize and declaration.return_matcher then
					raise NeuronCheckSystem::DeclarationError, "returns declaration cannot be used with `#initialize' method"
				end

				# チェック処理の追加が完了したら、「最後に宣言した内容」を表すクラスインスタンス変数をnilに戻す
				@__neuron_check_last_declaration = nil
			end
		end
	end


	# チェック処理を差し込むためのTracePointを作成
	TRACE_POINT = TracePoint.new(:call, :return) do |tp|
		cls = tp.defined_class

		# メソッドに紐付けられた宣言を取得。取得できなければ終了
		decls = METHOD_DECLARATIONS[cls]
		next unless decls

		decl = decls[tp.method_id]
		next unless decl

		# メソッドの宣言情報を取得 (宣言があれば、メソッドの定義情報も必ず格納されているはずなので、取得成否チェックはなし)
		met = decl.assigned_method

		# ここからの処理はイベント種別で分岐
		case tp.event
		when :call # タイプが「メソッドの呼び出し」の場合の処理
			self.trace_method_call(tp.self, decl, met, tp.binding)
		when :return # タイプが「メソッドの終了」の場合の処理
			self.trace_method_return(tp.self, decl, met, tp.binding, tp.return_value)
		end
	end
	TRACE_POINT.enable

	# 全メソッド宣言のリスト
	METHOD_DECLARATIONS = {}

	# 全属性制限と対応するメソッド情報のリスト
	ATTR_DECLARATIONS = {}

	# bindingクラスに local_variable_get が定義されているかどうかを判定し、その判定結果を定数に記録 (Ruby 2.1以降では定義されているはず)
	LOCAL_VARIABLE_GET_USABLE = (binding.respond_to?(:local_variable_get))

	# 指定したbindingから、指定した名前のローカル変数を取得する (Binding#local_variable_getが定義されているかどうかで実装を変える)
	def self.get_local_variable_from_binding(target_binding, var_name)
		if LOCAL_VARIABLE_GET_USABLE then
			target_binding.local_variable_get(var_name)
		else
			# local_variable_getが使えない時は、代わりにevalを使用して取得
			target_binding.eval(var_name.to_s)
		end
	end

	# メソッド呼び出し時のチェック処理 (現段階ではattrメソッドの呼び出しでは発生しないことに注意。Ruby 2.1で確認)
	def self.trace_method_call(method_self, declaration, met, method_binding)
		param_values = {}

		# 大域脱出できるようにcatchを使用 (バックトレースを正しく取得するための処置)
		error_msg = catch(:neuron_check_error_tag) do

			# 対象メソッドの引数1つごとに処理
			met.parameters.each_with_index do |param_info, def_param_index|
				param_type, param_name = param_info

				# 実際に渡された引数の値を取得 (デフォルト値の処理も考慮する)
				param_value = get_local_variable_from_binding(method_binding, param_name)
				param_values[param_name] = param_value

				# 指定位置に対応するマッチャが登録されている場合のみ処理
				if (matcher = declaration.arg_matchers[def_param_index]) then

					# 引数の種類で処理を分岐
					case param_type
					when :key # キーワード引数
						unless matcher.match?(param_value, self) then
							context_caption = "argument `#{param_name}' of `#{declaration.signature_caption_name_only}'"
							@last_argument_error_info = [method_self, met.name] # 引数チェックエラーの発生情報を記録

							throw :neuron_check_error_tag, matcher.get_error_message(declaration, context_caption, param_value)
						end

					when :keyrest # キーワード引数の可変長部分
						# 可変長部分1つごとにチェック
						param_value.each_pair do |key, value|
							unless matcher.match?(value, self) then
								context_caption = "argument `#{param_name}' of `#{declaration.signature_caption_name_only}'"
								@last_argument_error_info = [method_self, met.name] # 引数チェックエラーの発生情報を記録

								throw :neuron_check_error_tag, matcher.get_error_message(declaration, context_caption, value)
							end
						end

					when :rest # 可変長部分
						# 可変長引数であれば、受け取った引数1つごとにチェック
						param_value.each_with_index do |val, i|
							unless matcher.match?(val, self) then
								context_caption = "#{NeuronCheckSystem::Utils.ordinalize(def_param_index + 1 + i)} argument `#{param_name}' of `#{declaration.signature_caption_name_only}'"
								@last_argument_error_info = [method_self, met.name] # 引数チェックエラーの発生情報を記録

								throw :neuron_check_error_tag, matcher.get_error_message(declaration, context_caption, val)
							end
						end

					else # 通常の引数/ブロック引数
						unless matcher.match?(param_value, self) then
							context_caption = "#{NeuronCheckSystem::Utils.ordinalize(def_param_index + 1)} argument `#{param_name}' of `#{declaration.signature_caption_name_only}'"
							@last_argument_error_info = [method_self, met.name] # 引数チェックエラーの発生情報を記録

							throw :neuron_check_error_tag, matcher.get_error_message(declaration, context_caption, param_value)
						end
					end
				end
			end


			# 事前条件があれば実行
			if declaration.precond then
				# コンテキストを生成
				context = make_cond_block_context(method_self, 'precond', param_values, declaration.precond_allow_instance_method)

				# 条件文実行
				context.instance_exec(&(declaration.precond))
			end

			# 最後まで正常実行した場合はnilを返す
			nil
		end # catch

		# エラーメッセージがあればNeuronCheckError発生
		if error_msg then
			raise NeuronCheckError, error_msg, caller(3)
		end
	end

	# メソッド終了時のチェック処理
	def self.trace_method_return(method_self, declaration, met, method_binding, return_value)

		# 大域脱出できるようにcatchを使用 (バックトレースを正しく取得するための処置)
		error_msg = catch(:neuron_check_error_tag) do
			# 最後に引数チェックエラーが発生しており、selfとメソッド名が同じものであれば、return値のチェックをスキップ
			# (NeuronCheckError例外を発生させたときにもreturnイベントは発生してしまうため、その対策として)
			if @last_argument_error_info and @last_argument_error_info[0].equal?(method_self) and @last_argument_error_info[1] == met.name then
				@last_argument_error_info = nil
				return
			end

			param_values = {}

			# 対象メソッドの引数1つごとに処理
			met.parameters.each_with_index do |param_info, def_param_index|
				_, param_name = param_info

				# 実際に渡された引数の値を取得 (デフォルト値の処理も考慮する)
				param_value = get_local_variable_from_binding(method_binding, param_name)
				param_values[param_name] = param_value
			end

			# 戻り値チェック
			if (matcher = declaration.return_matcher) then
				# チェック処理
				unless matcher.match?(return_value, method_self) then
					# エラー
					throw :neuron_check_error_tag, matcher.get_error_message(declaration, "return value of `#{declaration.signature_caption_name_only}'", return_value)
				end
			end

			# 事後条件があれば実行
			if declaration.postcond then
				# コンテキストを生成
				context = make_cond_block_context(method_self, 'postcond', param_values, declaration.postcond_allow_instance_method)

				# 条件文実行
				context.instance_exec(return_value, &(declaration.postcond))
			end

			# 最後まで正常実行した場合はnilを返す
			nil
		end # catch

		# エラーメッセージがあればNeuronCheckError発生
		if error_msg then
			raise NeuronCheckError, error_msg, caller(3)
		end
	end

	# 事前条件/事後条件の実行用コンテキストを構築する
	def self.make_cond_block_context(method_self, context_caption, param_values, allow_instance_method)
		# ローカル変数指定用の無名モジュールを作成
		local_mod = Module.new
		local_mod.module_eval do
			# ローカル変数取得用のメソッドを定義する
			param_values.each_pair do |var_name, value|
				define_method(var_name) do
					return value
				end
			end
		end

		# ブロック実行用のコンテキストを生成し、ローカル変数保持モジュールを差し込む
		context = CondBlockContext.new(context_caption, method_self, allow_instance_method)
		context.extend local_mod

		# 対象のオブジェクトが持つ全てのインスタンス変数を、コンテキストへ引き渡す
		method_self.instance_variables.each do |var_name|
			val = method_self.instance_variable_get(var_name)
			context.instance_variable_set(var_name, val)
		end

		return context
	end

	# モジュール/クラス1つに対して、NeuronCheck用の初期化を行う
	def self.initialize_module_for_neuron_check(mod_or_class)
		# 2回目以降の初期化であれば何もせずにスルー
		if mod_or_class.instance_variable_get(:@__neuron_check_initialized) then
			return
		end

		# 宣言とメソッド情報を格納するためのHashを更新
		NeuronCheckSystem::METHOD_DECLARATIONS[mod_or_class] = {}
		NeuronCheckSystem::METHOD_DECLARATIONS[mod_or_class.singleton_class] = {} # 特異メソッド用のクラスも追加
		NeuronCheckSystem::ATTR_DECLARATIONS[mod_or_class] = {}

		# 対象のModule/Classに対する処理
		mod_or_class.instance_eval do
			# 最後に宣言された内容を保持するクラスインスタンス変数(モジュールインスタンス変数)を定義
			@__neuron_check_last_declaration = nil
			# メソッド定義時のフックを一時的に無効化するフラグ
			@__neuron_check_method_added_hook_enabled = true
			# 属性の処理を上書きするために差し込む無名モジュールを定義 (prependする)
			@__neuron_check_attr_check_module = Module.new
			prepend @__neuron_check_attr_check_module

			# メソッド定義時のフックなどを定義したモジュールをextend
			extend NeuronCheckSystem::Kernel

			# initialize済みフラグON
			@__neuron_check_initialized = true # 初期化
		end
	end
end

# ユーザーが利用するメインモジュール。extend処理や、有効化/無効化などに使用する
module NeuronCheck

	# チェック実行フラグ
	@enabled = true
	def self.enabled?; @enabled; end

	# 無効化
	def self.disable
		if block_given? then
			# ブロックが渡された場合は、ブロック実行中のみチェックを無効化
			begin
				disable
				yield
			ensure
				enable
			end
		else
			@enabled = false
			NeuronCheckSystem::TRACE_POINT.disable # メソッド呼び出しフックを無効化
		end
	end

	# 無効化されたチェックを、再度有効化
	def self.enable
		if block_given? then
			# ブロックが渡された場合は、ブロック実行中のみチェックを有効か
			begin
				enable
				yield
			ensure
				disable
			end
		else
			@enabled = true
			NeuronCheckSystem::TRACE_POINT.enable # メソッド呼び出しフックを有効化
		end
	end

	# 単体チェック
	def self.match?(value, &expected_block)
		# 宣言ブロック実行用のコンテキストを作成
		context = NeuronCheckSystem::DeclarationContext.new
		# 宣言ブロックの内容を実行
		expected = context.instance_eval(&expected_block)

		matcher = NeuronCheckSystem.get_appropriate_matcher(expected, [])
		return matcher.match?(value, nil)
	end

	# 単体チェック
	def self.check(value, &expected_block)
		# 宣言ブロック実行用のコンテキストを作成
		context = NeuronCheckSystem::DeclarationContext.new
		# 宣言ブロックの内容を実行
		expected = context.instance_eval(&expected_block)

		matcher = NeuronCheckSystem.get_appropriate_matcher(expected, [])
		unless matcher.match?(value, nil) then
			raise NeuronCheckError, matcher.get_error_message(nil, 'value', value), caller(1)
		end
	end

	# 宣言情報の出力
	def self.get_declarations_as_json(ignore_unnamed_modules: false)
		re = {'instance_methods' => {}, 'singleton_methods' => {}, 'attributes' => {}}

		NeuronCheckSystem::METHOD_DECLARATIONS.each_pair do |cls_or_mod, data|
			data.each_pair do |method_name, decl|
				method_type = (decl.assinged_to_singleton_method? ? 'singleton_methods' : 'instance_methods')
				target_mod_or_class = (decl.assinged_to_singleton_method? ? decl.assigned_singleton_original_class : decl.assigned_class_or_module)
				key = target_mod_or_class.name

				# 無名モジュール/クラスの場合の対応
				if key.nil? and not ignore_unnamed_modules then
					key = target_mod_or_class.inspect
				end

				if key then
					re[method_type][key] ||= {}
					re[method_type][key][method_name.to_s] = decl.meta_info_as_json
				end
			end
		end

		NeuronCheckSystem::ATTR_DECLARATIONS.each_pair do |cls_or_mod, data|
			key = cls_or_mod.name

			# 無名モジュール/クラスの場合の対応
			if key.nil? and not ignore_unnamed_modules then
				key = cls_or_mod.inspect
			end

			data.each_pair do |method_name, decl|
				re['attributes'][key] ||= {}
				re['attributes'][key][method_name.to_s] = decl.meta_info_as_json
			end
		end

		re
	end

	# extend時処理
	def self.extended(mod_or_class)
		# extend対象がモジュールでもクラスでもなければエラー
		unless mod_or_class.kind_of?(Module) then
			raise ScriptError, "NeuronCheck can be extended only to Class or Module"
		end

		# 2回目以降のextendであれば何もせずにスルー
		if mod_or_class.instance_variable_get(:@__neuron_check_extended) then
			return
		end

		# まずはNeuronCheck用の初期化
		NeuronCheckSystem.initialize_module_for_neuron_check(mod_or_class)

		# 対象のModule/Classに対する処理
		mod_or_class.instance_eval do
			# Module/Classに対して宣言用のメソッドを追加する
			extend NeuronCheckSystem::DeclarationMethods

			# extend済みフラグON
			@__neuron_check_extended = true
		end
	end
end



# トップレベル関数用の特殊なndecl
self.instance_eval do
	def ndecl(*expecteds, &block)
		decl_caller = caller(2)

		# Objectクラスへの宣言とみなす
		Object.class_eval do
			# extend NeuronCheckが実行されていない場合、NeuronCheck用の初期化を自動実行
			unless @__neuron_check_extended then
				extend NeuronCheck
			end

			# メイン処理実行
			__neuroncheck_ndecl_main(expecteds, block, decl_caller)
		end
	end

	alias ndeclare ndecl
	alias ncheck ndecl
	alias ntypesig ndecl
	alias nsig ndecl
end
