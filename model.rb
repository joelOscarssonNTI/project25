require 'sqlite3'
require 'bcrypt'

DB = SQLite3::Database.new "db/databas.db"
DB.results_as_hash = true

# ---------------------
# Användarhantering
# ---------------------

def find_user_by_username(username)
  DB.execute("SELECT * FROM User WHERE Username = ?", [username]).first
end

def create_user(username, password)
  pwdigest = BCrypt::Password.create(password)
  DB.execute("INSERT INTO User (Username, pwdigest) VALUES (?, ?)", [username, pwdigest])
end

def authenticate_user(username, password)
  user = find_user_by_username(username)
  return nil unless user && BCrypt::Password.new(user['pwdigest']) == password
  user
end

# ---------------------
# Inläggshantering
# ---------------------

def all_posts
  DB.execute("SELECT Post.*, User.Username FROM Post JOIN User ON Post.UserID = User.UserID ORDER BY PublicationDate DESC")
end

def create_post(title, content, user_id)
  DB.execute("INSERT INTO Post (Title, Content, PublicationDate, UserID) VALUES (?, ?, datetime('now'), ?)", [title, content, user_id])
end

def find_post(post_id)
  DB.execute("SELECT Post.*, User.Username FROM Post JOIN User ON Post.UserID = User.UserID WHERE PostID = ?", [post_id]).first
end

def update_post(post_id, title, content)
  DB.execute("UPDATE Post SET Title = ?, Content = ? WHERE PostID = ?", [title, content, post_id])
end

def delete_post(post_id)
  DB.execute("DELETE FROM Post WHERE PostID = ?", [post_id])
end

def post_owner(post_id)
  DB.execute("SELECT UserID FROM Post WHERE PostID = ?", [post_id]).first
end

# ---------------------
# Likes
# ---------------------

def find_likes_for_post(post_id)
  DB.execute("SELECT Like.*, User.Username FROM Like JOIN User ON Like.UserID = User.UserID WHERE PostID = ?", [post_id])
end

def like_exists?(post_id, user_id)
  DB.execute("SELECT * FROM Like WHERE PostID = ? AND UserID = ?", [post_id, user_id]).first
end

def create_like(post_id, user_id, content)
  DB.execute("INSERT INTO Like (PostID, UserID, Content, Timestamp) VALUES (?, ?, ?, datetime('now'))", [post_id, user_id, content])
  DB.execute("INSERT INTO Interaction (UserID, PostID, Type, Timestamp) VALUES (?, ?, 'like', datetime('now'))", [user_id, post_id])
end