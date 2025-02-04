require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

enable :sessions

db = SQLite3::Database.new('db/projekt2025.db')

get('/') do
  slim(:register)
end

get('/showlogin') do
  slim(:login)
end

post('/login') do
  username = params[:username]
  password = params[:password]
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?", username).first
  if result && BCrypt::Password.new(result['pwdigest']) == password
    session[:user_id] = result['user_id']
    redirect('/posts')
  else
    "Fel användarnamn eller lösenord"
  end
end

get('/posts') do
  user_id = session[:user_id].to_i
  db.results_as_hash = true
  result = db.execute("SELECT * FROM posts WHERE user_id = ?", user_id)
  slim(:"posts/index", locals: { posts: result })
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO users (username, pwdigest) VALUES (?, ?)", [username, password_digest])
    redirect('/showlogin')
  else
    "Lösenordet matchade inte"
  end
end

get '/new_post' do
  slim :new_post
end

post '/create_post' do
  user_id = session[:user_id]
  db.execute 'INSERT INTO posts (user_id, title, content, ingredients, instructions, image_path) VALUES (?, ?, ?, ?, ?, ?)',
             [user_id, params[:title], params[:content], params[:ingredients], params[:instructions], params[:image_path]]
  redirect '/posts'
end
