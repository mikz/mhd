class Connection
  include Benchmarkable

  attr_reader :from, :to

  DEFAULT_PARAMS = {
      isdep: 1,
      sp: 0,
      alg: 1,
      dev: 1,
      deval: 250,
      tid: 'CityAll|152|153',
      std: '1|1',
      min: '-1|-1',
      max: '60|600',
      tt: 'PID',
      fvl: 301003,
      tvl: 301003,
      res: 1
  }
  URL_BASE = URI.parse('http://spojeni.dpp.cz/ConnForm.aspx')

  def self.find(params)
    from, to = params.slice(:from, :to).values
    new(from, to)
  end

  def initialize(from, to)
    @from, @to = from, to
  end

  def bookmark
    benchmark "Getting bookmark" do
      @bookmark ||= HTTPClient.get(URL_BASE, bookmark_params)
    end
  end

  def connection_url
    location = bookmark.header['Location'].join
    URL_BASE.merge(location)
  end

  def html
    benchmark "Getting html for" do
      @html ||= HTTPClient.get_content(connection_url)
    end
  end

  def bookmark_params
    DEFAULT_PARAMS.merge(f: from, t: to).to_query
  end

  delegate :to_json, to: :routes

  def routes
    @routes ||= parser.get_routes
  end

  def parser
    @parser ||= Parser.new(html)
  end

  class Route
    def initialize(date, from, to, parts)
      @date, @from, @to, @parts = date, from, to, parts
    end

    def as_json(options = {})
      {
          date: @date,
          from: @from,
          to: @to,
          parts: @parts
      }
    end
  end


  class Parser
    include Benchmarkable

    def initialize(html)
      benchmark "Initializing parser" do
        @html = html
        @doc = Nokogiri::HTML(html)
      end
    end

    def route_elements
      summary = @doc.search('h2.souhrn-spojeni')
      details = @doc.search('div.spojeni')

      summary.zip(details)
    end

    def get_routes
      benchmark "Parsing routes" do
        route_elements.map do |summary, details|
          date = summary.search('.date').text # 16.3.2013 10:28:00
          from, to = details.search("h3 strong").children.minmax.map{ |node| node.text.strip }
          parts = details.search('> p').map { |element| RoutePart.for(element) }.compact

          Route.new(date, from, to, parts)
        end
      end
    end

    class RoutePart
      def self.for(element)
        klass = case element['class']
          when 'usek'
            Usek
          when 'walk'
            Walk
          when 'note'
            # ignore
          else
            raise "Unknown line type: #{type}"
        end

        klass && klass.new(element)
      end

      def initialize(element)
        @element = element
      end

      def as_json(options = {}); end

      class Node
        def initialize(element)
          @element = element
        end

        def station
          @station ||= a.text
        end

        def time
          @time ||= @element.xpath("text()").text.last(5)
        end

        def as_json(options = {})
          { sation: station, time: time}
        end

        protected

        def a
          @a ||= @element.search('a')
        end
      end

      class Line
        def initialize(element)
          @element = element
        end

        def kind
          @kind ||= texts[0].text.strip
        end

        def number
          @number ||= texts[1].text.strip
        end

        def as_json(options = {})
          { kind: kind, number: number}
        end

        protected

        def texts
          @texts ||= link.search('span')
        end

        def link
          @link ||= @element.search('a')
        end
      end

      class Usek < RoutePart
        def start
          @start ||= Node.new(@element.search('.start'))
        end

        def destination
          @destination ||= Node.new(@element.search('.cil'))
        end

        def line
          @line ||= Line.new(@element.search('.start + span'))
        end

        def as_json(options = {})
          { kind: :mhd, line: line, start: start, destination: destination }
        end
      end

      class Walk < RoutePart
        def description
          @element.children.first.text.strip
        end

        def as_json(options = {})
          { kind: :walk, description: description }
        end
      end
    end
  end
end
