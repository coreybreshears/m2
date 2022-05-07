require 'rubyXL'

# The module "monkey" patches the RubyXL OOXML object parsing by skipping a
#   child node of unknown type instead of raising an error. A warning in
#   bebug log is generated for such a case.
module RubyXL::OOXMLObjectClassMethods
  def parse(node, known_namespaces = nil)
    case node
    when String, IO, Zip::InputStream then node = Nokogiri::XML.parse(node)
    end

    if node.is_a?(Nokogiri::XML::Document) then
      @namespaces = node.namespaces
      node = node.root
    end

    obj = self.new

    known_attributes = obtain_class_variable(:@@ooxml_attributes)

    content_params = known_attributes['_']
    process_attribute(obj, node.text, content_params) if content_params

    node.attributes.each_pair { |attr_name, attr|
      attr_name = if attr.namespace then "#{attr.namespace.prefix}:#{attr.name}"
                  else attr.name
                  end

      attr_params = known_attributes[attr_name]

      next if attr_params.nil?
      process_attribute(obj, attr.value, attr_params) unless attr_params[:computed]
    }

    known_child_nodes = obtain_class_variable(:@@ooxml_child_nodes)

    unless known_child_nodes.empty?
      known_namespaces ||= obtain_class_variable(:@@ooxml_namespaces)

      node.element_children.each { |child_node|

        ns = child_node.namespace
        prefix = known_namespaces[ns.href] || ns.prefix

        child_node_name = case prefix
                          when '', nil then child_node.name
                          else "#{prefix}:#{child_node.name}"
                          end

        child_node_params = known_child_nodes[child_node_name]

        if child_node_params.nil?
          MorLog.my_debug(
            "XLSX Debug (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}) -> "\
            "Unknown child node [#{child_node_name}] for element [#{node.name}]"
          )
          next
        end

        parsed_object = child_node_params[:class].parse(child_node, known_namespaces)
        if child_node_params[:is_array] then
          index = parsed_object.index_in_collection

          collection = if (self < RubyXL::OOXMLContainerObject) then obj
                       else obj.send(child_node_params[:accessor])
                       end

          if index.nil? then
            collection << parsed_object
          else
            collection[index] = parsed_object
          end
        else
          obj.send("#{child_node_params[:accessor]}=", parsed_object)
        end
      }
    end

    obj
  end
end
