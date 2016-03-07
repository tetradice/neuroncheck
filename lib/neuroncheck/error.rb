module NeuronCheckSystem
	class ExceptionBase < Exception
	end

	class DeclarationError < ExceptionBase
	end

	class PluginError < ExceptionBase
	end
end

class NeuronCheckError < NeuronCheckSystem::ExceptionBase
end
