#require './lib/response_timer'
#require './lib/gc_stats'
#require 'rack/perftools_profiler'

require 'sinatra'
require 'json'
require 'to_xml'

require 'data_mapper'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'

require 'will_paginate'
require 'will_paginate/data_mapper'

# Article Class
class Article
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :required => true
  property :text, String, :required => true

  #property :created_at, DateTime
  #property :updated_at, DateTime

  def self.find_next(id)
    Article.first(:id.gt =>  id)
  end

  def self.find_prev(id)
    Article.last(:id.lt =>  id)
  end
end

#Setup Database
DataMapper.setup(:default, "sqlite3:article.db")
DataMapper.auto_upgrade!

#ArticleApi Application
class ArticleApi < Sinatra::Base

  configure do
    #use ResponseTimer
    #use GCStats
    #use ::Rack::PerftoolsProfiler, :default_printer => 'text', :mode => 'cputime', :frequency => 1000
  end

  def self.new(*)
    app = Rack::Auth::Digest::MD5.new(super) do |username|
      {'foo' => 'bar'}[username]
    end
    app.realm = 'Protected Area'
    app.opaque = 'secretkey'
    app
  end

  helpers do
    def api_links(action = nil, id = nil)
      case action
        when :entryPoint
          [ { :link => { :rel => "all", :uri => "/articles/"} },
            { :link => { :rel => "new", :uri => "/articles/"} }]
        when :allArticles
          [ { :link => { :rel => "new", :uri => "/articles/"} } ]
        when :article
          next_record = Article.find_next(id)
          prev_record = Article.find_prev(id)
          [ { :link => { :rel => "self", :uri => "/articles/#{id}"} },
            { :link => { :rel => "update", :uri => "/articles/#{id}"} },
            { :link => { :rel => "delete", :uri => "/articles/#{id}"} },
            { :link => { :rel => "next", :uri => next_record.nil? ? nil : "/articles/#{next_record.id}"} },
            { :link => { :rel => "prev", :uri => prev_record.nil? ? nil : "/articles/#{prev_record.id}"} }]
        when :errorResponse
          [ { :link => { :rel => "all", :uri => "/articles/"} },
            { :link => { :rel => "new", :uri => "/articles/"} }]
      end
    end

    def respond_with(data)
      request.accept.each do |type|
        case type
        when 'application/json', 'text/json'
          content_type :json
          halt data.to_json
        else
          content_type :xml
          halt data.to_xml
        end
      end
    end

    def return_status(code, msg)
      status code
      respond_with({
        :status => code,
        :reason => msg,
        :api => api_links(:errorResponse)
      })
    end
  end

  # GET / - entry point
  get "/" do
    respond_with(:response => {
      :api => api_links(:entryPoint)
    })
  end

  # GET /articles - return all articles
  get "/articles/?" do
    authenticate!
    respond_with(:response => {
      :content => Article.paginate(:page => params[:page], :per_page => 10).collect{ |a| { :title => a.title, :text => a.text, :api => api_links(:article, a.id)} },
      :api => api_links(:allArticles)
    })
  end

  ## GET /articles/:id - return article with specified id
  get "/articles/:id" do
    if article = Article.first(:id => params[:id].to_i)
      respond_with(:response => {
        :content => article.to_xml,
        :api => api_links(:article, article.id)
      })
    else
      return_status 404, "Not found"
    end
  end

  ## POST /articles/ - create new article
  post "/articles/?" do
    article = Article.new(:title => params[:title], :text => params[:text])
    if article.save
      headers["Location"] = "/article/#{article.id}"
      status 201 # Created

      respond_with(:response => {
        :content => article.to_xml,
        :api => api_links(:article, article.id)
      })
    else
      return_status 400, article.errors.to_hash
    end
  end

  # PUT /articles/:id - change a whole article
  put "/articles/:id" do
    if article = Article.first(:id => params[:id].to_i)

      article.title = params[:title] unless params[:title].nil?
      article.text = params[:text] unless params[:text].nil?

      if article.save
        respond_with(:response => {
          :content => article.to_xml,
          :api => api_links(:article, article.id)
        })
      else
        return_status 400, article.errors.to_hash
      end
    else
      return_status 404, "Not found"
    end
  end

  # DELETE /articles/:id - delete a article
  delete "/articles/:id/?" do
    if article = Article.first(:id => params[:id].to_i)
      article.destroy!
      status 204 # No content
    else
      return_status 404, "Not found"
    end
  end

  # Handle wrong requests
  get "*" do status 404 end
  post "*" do status 404 end
  put "*" do status 404 end
  delete "*" do status 404 end
end