module NeuronCheckSystem
	module Utils
		module_function

		# From ActiveSupport (Thanks for Rails Team!)  <https://github.com/rails/rails/tree/master/activesupport>
		#
		# Truncates a given +text+ after a given <tt>length</tt> if +text+ is longer than <tt>length</tt>:
	  #
	  #   'Once upon a time in a world far far away'.truncate(27)
	  #   # => "Once upon a time in a wo..."
	  #
	  # Pass a string or regexp <tt>:separator</tt> to truncate +text+ at a natural break:
	  #
	  #   'Once upon a time in a world far far away'.truncate(27, separator: ' ')
	  #   # => "Once upon a time in a..."
	  #
	  #   'Once upon a time in a world far far away'.truncate(27, separator: /\s/)
	  #   # => "Once upon a time in a..."
	  #
	  # The last characters will be replaced with the <tt>:omission</tt> string (defaults to "...")
	  # for a total length not exceeding <tt>length</tt>:
	  #
	  #   'And they found that many people were sleeping better.'.truncate(25, omission: '... (continued)')
	  #   # => "And they f... (continued)"
	  def truncate(str, truncate_at, omission: '...', separator: nil)
	    return str.dup unless str.length > truncate_at

	    omission = omission || '...'
	    length_with_room_for_omission = truncate_at - omission.length
	    stop = \
	      if separator
	        rindex(separator, length_with_room_for_omission) || length_with_room_for_omission
	      else
	        length_with_room_for_omission
	      end

	    "#{self[0, stop]}#{omission}"
	  end

		# 1つ以上の文字列をorで結んだ英語文字列にする
		def string_join_using_or_conjunction(strings)
			ret = ""
			strings.each_with_index do |str, i|
				case i
				when 0 # 最初の要素
				when strings.size - 1 # 最後の要素
					ret << " or "
				else
					ret << ", "
				end

				ret << str
			end

			ret
		end

		# Thread::Backtrace::Locationのリストを文字列形式に変換。フレーム数が多すぎる場合は途中を省略
		def backtrace_locations_to_captions(locations)
			locs = nil
			if locations.size > 9 then
				locs = (locations[0..3].map{|x| "from #{x.to_s}"} + [" ... (#{locations.size - 8} frames) ..."] + locations[-4..-1].map{|x| "from #{x.to_s}"})
			else
				locs = locations.map{|x| "from #{x.to_s}"}
			end

			if locs.size >= 1 then
				locs.first.sub!(/\A\s*from /, '')
			end

			locs
		end

		# 指定した整数値を序数文字列にする
		def ordinalize(v)
			if [11,12,13].include?(v % 100)
				"#{v}th"
			else
				case (v % 10)
				when 1
					"#{v}st"
				when 2
					"#{v}nd"
				when 3
					"#{v}rd"
				else
					"#{v}th"
				end
			end
		end
	end
end
