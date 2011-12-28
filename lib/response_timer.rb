class ResponseTimer

  require 'logger'

  def initialize(app)
    @app = app
  end

  def call(env)
    started = Time.now

    status, headers, body = @app.call(env)

    log = Logger.new('response_time.txt')

    unless headers["Content-Type"].nil?
      log.debug "#{Time.now-started}" if headers["Content-Type"].include? "application/json"
    end

    [status, headers, body]
  end
end
