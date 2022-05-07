# Monkey Patched
require 'rubyXL'

module RubyXL
  class Reference

    # Move merged cells down starting from next                            #
    def shift_down(row_index)                                              # This code block was patched (added)
      return unless row_range.max >= row_index                             #
                                                                           #
      new_min = row_range.min + (row_range.min >= row_index ? 1 : 0)       #
      @row_range = Range.new(new_min, row_range.max + 1)                   #
    end                                                                    #
  end
end
