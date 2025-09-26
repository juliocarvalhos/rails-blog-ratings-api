module DatabaseFunctions
  extend ActiveSupport::Concern

  class_methods do
    # Get top N posts using database function
    def top_rated_via_function(limit = 10)
      sql = "SELECT * FROM get_top_rated_posts(#{limit.to_i})"
      connection.execute(sql).map do |row|
        {
          "id" => row["id"].to_i,
          "title" => row["title"],
          "body" => row["body"],
          "avg_rating" => row["avg_rating"].to_f
        }
      end
    end

    # Get IPs with multiple authors using database function
    def ips_with_multiple_authors_via_function
      sql = "SELECT * FROM get_ips_with_multiple_authors()"
      connection.execute(sql).map do |row|
        {
          "ip" => row["ip"],
          "authors" => row["authors"]&.gsub(/[{}]/, "")&.split(",") || []
        }
      end
    end
  end

  # Calculate average rating using database function
  def avg_rating_via_function
    sql = "SELECT calculate_post_avg_rating(#{id}) as avg_rating"
    result = self.class.connection.execute(sql).first
    result["avg_rating"].to_f
  end
end
