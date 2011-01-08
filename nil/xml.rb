module Nil
  class XMLObject
    def initialize
      @overrideName = nil
      @content = nil
      @ignored = [:@overrideName, :@content, :@ignored]
    end

    def add(node)
      if @content == nil
        @content = []
      elsif String === @content
        raise 'Tried to add an XML object to a parent which already has a content string specified'
      end
      if !node.kind_of?(XMLObject)
        raise "Child class #{node.class} is not derived from XMLObject"
      end
      @content << node
    end

    def setContent(content)
      if !(String === content)
        raise "Invalid content class #{content.class}"
      end
      @content = content
    end

    def setName(name)
      @overrideName = name
    end

    def attributifyString(string)
      output = ''
      string.each_char do |char|
        if !['&', '<', '>'].include?(char) && (' '..'~').include?(char)
          output += char
        else
          output += "&##{char.ord};"
        end
      end
      return output
    end

    def getCDATAString(input)
      intro = '<![CDATA'
      outro = ']]>'
      content = input.gsub(outro, outro[0..-2] + intro + outro[-1])
      return "#{intro}\n#{content}#{outro}\n"
    end

    def getStringContent
      if !(String === @content)
        raise 'Cannot retrieve the string of non-string content'
      end
      illegalStrings =
        [
         '<',
         '>',
        ]
      illegalStrings.each do |string|
        if @content.index(string) != nil
          return getCDATAString(@content)
        end
      end
      return @content
    end

    def serialise
      attributes = {}
      instance_variables.each do |symbol|
        next if @ignored.include?(symbol)
        name = symbol.to_s[1..-1]
        value = instance_variable_get(symbol)
        attributes[name] = value
      end
      attributeString = attributes.map do |key, value|
        " #{key}=\"#{attributifyString(value)}\""
      end.join('')
      name = self.class.to_s
      if @overrideName != nil
        name = @overrideName
      end
      if @content == nil
        return "<#{name}#{attributeString} />\n"
      else
        intro = "<#{name}#{attributeString}>"
        if String === @content
          content = getStringContent
        else
          intro += "\n"
          content = @content.map do |node|
            node.serialise
          end.join('')
        end
        outro = "</#{name}>\n"
        output = intro + content + outro
        return output
      end
    end
  end
end
