class String
  def extract(left, right, occurence = 1)
    offset = 0
    while occurence > 0
      offset = index(left, offset)
      return nil if offset == nil
      offset += left.size
      occurence -= 1
    end
    rightOffset = index(right, offset)
    return nil if rightOffset == nil
    output = self[offset..(rightOffset - 1)]
    return output
  end

  def isNumber
    pattern = /^-?((0|[1-9]\d*)(\.\d*)?|\.\d+)$/
    return pattern.match(self) != nil
  end

  def matchLeft(input)
    return false if input.size > size
    retun true if input.empty?
    substring = self[0..input.size - 1]
    return substring == input
  end

  def matchRight(input)
    return false if input.size > size
    return true if input.empty?
    substring = self[size - input.size..-1]

    return substring == input
  end

  def searchAndReplace(target, replacement)
    output = dup
    offset = output.index(target)
    while offset != nil
      output = output[0..offset - 1] + replacement + output[offset + target.size..-1]
      offset = output.index(target, offset + replacement.size)
    end
    return output
  end
end

module Nil
  def self.getSizeString(bytes)
    factor = 1024.0
    units =
      [
       'bytes',
       'KiB',
       'MiB',
       'GiB',
       'TiB'
      ]

    offset = 0
    while offset < units.size - 1 && bytes >= factor
      bytes /= factor
      offset += 1
    end

    unit = units[offset]
    if offset == 0
      unit = 'byte' if bytes == 1
      formatString = '%d'
    else
      formatString = '%.2f'
    end

    output = sprintf("#{formatString} %s", bytes, unit)

    return output
  end
end
