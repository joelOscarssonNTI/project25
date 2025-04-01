require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

enable :sessions

DB = SQLite3::Database.new "db/databas.db"
DB.results_as_hash = true

def current_user
  if session[:user_id]
    @current_user ||= DB.execute("SELECT * FROM User WHERE UserID = ?", [session[:user_id]]).first
  end
end

def logged_in?
  !current_user.nil?
end

def admin?
  current_user && current_user["Username"] == "adminuser"
end

def owns_post?(post_id)
  owner = DB.execute("SELECT UserID FROM Post WHERE PostID = ?", [post_id]).first
  owner && owner["UserID"] == session[:user_id]
end

get '/' do
  @posts = DB.execute("SELECT Post.*, User.Username FROM Post JOIN User ON Post.UserID = User.UserID ORDER BY PublicationDate DESC")
  slim :"posts/index"
end

get '/signup' do
  slim :"users/signup"
end

post '/signup' do
  username = params[:username]
  password = params[:password]
  pwdigest = BCrypt::Password.create(password)
  existing_user = DB.execute("SELECT * FROM User WHERE Username = ?", [username]).first

  if existing_user.nil?
    DB.execute("INSERT INTO User (Username, pwdigest) VALUES (?, ?)", [username, pwdigest])
    redirect '/login'
  else
    @error = "Username already taken or invalid input."
    slim :"users/signup"
  end
end

get '/login' do
  slim :"users/login"
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
    slim :"users/login"
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

get '/posts/new' do
  redirect '/login' unless logged_in?
  slim :"posts/new"
end

post '/posts' do
  redirect '/login' unless logged_in?
  title = params[:title]
  content = params[:content]
  DB.execute("INSERT INTO Post (Title, Content, PublicationDate, UserID) VALUES (?, ?, datetime('now'), ?)", [title, content, session[:user_id]])
  redirect '/'
end

get '/posts/:id' do
  @post = DB.execute("SELECT Post.*, User.Username FROM Post JOIN User ON Post.UserID = User.UserID WHERE PostID = ?", [params[:id]]).first
  @likes = DB.execute("SELECT Like.*, User.Username FROM Like JOIN User ON Like.UserID = User.UserID WHERE PostID = ?", [params[:id]])
  slim :"posts/show"
end

post '/posts/:id/like' do
  redirect '/login' unless logged_in?
  existing_like = DB.execute("SELECT * FROM Like WHERE PostID = ? AND UserID = ?", [params[:id], session[:user_id]]).first
  if existing_like.nil?
    DB.execute("INSERT INTO Like (PostID, UserID, Content, Timestamp) VALUES (?, ?, ?, datetime('now'))", [params[:id], session[:user_id], params[:content]])
    DB.execute("INSERT INTO Interaction (UserID, PostID, Type, Timestamp) VALUES (?, ?, 'like', datetime('now'))", [session[:user_id], params[:id]])
  end
  redirect "/posts/#{params[:id]}"
end

get '/posts/:id/edit' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id])
  @post = DB.execute("SELECT * FROM Post WHERE PostID = ?", [params[:id]]).first
  slim :"posts/edit"
end

post '/posts/:id/update' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id])
  DB.execute("UPDATE Post SET Title = ?, Content = ? WHERE PostID = ?", [params[:title], params[:content], params[:id]])
  redirect "/posts/#{params[:id]}"
end

post '/posts/:id/delete' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id]) || admin?
  DB.execute("DELETE FROM Post WHERE PostID = ?", [params[:id]])
  redirect '/'
end

get '/error' do
  "Unauthorized action."
end