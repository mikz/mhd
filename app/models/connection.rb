class Connection
  # attr_accessible :title, :body

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

    msg = HTTPClient.get(URL_BASE, params(from, to))
    location = msg.header['Location'].join
    URL_BASE.merge(location)
  end

  def self.params(from, to)
    DEFAULT_PARAMS.merge(f: from, t: to).to_query
  end
end
