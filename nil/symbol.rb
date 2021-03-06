module SymbolicAssignment
  def self.translateSymbol(symbol)
    return ('@' + symbol.to_s).to_sym
  end

  def getMember(symbol)
    symbol = SymbolicAssignment.translateSymbol(symbol)
    return instance_variable_get(symbol)
  end

  def setMember(symbol, value)
    symbol = SymbolicAssignment.translateSymbol(symbol)
    instance_variable_set(symbol, value)
  end

  def setPublicMember(symbol, value)
    setMember(symbol, value)
    self.class.send(:define_method, symbol) do
      getMember(symbol)
    end
  end
end
