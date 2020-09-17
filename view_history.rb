# frozen_string_literal: true

# Module to store ActiveAdmin view history action
module ViewHistory
  extend ActiveSupport::Concern
  def self.included(base)
    base.send(:member_action, :history) do
      entity = if params['id'].to_i.zero?
                 resource.class.friendly.find(params[:id])
               else
                 resource.class.find(params[:id])
               end
      @versions = PaperTrail::Version.where(item_type: resource.class.to_s,
                                            item_id: entity.id)
      if Admin::AdminPolicy.new(current_admin_user, @versions).history?
        render 'admin/history'
      else
        flash[:error] = 'You are not authorized to perform this action'
        redirect_to resource_path
      end
    end

    base.send(:action_item, :view_history,
              class: 'history_action',
              only: :show,
              if: proc { current_admin_user.can_see_history? && resource.versions.present? }) do
      link_to 'View Versions History', "#{resource_path}/history"
    end

    base.send(:sidebar, :versionate,
              only: :show,
              if: proc { current_admin_user.can_see_history? }) do
      render 'admin/version'
    end

    base.send(:before_action, only: :show) do
      find_versions
    end

    base.send(:member_action, :find_versions) do
      entity = if params['id'].to_i.zero?
                 resource.class.includes(versions: :item).friendly.find(params[:id])
               else
                 resource.class.includes(versions: :item).find(params[:id])
               end
      str = resource.class.table_name.singularize
      instance_variable_set("@#{str}", entity)
      @versions = instance_variable_get("@#{str}").versions
      if params[:version]
        entity = instance_variable_get("@#{str}").versions[params[:version].to_i].reify
        instance_variable_set("@#{str}", entity)
      end
    end
  end
end
