class NilClass
  def to_d
    self.to_f.to_d
  end

  def [] key
    # MorLog.my_debug("#{Time.now}: Hash method - [] was used on NilClass, fix it!")
    # MorLog.my_debug("Key used: #{key}")
    # MorLog.my_debug('Backtrace:')
    # MorLog.my_debug("#{caller.join("\n")}\n\n")
    nil
  end

  def []=(key, value)
    # MorLog.my_debug("#{Time.now}: Hash method - []= was used on NilClass, fix it!")
    # MorLog.my_debug("Key used: #{key}")
    # MorLog.my_debug("Value used: #{value}")
    # MorLog.my_debug('Backtrace:')
    # MorLog.my_debug("#{caller.join("\n")}\n\n")
    nil
  end
end