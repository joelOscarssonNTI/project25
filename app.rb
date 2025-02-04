require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader' if development?

enable :sessions

DB = SQLite3::Database.new "blog.db"
DB.results_as_hash = true

def current_user
  if session[:user_id]
    @current_user ||= DB.execute("SELECT * FROM User WHERE UserID = ?", [session[:user_id]]).first
  end
end

def logged_in?
  !current_user.nil?
end

get '/' do
  @posts = DB.execute("SELECT * FROM Post ORDER BY PublicationDate DESC")
  slim :index
end

get '/signup' do
  slim :signup
end

post '/signup' do
  username = params[:username]
  password = params[:password]
  pwdigest = BCrypt::Password.create(password)
  
  begin
    DB.execute("INSERT INTO User (Username, Password, pwdigest) VALUES (?, ?, ?)", [username, password, pwdigest])
    redirect '/login'
  rescue SQLite3::Exception
    @error = "Username already taken or invalid input."
    slim :signup
  end
end

get '/login' do
  slim :login
end

post '/login' do
  username = params[:username]
  password = params[:password]
  user = DB.execute("SELECT * FROM User WHERE Username = ?", [username]).first

  if user && BCrypt::Password.new(user['pwdigest']) == password
    session[:user_id] = user['UserID']
    redirect '/'
  else
    @error = "Invalid credentials."
    slim :login
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

get '/posts/new' do
  redirect '/login' unless logged_in?
  slim :new_post
end

post '/posts' do
  redirect '/login' unless logged_in?
  title = params[:title]
  content = params[:content]
  DB.execute("INSERT INTO Post (Title, Content, PublicationDate) VALUES (?, ?, datetime('now'))", [title, content])
  redirect '/'
end

get '/posts/:id' do
  @post = DB.execute("SELECT * FROM Post WHERE PostID = ?", [params[:id]]).first
  @likes = DB.execute("SELECT * FROM Like WHERE PostID = ?", [params[:id]])
  slim :post_detail
end

post '/posts/:id/like' do
  redirect '/login' unless logged_in?
  content = params[:content] || ""
  DB.execute("INSERT INTO Like (PostID, UserID, Content, Timestamp) VALUES (?, ?, ?, datetime('now'))", [params[:id], session[:user_id], content])
  DB.execute("INSERT INTO Interaction (UserID, PostID, Type, Timestamp) VALUES (?, ?, 'like', datetime('now'))", [session[:user_id], params[:id]])
  redirect "/posts/#{params[:id]}"
end