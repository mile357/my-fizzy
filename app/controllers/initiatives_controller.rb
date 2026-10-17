class InitiativesController < ApplicationController
  before_action :ensure_initiatives_enabled
  before_action :set_initiative, only: %i[ show update destroy ]

  def index
    @initiatives = initiatives_scope
    set_tags_data
    @active_initiative = params[:initiative_id].present? ? @initiatives.find_by(id: params[:initiative_id]) : @initiatives.first
    if @active_initiative
      @cards = @active_initiative.cards.open.preload(:board, :column, :assignees, :creator)
      @closed_cards_count = @active_initiative.cards.closed.count
    end
  end

  def show
    @initiatives = initiatives_scope
    @cards = @initiative.cards.open.preload(:board, :column, :assignees, :creator)
    @closed_cards_count = @initiative.cards.closed.count
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    clean_title = initiative_params[:title].to_s.strip.delete_prefix("#")
    if clean_title.blank?
      redirect_to initiatives_path and return
    end

    @initiative = Current.account.tags.find_or_create_by!(title: clean_title)
    @initiative.update!(initiative_params.except(:title)) if initiative_params.except(:title).present?

    desc = @initiative.initiative? ? "Created initiative #{@initiative.hashtag}" : "Created tag #{@initiative.hashtag}"
    action = @initiative.initiative? ? "initiative_created" : "tag_created"
    InitiativeActivity.track(
      @initiative,
      action: action,
      description: desc,
      particulars: { end_date: @initiative.end_date&.iso8601 }
    )
    @initiatives = initiatives_scope
    set_tags_data
    @cards = @initiative.cards.open.preload(:board, :column, :assignees, :creator)
    @closed_cards_count = @initiative.cards.closed.count

    respond_to do |format|
      format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
      format.turbo_stream
    end
  end

  def update
    old_start = @initiative.start_date
    old_end = @initiative.end_date
    @initiative.update!(initiative_params)
    if @initiative.start_date != old_start || @initiative.end_date != old_end
      desc = if @initiative.start_date && @initiative.end_date
        "Changed dates to #{@initiative.start_date.strftime('%b %d, %Y')} – #{@initiative.end_date.strftime('%b %d, %Y')}"
      elsif @initiative.end_date
        "Changed target date to #{@initiative.end_date.strftime('%b %d, %Y')}"
      elsif @initiative.start_date
        "Changed start date to #{@initiative.start_date.strftime('%b %d, %Y')}"
      else
        "Cleared schedule dates"
      end
      InitiativeActivity.track(
        @initiative,
        action: "dates_changed",
        description: desc,
        particulars: {
          old_start_date: old_start&.iso8601,
          old_end_date: old_end&.iso8601,
          start_date: @initiative.start_date&.iso8601,
          end_date: @initiative.end_date&.iso8601
        }
      )
    end
    if @initiative.start_date.nil? && @initiative.end_date.nil? && @initiative.color.present?
      @initiative.update!(color: nil)
    end
    @initiatives = initiatives_scope
    set_tags_data
    @cards = @initiative.cards.open.preload(:board, :column, :assignees, :creator)
    @closed_cards_count = @initiative.cards.closed.count

    respond_to do |format|
      format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
      format.turbo_stream
      format.json { render json: { success: true, progress: @initiative.progress_percentage } }
    end
  end

  def destroy
    InitiativeActivity.track(@initiative, action: "timeline_cleared", description: "Removed from timeline")
    # We clear the initiative dates and color rather than deleting the tag and all its card associations
    @initiative.update!(start_date: nil, end_date: nil, color: nil)
    @initiatives = initiatives_scope
    set_tags_data
    @active_initiative = @initiatives.first
    if @active_initiative
      @cards = @active_initiative.cards.open.preload(:board, :column, :assignees, :creator)
      @closed_cards_count = @active_initiative.cards.closed.count
    else
      @cards = []
      @closed_cards_count = 0
    end

    respond_to do |format|
      format.html { redirect_to initiatives_path }
      format.turbo_stream
    end
  end

  private
    def ensure_initiatives_enabled
      unless Current.account.initiatives_enabled?
        respond_to do |format|
          format.html { redirect_to root_path, alert: "Cross-Board Initiatives are disabled for this account." }
          format.any { head :not_found }
        end
      end
    end

    def set_initiative
      @initiative = Current.account.tags.find(params[:id])
    end

    def initiatives_scope
      Current.account.tags.initiatives.chronologically.preload(:activities, :checkpoints)
    end

    def set_tags_data
      @tags = Current.account.tags.alphabetically.preload(:cards, :taggings, :checkpoints)
      @unassigned_tags = @tags.reject(&:initiative?)
      @new_tag_ids = Tag.new_tag_ids
      @recent_tag_ids = Tag.recent_tag_ids
    end

    def initiative_params
      params.expect(tag: [ :title, :start_date, :end_date, :color ])
    end
end
