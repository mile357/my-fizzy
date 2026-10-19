class Initiatives::CheckpointsController < ApplicationController
  before_action :ensure_initiatives_enabled
  before_action :ensure_admin
  before_action :set_initiative
  before_action :set_checkpoint, only: %i[ update destroy ]

  def create
    @checkpoint = @initiative.checkpoints.build(checkpoint_params)

    if @checkpoint.save
      InitiativeActivity.track(@initiative, action: "milestone_added", description: "Added milestone \"#{@checkpoint.content}\"")

      respond_to do |format|
        format.html { redirect_to initiative_path(@initiative) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to initiative_path(@initiative), alert: @checkpoint.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("initiative_checkpoints_#{@initiative.id}", partial: "initiatives/checkpoints", locals: { initiative: @initiative }), status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if params[:checkpoint] && params[:checkpoint].key?(:completed)
      completed_value = ActiveRecord::Type::Boolean.new.cast(params[:checkpoint][:completed])
      @checkpoint.update(completed: completed_value, completed_at: (completed_value ? Time.current : nil))
      action = completed_value ? "milestone_completed" : "milestone_reopened"
      desc = completed_value ? "Completed milestone \"#{@checkpoint.content}\"" : "Reopened milestone \"#{@checkpoint.content}\""
      InitiativeActivity.track(@initiative, action: action, description: desc)
    else
      @checkpoint.update(checkpoint_params)
    end

    respond_to do |format|
      format.html { redirect_to initiative_path(@initiative) }
      format.turbo_stream
    end
  end

  def destroy
    content = @checkpoint.content
    @checkpoint.destroy
    InitiativeActivity.track(@initiative, action: "milestone_removed", description: "Removed milestone \"#{content}\"")

    respond_to do |format|
      format.html { redirect_to initiative_path(@initiative) }
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
