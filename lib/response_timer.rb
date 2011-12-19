module Rack
  class ResponseTimer

    def initialize(app)
      @app = app
    end

    def call(env)
      started = Time.now

      status, headers, body = @app.call(env)

      body << "<!-- Response Time: #{Time.now-started} seconds -->"
      headers['Content-Length'] = (Rack::Utils.bytesize(body.to_s) - 8).to_s

      [status, headers, body]
    end
  end
end
