module Helioth
  module Dsl
    ## Configure roles
    def roles(&block)
      @roles ||= Role.new(&block)
    end

    ## Configure relations
    def relations(&block)
      @relations ||= Relation.new(&block)
    end

    ## Configure features
    def features(&block)
      if block
        @features ||= Features.new(&block)
      else
        @features.list
      end
    end

    ## Get feature
    def feature(feature_name)
      @features.list.map{|feature|
        feature if feature.name == feature_name
      }.compact.first
    end

    ## Get feature action
    def action(feature_name, action_name)
      feature(feature_name).actions.map{|action|
        action if action.name == action_name
      }.compact.first
    end

    ## Check authorization
    def authorized_for_locale?(feature_name, *actions_name, locale)
      authorized_for(feature_name, actions_name.flatten, {locale: locale})
    end

    def authorized_for_user?(feature_name, *actions_name, role)
      authorized_for(feature_name, actions_name.flatten, {role: role, type: :user})
    end

    def authorized_for_instance?(feature_name, *actions_name, role)
      authorized_for(feature_name, actions_name.flatten, {role: role, type: :instance})
    end

    private
    def authorized_for(feature_name, actions_name, options={})

      role = options[:role]
      type = options[:type]
      locale = options[:locale]

      feature, actions = process_input(feature_name, actions_name)

      if feature

        ## If a feature doesn"t have relation (ex: disabled feature)
        return false if role.present? && relations.feature[feature.status].blank?

        access = Array.new
        access << relations.feature[feature.status][type].include?(role) if role.present?
        access << feature.locales.include?(locale) if locale.present?

        if actions.any?
          access += actions.map{|action|
            if role.present?
              relations.feature[action.status][type].include?(role)
            elsif locale.present?
              action.locales.include?(locale)
            end
          }
        end

        access.all?
      else
        Rails.logger.info("Feature #{feature.try(:name)} not found")
        false
      end
    rescue
      raise "Error in method #{__method__} of #{__FILE__}"
    end

    def process_input(feature_name, actions_name)
      feature = feature(feature_name)
      actions = actions_name.flatten.map{|action_name|
        action(feature_name, action_name)
      }
      return([feature, actions])
    end
  end
end
