class Blog::Api::IpsController < Blog::Api::BaseController
  def index
    # Use database function for improved performance
    if params[:use_function] == "true"
      ips_data = Post.ips_with_multiple_authors_via_function
      render_success(
        ips_data.map do |ip_data|
          {
            ip: ip_data["ip"],
            authors: ip_data["authors"]
          }
        end
      )
    else
      # Use ActiveRecord approach
      results = Post.joins(:user)
                    .group(:ip)
                    .having("COUNT(DISTINCT users.login) > 1")
                    .pluck(
                      Arel.sql("ip"),
                      Arel.sql("ARRAY_AGG(DISTINCT users.login) as author_logins")
                    )

      ips_with_multiple_authors = results.map do |ip, logins_array|
        {
          ip: ip.to_s,
          authors: logins_array
        }
      end

      render_success(ips_with_multiple_authors)
    end
  end
end
