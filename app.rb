require 'sinatra'
require 'slim'
require 'bcrypt'
require 'sinatra/reloader'
require_relative './model.rb'

enable :sessions

helpers do
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
    owner = post_owner(post_id)
    owner && owner["UserID"] == session[:user_id]
  end
end

# ---------------------
# Routes
# ---------------------

get '/' do
  @posts = all_posts
  slim :"posts/index"
end

get '/signup' do
  slim :"users/signup"
end

post '/signup' do
  username = params[:username]
  password = params[:password]
  existing_user = find_user_by_username(username)

  if existing_user.nil?
    create_user(username, password)
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
  user = authenticate_user(username, password)

  if user
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
  create_post(params[:title], params[:content], session[:user_id])
  redirect '/'
end

get '/posts/:id' do
  @post = find_post(params[:id])
  @likes = find_likes_for_post(params[:id])
  slim :"posts/show"
end

post '/posts/:id/like' do
  redirect '/login' unless logged_in?
  unless like_exists?(params[:id], session[:user_id])
    create_like(params[:id], session[:user_id], params[:content])
  end
  redirect "/posts/#{params[:id]}"
end

get '/posts/:id/edit' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id])
  @post = find_post(params[:id])
  slim :"posts/edit"
end

post '/posts/:id/update' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id])
  update_post(params[:id], params[:title], params[:content])
  redirect "/posts/#{params[:id]}"
end

post '/posts/:id/delete' do
  redirect '/login' unless logged_in?
  redirect '/error' unless owns_post?(params[:id]) || admin?
  delete_post(params[:id])
  redirect '/'
end

get '/error' do
  "Unauthorized action."
end
