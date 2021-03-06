require 'nokogiri'
require 'ostruct'
require 'string'
require 'webrick/cookie'

module Anemone
  class Page

    # The URL of the page
    attr_reader :url
    # The raw HTTP response body of the page
    attr_reader :body
    # Headers of the HTTP response
    attr_reader :headers
    # URL of the page this one redirected to, if any
    attr_reader :redirect_to
    # Exception object, if one was raised during HTTP#fetch_page
    attr_reader :error

    # OpenStruct for user-stored data
    attr_accessor :data
    # Integer response code of the page
    attr_accessor :code
    # Boolean indicating whether or not this page has been visited in PageStore#shortest_paths!
    attr_accessor :visited
    # Depth of this page from the root of the crawl. This is not necessarily the
    # shortest path; use PageStore#shortest_paths! to find that value.
    attr_accessor :depth
    # URL of the page that brought us to this page
    attr_accessor :referer
    # Response time of the request for this page in milliseconds
    attr_accessor :response_time

    #
    # Create a new page
    #
    def initialize(url, params = {})
      @url = url
      @data = OpenStruct.new

      @code = params[:code]
      @headers = params[:headers] || {}
      @headers['content-type'] ||= ['']
      @aliases = Array(params[:aka]).compact
      @referer = params[:referer]
      @depth = params[:depth] || 0
      @redirect_to = to_absolute(params[:redirect_to])
      @response_time = params[:response_time]
      @body = params[:body]
      @error = params[:error]
      @skip_no_follow = params[:skip_no_follow]
      @follow_subdomain = params[:follow_subdomain]
      @external_links = params[:external_links]
      @urls = params[:urls]

      @fetched = !params[:code].nil?
    end

    #
    # Array of distinct A tag HREFs from the page
    #
    def links
      return @links unless @links.nil?
      @links = []
      return @links if !doc
      return @links if no_index?

      # Don't add any links if this page is not in the crawled domains
      return @links if !page_in_domain?

      docs = 
        if @skip_no_follow
          doc.search('//a[@href and not(contains(@rel, "nofollow"))]')
        else
          doc.search('//a[@href]')
        end

      docs.each do |a|
        u = a['href']
        next if u.nil? or u.empty?
        # If the page ends in a "/" or doesn't have a "." in the last portion of the url
        #  then add an "index.html". Without this, the path to child pages is incorrect
        abs = to_absolute(u) rescue next
        @links << abs if (in_domain?(abs) || is_subdomain?(u)) || @external_links        
      end
      @links.uniq!

      docs = doc.search('//img[@src]')

      docs.each do |a|
        u = a['src']
        next if u.nil? or u.empty?
        abs = to_absolute(u) rescue next
        @links << abs if (in_domain?(abs) || is_subdomain?(u)) || @external_links        
      end
      @links.uniq!
            
      @links
    end

    #
    # Nokogiri document for the HTML body
    #
    def doc
      return @doc if @doc
      @doc = Nokogiri::HTML(@body) if @body && html? rescue nil
    end

    #
    # Delete the Nokogiri document and response body to conserve memory
    #
    def discard_doc!
      links # force parsing of page links before we trash the document
      @doc = @body = nil
    end

    #
    # Was the page successfully fetched?
    # +true+ if the page was fetched with no error, +false+ otherwise.
    #
    def fetched?
      @fetched
    end

    #
    # Array of cookies received with this page as WEBrick::Cookie objects.
    #
    def cookies
      WEBrick::Cookie.parse_set_cookies(@headers['set-cookie']) rescue []
    end

    #
    # The content-type returned by the HTTP request for this page
    #
    def content_type
      headers['content-type']
    end

    #
    # Returns +true+ if the page is a HTML document, returns +false+
    # otherwise.
    #
    def html?
      !!(content_type =~ %r{^(text/html|application/xhtml+xml)\b})
    end

    def image?
      !!(content_type =~ %r{^(image/gif|image/jpeg|image/pjpeg|image/png|image/svg+xml|image/tiff|image/vnd.djvu|image/example)\b})
    end

    def video?
      !!(content_type =~ %r{^(video/avi|video/example|video/mpeg|video/mp4|video/ogg|video/quicktime|video/webm|video/x-matroska|video/x-ms-wmv|video/x-flv)\b})
    end

    def pdf?
      !!(content_type =~ %r{^(application/pdf)\b})
    end

    #
    # Returns +true+ if the page is a HTTP redirect, returns +false+
    # otherwise.
    #
    def redirect?
      (300..307).include?(@code)
    end

    #
    # Returns +true+ if the page was not found (returned 404 code),
    # returns +false+ otherwise.
    #
    def not_found?
      404 == @code
    end

    #
    # Base URI from the HTML doc head element
    # http://www.w3.org/TR/html4/struct/links.html#edef-BASE
    #
    def base
      @base = if doc
        href = doc.search('//head/base/@href')
        URI(href.to_s) unless href.nil? rescue nil
      end unless @base
      
      return nil if @base && @base.to_s().empty?
      @base
    end


    #
    # Converts relative URL *link* into an absolute URL based on the
    # location of the page
    #
    def to_absolute(link)
      return nil if link.nil?

      # remove anchor
      # Originally anemone did this decode/encode thing, but it screws with some
      #  characters, like a ? for example, so I'm removing that part of it for now
      # link = URI.encode(URI.decode(link.to_s.gsub(/#[a-zA-Z0-9_-]*$/,'')))
      link = link.to_s.gsub(/#[a-zA-Z0-9_-]*$/,'')

      relative = URI(link)
      absolute = base ? base.merge(relative) : @url.merge(relative)

      absolute.path = '/' if absolute.path.empty?

      return absolute
    end

    #
    # Returns +true+ if *uri* is in the same domain as the page, returns
    # +false+ otherwise
    #
    def in_domain?(uri)
      uri.host == @url.host
    end

    # Returns true if this page is in one of the crawled sites
    def page_in_domain?
      !@urls.select{ |u| u.host == @url.host }.empty?
    end

    def is_subdomain?(link)
      @follow_subdomain && @follow_subdomain.include?(link.get_domain)
    end

    def marshal_dump
      [@url, @headers, @data, @body, @links, @code, @visited, @depth, @referer, @redirect_to, @response_time, @fetched]
    end

    def marshal_load(ary)
      @url, @headers, @data, @body, @links, @code, @visited, @depth, @referer, @redirect_to, @response_time, @fetched = ary
    end

    def to_hash
      {'url' => @url.to_s,
       'headers' => Marshal.dump(@headers),
       'data' => Marshal.dump(@data),
       'body' => @body,
       'links' => links.map(&:to_s), 
       'code' => @code,
       'visited' => @visited,
       'depth' => @depth,
       'referer' => @referer.to_s,
       'redirect_to' => @redirect_to.to_s,
       'response_time' => @response_time,
       'fetched' => @fetched}
    end

    def self.from_hash(hash)
      page = self.new(URI(hash['url']))
      {'@headers' => Marshal.load(hash['headers']),
       '@data' => Marshal.load(hash['data']),
       '@body' => hash['body'],
       '@links' => hash['links'].map { |link| URI(link) },
       '@code' => hash['code'].to_i,
       '@visited' => hash['visited'],
       '@depth' => hash['depth'].to_i,
       '@referer' => hash['referer'],
       '@redirect_to' => (!!hash['redirect_to'] && !hash['redirect_to'].empty?) ? URI(hash['redirect_to']) : nil,
       '@response_time' => hash['response_time'].to_i,
       '@fetched' => hash['fetched']
      }.each do |var, value|
        page.instance_variable_set(var, value)
      end
      page
    end

    def no_index?
      @skip_no_follow && doc.search("//meta[@name='robots' and contains(@content, 'noindex') and contains(@content, 'follow')]").any?
    end

  end
end
