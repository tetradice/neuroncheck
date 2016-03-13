require 'neuroncheck/builtin_keyword'

# NeuronCheckSyntaxはruby 2.0以前では使用しない (Refinementが実験的機能として定義されているため)
unless RUBY_VERSION <= '2.0.9' then
	NeuronCheckSystem::RUBY_TOPLEVEL = self

	module NeuronCheckSyntax
		refine Module do
			# NeuronCheckの宣言用キーワードを、コード内の全箇所で使用可能にする
			include NeuronCheckSystem::Keywords

			# ndecl宣言 (このメソッドは初回実行時のみ呼び出されることに注意。1度ndeclを実行したら、次以降はNeuronCheckSystem::DeclarationMethodsの方が有効になるため、そちらが呼ばれる)
			def ndecl(*expecteds, &block)
				# モジュール/クラス内の場合の処理
				# extend NeuronCheckが実行されていない未初期化の場合、NeuronCheck用の初期化を自動実行
				unless @__neuron_check_extended then
					extend NeuronCheck
				end

				# メイン処理実行
				__neuroncheck_ndecl_main(expecteds, block, caller(1, 1))
			end

			alias ndeclare ndecl
			alias ncheck ndecl
			alias ntypesig ndecl
			alias nsig ndecl

			alias decl ndecl
			alias declare ndecl
			alias sig ndecl
		end

		# トップレベル定義のエイリアス
		refine NeuronCheckSystem::RUBY_TOPLEVEL.singleton_class do
			def decl(*expecteds, &block)
				ndecl(*expecteds, &block)
			end

			def declare(*expecteds, &block)
				ndecl(*expecteds, &block)
			end

			def sig(*expecteds, &block)
				ndecl(*expecteds, &block)
			end
		end
	end
end
