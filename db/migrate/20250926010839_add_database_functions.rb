class AddDatabaseFunctions < ActiveRecord::Migration[8.0]
  def up
    # Function to update post rating counters
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_post_rating_counters()
      RETURNS TRIGGER AS $$
      DECLARE
        post_id_to_update BIGINT;
        new_count INTEGER;
        new_sum INTEGER;
        new_avg DECIMAL(3,2);
      BEGIN
        -- Determine which post_id to update
        IF TG_OP = 'DELETE' THEN
          post_id_to_update := OLD.post_id;
        ELSE
          post_id_to_update := NEW.post_id;
        END IF;

        -- Calculate new values
        SELECT COUNT(*), COALESCE(SUM(value), 0)
        INTO new_count, new_sum
        FROM ratings
        WHERE post_id = post_id_to_update;

        -- Calculate average rating
        IF new_count > 0 THEN
          new_avg := ROUND(new_sum::DECIMAL / new_count, 2);
        ELSE
          new_avg := 0.0;
        END IF;

        -- Update the post
        UPDATE posts
        SET
          ratings_count = new_count,
          ratings_sum = new_sum,
          avg_rating = new_avg,
          updated_at = NOW()
        WHERE id = post_id_to_update;

        -- Return appropriate record
        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        ELSE
          RETURN NEW;
        END IF;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Create triggers for automatic counter updates
    execute <<-SQL
      CREATE TRIGGER trigger_update_post_rating_counters_insert
        AFTER INSERT ON ratings
        FOR EACH ROW
        EXECUTE FUNCTION update_post_rating_counters();
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_update_post_rating_counters_update
        AFTER UPDATE ON ratings
        FOR EACH ROW
        EXECUTE FUNCTION update_post_rating_counters();
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_update_post_rating_counters_delete
        AFTER DELETE ON ratings
        FOR EACH ROW
        EXECUTE FUNCTION update_post_rating_counters();
    SQL

    # Function for bulk rating creation optimization
    execute <<-SQL
      CREATE OR REPLACE FUNCTION bulk_update_post_ratings(post_ids BIGINT[])
      RETURNS VOID AS $$
      BEGIN
        UPDATE posts
        SET
          ratings_count = subquery.rating_count,
          ratings_sum = subquery.rating_sum,
          avg_rating = CASE
            WHEN subquery.rating_count > 0
            THEN ROUND(subquery.rating_sum::DECIMAL / subquery.rating_count, 2)
            ELSE 0.0
          END,
          updated_at = NOW()
        FROM (
          SELECT
            r.post_id,
            COUNT(r.value) AS rating_count,
            COALESCE(SUM(r.value), 0) AS rating_sum
          FROM ratings r
          WHERE r.post_id = ANY(post_ids)
          GROUP BY r.post_id
        ) AS subquery
        WHERE posts.id = subquery.post_id;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    # Remove triggers
    execute "DROP TRIGGER IF EXISTS trigger_update_post_rating_counters_insert ON ratings;"
    execute "DROP TRIGGER IF EXISTS trigger_update_post_rating_counters_update ON ratings;"
    execute "DROP TRIGGER IF EXISTS trigger_update_post_rating_counters_delete ON ratings;"

    # Remove functions
    execute "DROP FUNCTION IF EXISTS update_post_rating_counters();"
    execute "DROP FUNCTION IF EXISTS bulk_update_post_ratings(BIGINT[]);"
  end
end
