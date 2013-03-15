class ConnectionsController < ApplicationController


  def index
    render text: Connection.find(params)
  end

end
