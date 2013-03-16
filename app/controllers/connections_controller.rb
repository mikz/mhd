class ConnectionsController < ApplicationController
  expose(:connection) { Connection.find(params) }

  def index
    respond_with connection
  end
end
