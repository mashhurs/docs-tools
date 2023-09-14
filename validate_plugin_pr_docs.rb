require "clamp"
require "asciidoctor"
require "logger"

class ValidatePluginPrDocs < Clamp::Command
  option "--docs-path", "OUTPUT", "Path to the top-level of the logstash-docs path to read the ascii docs.", required: true

  # include Asciidoctor::Logging

  LAYOUT_DESCRIPTION = <<~LOG
      Alternative language must be a code block followed optionally by a callout list
  LOG

  def execute
    # let's print the asciidoctor version to make sure it is aligned with elastic/docs
    puts "Validation process of PR docs started with asciidoctor #{Asciidoctor::VERSION} version."
    index_doc = docs_path + "/docs/versioned-plugins/index.asciidoc"
    puts "Index doc: #{index_doc}"
    # with a safe mode, asciidoctor produces warnings/errors
    # when opening the index.asciidoc file
    # it checks all the docs embedded to the index file
    # validates the links included docs
    Asciidoctor.load_file index_doc, safe: :safe
  end

  def explore_files_and_validate
    # discover files and validate one by one
    explored_docs = explore_files(docs_path)
    invalid_doc_found = false
    explored_docs.each do |file_name|
      next unless file_name.include?("azure_event_hubs-index")
      begin
        # Parse an AsciiDoc file into a document object
        # doc = Asciidoctor.load_file file_name
        source = [
          '<div id="footnotes"> Validation </div>',
        ].join "\n"

        puts "File: #{file_name}"
        file = Asciidoctor::convert_file file_name, safe: :SERVER, to_file: false
        # puts "File: #{file.inspect} \n\n"

      rescue
        puts "Unhealthy ASCII doc: #{file_name}"
        puts $!
        invalid_doc_found = true
      end
    end

    if invalid_doc_found
      exit(-1)
    end
  end

  def explore_files(path)
    files = []
    Dir.each_child(path) do |file|
      full_file_path = path + "/" + file
      if File.file?(full_file_path)
        files << full_file_path
      else
        files.concat(explore_files(full_file_path))
      end
    end
    files
  end

end

if __FILE__ == $0
  ValidatePluginPrDocs.run
end
