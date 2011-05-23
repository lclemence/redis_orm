module RedisOrm
  module Associations
    module BelongsTo
      # class Avatar < RedisOrm::Base
      #   belongs_to :user
      # end 
      #
      # class User < RedisOrm::Base
      #   has_many :avatars
      # end 
      #
      # avatar.user => avatar:234:user => 1 => User.find(1)
      def belongs_to(foreign_model, options = {})
        class_associations = class_variable_get(:"@@associations")
        class_variable_get(:"@@associations")[model_name] << {:type => :belongs_to, :foreign_model => foreign_model, :options => options}

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        define_method foreign_model_name.to_sym do
          foreign_model.to_s.camelize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model_name}")
        end

        # look = Look.create :title => 'test'
        # look.user = User.find(1) => look:23:user => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          if assoc_with_record.model_name == foreign_model.to_s
            $redis.set("#{model_name}:#{id}:#{foreign_model_name}", assoc_with_record.id)
          else
            raise TypeMismatchError
          end

          # check whether *assoc_with_record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if class_associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} && !$redis.zrank("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id)            
            assoc_with_record.send(model_name.pluralize.to_sym).send(:"<<", self)

          # check whether *assoc_with_record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          elsif class_associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?
            assoc_with_record.send("#{model_name}=", self)            
          end
        end
      end
    end
  end
end
