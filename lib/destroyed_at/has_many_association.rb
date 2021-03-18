module DestroyedAt
  module HasManyAssociation
    def delete_records(records, method)
      if method == :destroy
        records.each do |record|
          next if record.destroyed?

          if record.respond_to?(:destroyed_at) && owner.respond_to?(:destroyed_at)
            record.destroy(owner.destroyed_at)
          else
            record.destroy
          end
        end
        update_counter(-records.length) unless reflection.inverse_updates_counter_cache?
      else
        super
      end
    end
  end
end

ActiveRecord::Associations::HasManyAssociation.send(:prepend, DestroyedAt::HasManyAssociation)
