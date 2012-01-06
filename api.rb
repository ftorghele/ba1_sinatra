require './lib/response_timer'
require './lib/gc_stats'
require 'sinatra'
require 'sinatra/activerecord'
require 'json'

# Article Class
class Article < ActiveRecord::Base

  validates_presence_of :title
  validates_presence_of :text

  scope :find_prev, lambda { |id| { :conditions => [ "id < :id", { :id => id } ] } }
  scope :find_next, lambda { |id| { :conditions => [ "id > :id", { :id => id } ] } }
end

#ArticleApi Application
class ArticleApi < Sinatra::Base

  use ResponseTimer
  #use GCStats

  helpers do
    def api_links(action = nil, id = nil)
      case action
        when :entryPoint
          [ { :link => { :rel => "all", :uri => "/articles/"} },
            { :link => { :rel => "new", :uri => "/articles/"} }]
        when :allArticles
          [ { :link => { :rel => "new", :uri => "/articles/"} } ]
        when :article
          next_record = Article.find_next(id).first
          prev_record = Article.find_prev(id).last
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

    def return_json_status(code, msg)
      status code
      {
        :status => code,
        :reason => msg,
        :api => api_links(:errorResponse)
      }.to_json
    end
  end

  # GET / - entry point
  get "/", :provides => :json do
    content_type :json
    {
      :api => api_links(:entryPoint)
    }.to_json
  end

  # GET /articles - return all articles
  get "/articles/?", :provides => :json do
    content_type :json
    {
      :content => Article.all.collect{ |a| { :title => a.title, :text => a.text, :api => api_links(:article, a.id)} },
      :api => api_links(:allArticles)
    }.to_json
  end

  ## GET /articles/:id - return article with specified id
  get "/articles/:id", :provides => :json do
    content_type :json

    if article = Article.find_by_id(params[:id].to_i)
      {
        :content => article,
        :api => api_links(:article, article.id)
      }.to_json
    else
      return_json_status 404, "Not found"
    end

  end

  ## POST /articles/ - create new article
  post "/articles/?", :provides => :json do
    content_type :json

    article = Article.new(:title => params[:title], :text => params[:text])
    if article.save
      headers["Location"] = "/article/#{article.id}"
      status 201 # Created
      {
        :content => article,
        :api => api_links(:article, article.id)
      }.to_json
    else
      return_json_status 400, article.errors.to_hash
    end
  end

  # PUT /articles/:id - change a whole article
  put "/articles/:id", :provides => :json do
    content_type :json

    if article = Article.find_by_id(params[:id].to_i)

      article.title = params[:title] unless params[:title].nil?
      article.text = params[:text] unless params[:text].nil?

      if article.save
        {
          :content => article,
          :api => api_links(:article, article.id)
        }.to_json
      else
        return_json_status 400, article.errors.to_hash
      end
    else
      return_json_status 404, "Not found"
    end
  end

  # DELETE /articles/:id - delete a article
  delete "/articles/:id/?", :provides => :json do
    content_type :json

    if article = Article.find_by_id(params[:id].to_i)
      article.destroy!
      status 204 # No content
    else
      return_json_status 404, "Not found"
    end
  end

  # Handle wrong requests
  get "*" do status 404 end
  post "*" do status 404 end
  put "*" do status 404 end
  delete "*" do status 404 end
end