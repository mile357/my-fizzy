class Initiatives::CheckpointsController < ApplicationController
  before_action :ensure_initiatives_enabled
  before_action :ensure_admin
  before_action :set_initiative
  before_action :set_checkpoint, only: %i[ update destroy ]

  def create
    @checkpoint = @initiative.checkpoints.build(checkpoint_params)

    saved = Checkpoint.transaction do
      if @checkpoint.save
        InitiativeActivity.track(@initiative, action: "milestone_added", description: "Added milestone \"#{@checkpoint.content}\"")
        true
      else
        false
      end
    end

    if saved
      respond_to do |format|
        format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to initiatives_path(initiative_id: @initiative.id), alert: @checkpoint.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("initiative_checkpoints_#{@initiative.id}", partial: "initiatives/checkpoints", locals: { initiative: @initiative }), status: :unprocessable_entity
        end
      end
    end
  end

  def update
    Checkpoint.transaction do
      attrs = checkpoint_params.to_h
      if attrs.key?("completed") || attrs.key?(:completed)
        raw_completed = attrs.key?(:completed) ? attrs[:completed] : attrs["completed"]
        completed_value = ActiveRecord::Type::Boolean.new.cast(raw_completed)
        attrs[:completed] = completed_value
        attrs[:completed_at] = completed_value ? Time.current : nil
      end

      if @checkpoint.update(attrs) && @checkpoint.saved_change_to_completed?
        completed_now = @checkpoint.completed?
        action = completed_now ? "milestone_completed" : "milestone_reopened"
        desc = completed_now ? "Completed milestone \"#{@checkpoint.content}\"" : "Reopened milestone \"#{@checkpoint.content}\""
        InitiativeActivity.track(@initiative, action: action, description: desc)
      end
    end

    respond_to do |format|
      format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
      format.turbo_stream
    end
  end

  def destroy
    content = @checkpoint.content
    Checkpoint.transaction do
      @checkpoint.destroy!
      InitiativeActivity.track(@initiative, action: "milestone_removed", description: "Removed milestone \"#{content}\"")
    end

    respond_to do |format|
      format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
      format.turbo_stream
    end
  end

  private
    def ensure_initiatives_enabled
      head :not_found unless Current.account.initiatives_enabled?
    end

    def set_initiative
      @initiative = Current.account.tags.find(params[:initiative_id])
    end

    def set_checkpoint
      @checkpoint = @initiative.checkpoints.find(params[:id])
    end

    def checkpoint_params
      params.expect(checkpoint: [ :content, :completed ])
    end
end
