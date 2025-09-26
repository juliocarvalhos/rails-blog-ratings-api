class CreateInitialSchema < ActiveRecord::Migration[8.0]
  def change
    # Enable PostgreSQL extensions
    enable_extension "plpgsql"

    # Users table
    create_table :users do |t|
      t.string :login, null: false
      t.timestamps
    end

    add_index :users, :login, unique: true

    # Posts table
    create_table :posts do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.inet :ip, null: false
      t.decimal :avg_rating, precision: 3, scale: 2, default: 0.0
      t.integer :ratings_count, default: 0, null: false
      t.integer :ratings_sum, default: 0, null: false
      t.timestamps
    end

    add_foreign_key :posts, :users
    add_index :posts, :user_id
    add_index :posts, :ip
    add_index :posts, :avg_rating
    add_index :posts, :created_at
    add_index :posts, [ :ip, :user_id ], name: "index_posts_ip_user"
    add_index :posts, [ :user_id, :avg_rating ], name: "index_posts_user_rating"

    # Ratings table
    create_table :ratings do |t|
      t.bigint :post_id, null: false
      t.bigint :user_id, null: false
      t.integer :value, null: false
      t.timestamps
    end

    add_foreign_key :ratings, :posts
    add_foreign_key :ratings, :users
    add_index :ratings, :post_id
    add_index :ratings, :user_id
    add_index :ratings, :created_at
    add_index :ratings, [ :user_id, :post_id ], unique: true

    # Custom calculated average rating index
    execute <<-SQL
      CREATE INDEX index_posts_on_calculated_avg_rating ON posts USING btree ((
        CASE
          WHEN (ratings_count > 0) THEN ((ratings_sum)::double precision / (ratings_count)::double precision)
          ELSE (0)::double precision
        END
      ));
    SQL
  end
end
