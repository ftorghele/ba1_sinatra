require './lib/response_timer'
require 'sinatra'
require 'json'

require 'data_mapper'
require 'dm-types'
require 'dm-timestamps'
require 'dm-validations'

# Article Class
class Article
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :required => true
  property :text, String, :required => true

  #property :created_at, DateTime
  #property :updated_at, DateTime
end

#Setup Database
DataMapper.setup(:default, "sqlite3:article.db")
DataMapper.auto_upgrade!

#ArticleApi Application
class ArticleApi < Sinatra::Base

  use ResponseTimer

  helpers do
    def return_json_status(code, msg)
      status code
      {
        :status => code,
        :reason => msg
      }.to_json
    end
  end

  # GET /article - return all articles
  get "/articles/?", :provides => :json do
    content_type :json

    Article.all.to_json
  end

  ## GET /article/:id - return article with specified id
  get "/articles/:id", :provides => :json do
    content_type :json

    if article = Article.first(:id => params[:id].to_i)
      article.to_json
    else
      return_json_status 404, "Not found"
    end

  end

  ## POST /article/ - create new article
  post "/articles/?", :provides => :json do
    content_type :json

    article = Article.new(:title => params[:title], :text => params[:text])
    if article.save
      headers["Location"] = "/article/#{article.id}"
      status 201 # Created
      article.to_json
    else
      return_json_status 400, article.errors.to_hash
    end
  end

  # PUT /article/:id - change a whole article
  put "/articles/:id", :provides => :json do
    content_type :json

    if article = Article.first(:id => params[:id].to_i)

      article.title = params[:title] unless params[:title].nil?
      article.text = params[:text] unless params[:text].nil?

      if article.save
        article.to_json
      else
        return_json_status 400, article.errors.to_hash
      end
    else
      return_json_status 404, "Not found"
    end
  end

  # DELETE /article/:id - delete a article
  delete "/articles/:id/?", :provides => :json do
    content_type :json

    if article = Article.first(:id => params[:id].to_i)
      article.destroy!
      status 204 # No content
    else
      return_json_status 404, "Not found"
    end
  end
end