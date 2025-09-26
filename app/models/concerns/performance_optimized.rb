# Performance optimization concerns for high-volume operations
module PerformanceOptimized
  extend ActiveSupport::Concern

  class_methods do
    # Bulk insert for better performance with large datasets
    def bulk_insert(records, batch_size: 1000)
      records.each_slice(batch_size) do |batch|
        insert_all(batch, returning: false)
      end
    end

    # Efficient counting with cache-friendly approach
    def efficient_count
      Rails.cache.fetch("#{name.downcase}_count", expires_in: 5.minutes) do
        count
      end
    end
  end
end
