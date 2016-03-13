module NeuronCheckSystem
  class CondBlockContext
    def initialize(block_name, method_self, allow_instance_method)
      @block_name = block_name
      @method_self = method_self
      @allow_instance_method = allow_instance_method
    end

    def method_missing(name, *args, &block)
      if @method_self.respond_to?(name, true) then
        if @allow_instance_method then
          @method_self.send(name, *args, &block)
        else
          raise NeuronCheckSystem::DeclarationError, "instance method `#{name}' cannot be called in #{@block_name}, it is forbidden", (NeuronCheck.debug? ? caller : caller(1))
        end
      else
        super
      end
    end

    def assert(*dummy)
      unless block_given? then
        raise NeuronCheckSystem::DeclarationError, "no block given for `assert' in #{@block_name}", (NeuronCheck.debug? ? caller : caller(1))
      end

      passed = yield

      unless passed
        locs = Utils.backtrace_locations_to_captions(caller(1, 1))

        msg = <<MSG
#{@block_name} assertion failed
  asserted at: #{locs.join("\n" + ' ' * 15)}

MSG

        # エラーを発生させる
        throw :neuron_check_error_tag, msg
      end
    end
  end
end
