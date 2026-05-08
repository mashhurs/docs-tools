# encoding: utf-8

require 'set'

module LogstashDocket
  ##
  # A {@link Source} provides methods for working with versioned source data.
  #
  module Source
    ##
    # Read the file at the given version
    #
    # @param filename [String]: the full file path
    # @param version [#to_s, nil]: the version (default: latest)
    #
    # @return [String]
    def read_file(filename, version=nil)
      fail NotImplementedError
    end

    ##
    # Get the public web URL for the given file path at the given revision
    #
    # @param filename [String]: the full file path
    # @param version [#to_s, nil]: the version (default: latest)
    #
    # @return [String]
    def web_url(filename, version=nil)
      fail NotImplementedError
    end

    ##
    # Get a set of release tags from this source
    #
    # @return [Set{String}]
    def release_tags
      fail NotImplementedError
    end

    ##
    # A {@link Source::Github} represents the source of a public project hosted on Github
    class Github
      include Source

      attr_reader :org
      attr_reader :repo

      ##
      # @param repo [String]: a repository name
      # @param org [String]: a github organisation (default: extract from `repo`)
      # @param octokit [Octokit::Client]: a github API client (optional; required for tag listing)
      def initialize(repo:, org:nil, octokit: nil)
        if org.nil?
          org, repo = repo.split('/', 2)
          fail(ArgumentError, "incomplete repo spec: `#{repo}`") if org.nil? || repo.nil?
        end

        @org = org
        @repo = repo

        @octokit = octokit
      end

      ##
      # @see [Source#read_file]
      def read_file(filename, version=nil)
        uri = URI.parse("https://raw.githubusercontent.com/#{org}/#{repo}/#{ref(version)}/#{filename}")
        response = Net::HTTP.get(uri)

        return nil if response.start_with?('404: Not Found')

        response
      end

      ##
      # @see [Source#web_url]
      def web_url(filename, version=nil)
        "https://github.com/#{org}/#{repo}/blob/#{ref(version)}/#{filename}"
      end

      ##
      # @see [Source#release_tags]
      def release_tags
        @tags ||= begin
          fail('octokit github client required') if @octokit.nil?

          # NOTE: We deliberately avoid Octokit's `auto_paginate` (used by
          # `@octokit.tags`) here. `auto_paginate` follows the `Link: rel=next`
          # auto-paginate fetchs only 100 tags, manually paginate using `@octokit.get`
          per_page = 100
          all_tags = []
          page = 1
          loop do
            page_tags = @octokit.get("repos/#{org}/#{repo}/tags", :page => page, :per_page => per_page)
            break if page_tags.nil? || page_tags.empty?
            all_tags.concat(page_tags)
            break if page_tags.size < per_page
            page += 1
          end

          Set.new(all_tags.map(&:name).select{|t| t[%r{\Av\d+\.\d+\.\d+}] })
        end
      end

      private

      def ref(version)
        version ? "v#{version}" : 'main'
      end
    end
  end
end
