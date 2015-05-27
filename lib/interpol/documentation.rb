require 'nokogiri'
require 'redcarpet'

module Interpol
  # Renders HTML documentation for an interpol endpoint.
  module Documentation
    extend self

    def html_for_schema(schema)
      SchemaDefinitionRenderer.new(schema).to_html
    end

    def html_for_examples(examples)
      SchemaExamplesRenderer.new(examples).to_html
    end

    def redcarpet
      @redcarpet ||= Redcarpet::Markdown.new \
        Redcarpet::Render::HTML,
        no_intra_emphasis: true,
        tables: true,
        fenced_code_blocks: true,
        disable_indented_code_blocks: true,
        strikethrough: true,
        lax_spacing: true,
        superscript: true,
        underline: true,
        highlight: true,
        quote: true
    end

    # Inner class for rendering the markdown
    class Renderer
      def initialize(document)
        @document = document
      end

      def to_html
        build do |doc|
          render(doc, @document)
        end.to_html
      end

      def render_markdown(md)
        Interpol::Documentation.redcarpet.render(md)
      end

      def render_fragment(md)
        # strip enclosing <p> tags
        render_markdown(md)[3..-4]
      end

    private

      def build
        Nokogiri::HTML::DocumentFragment.parse("").tap do |doc|
          Nokogiri::HTML::Builder.with(doc) do |doc|
            yield doc
          end
        end
      end
    end

    # Renders the documentation for a schema definition.
    class SchemaDefinitionRenderer < Renderer

    private

      def render(doc, schema)
        doc.div(:class => "schema-definition") do
          schema_description(doc, schema)
          render_properties_and_items(doc, schema)
        end
      end

      def schema_description(doc, schema)
        return unless schema.has_key?('description')
        doc.h3(:class => "description") { doc.text(schema['description']) }
      end

      def render_properties_and_items(doc, schema)
        render_properties(doc, Array(schema['properties']))
        render_items(doc, schema['items'])
      end

      def render_items(doc, items)
        # No support for tuple-typing, just basic array typing
        return  if items.nil?
        doc.dl(:class => "items") do
          doc.dt(:class => "name") { doc.text("(array contains #{items['type']}s)") }
          if items.has_key?('description')
            doc.dd { doc.text(items['description']) }
          end
          render_properties_and_items(doc, items)
        end

      end

      def render_properties(doc, properties)
        return if properties.none?

        doc.dl(:class => "properties") do
          properties.each do |name, property|
            property_definition(doc, name, property)
          end
        end
      end

      def property_definition(doc, name, property)
        doc.dt(:class => "name"){ doc << property_title(name, property) } if name

        if property.has_key?('description')
          doc.dd { doc.text(property['description']) }
        end

        render_properties_and_items(doc, property)
      end

      def property_title(name, property)
        return name unless property['type']
        render_fragment("**#{name}**  *#{property['type']}*")
      end
    end

    # Renders the examples for a schema definition.
    class SchemaExamplesRenderer < Renderer

    private

      def render(doc, examples)
        return if examples.empty?

        doc.h3 { doc.text("Examples:") }
        doc.div(:class => "schema-examples") do
          examples.each do |example|
            render_schema_example(doc, example)
          end
        end
      end

      def render_schema_example(doc, example)
        doc.pre(:class => "schema-example") do
          doc.text(JSON.pretty_generate(example.data))
          #doc.text(example.data.to_s)
        end
      end
    end
  end
end
