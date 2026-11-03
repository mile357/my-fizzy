class InitiativesController < ApplicationController
  before_action :ensure_initiatives_enabled
  before_action :ensure_admin, only: %i[ create update destroy ]
  before_action :set_initiative, only: %i[ show update destroy ]

  def index
    active = params[:initiative_id].present? ? Current.account.tags.find_by(id: params[:initiative_id]) : nil
    prepare_index_state(active)
  end

  def show
    respond_to do |format|
      format.html do
        if turbo_frame_request?
          set_initiative_cards
        else
          prepare_index_state(@initiative)
          render :index
        end
      end
      format.turbo_stream do
        prepare_index_state(@initiative)
      end
    end
  end

  def create
    clean_title = initiative_params[:title].to_s.strip.delete_prefix("#")
    if clean_title.blank?
      redirect_to initiatives_path
    else
      @initiative = Current.account.tags.find_or_initialize_by(title: clean_title)
      was_new_record = @initiative.new_record?
      old_start = @initiative.start_date
      old_end = @initiative.end_date
      @initiative.assign_attributes(initiative_params.except(:title)) if initiative_params.except(:title).present?

      saved = Tag.transaction do
        if @initiative.save
          if was_new_record
            desc = @initiative.initiative? ? "Created initiative #{@initiative.hashtag}" : "Created tag #{@initiative.hashtag}"
            action = @initiative.initiative? ? "initiative_created" : "tag_created"
            InitiativeActivity.track(
              @initiative,
              action: action,
              description: desc,
              particulars: { end_date: @initiative.end_date&.iso8601 }
            )
          elsif @initiative.start_date != old_start || @initiative.end_date != old_end
            track_dates_changed(@initiative, old_start, old_end)
          end
          true
        else
          false
        end
      end

      prepare_index_state(@initiative)

      if saved
        respond_to do |format|
          format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { redirect_to initiatives_path, alert: @initiative.errors.full_messages.to_sentence }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace("initiative_inspector", partial: "initiatives/inspector", locals: { initiative: @initiative, cards: @cards }), status: :unprocessable_entity
          end
        end
      end
    end
  end

  def update
    old_start = @initiative.start_date
    old_end = @initiative.end_date

    saved = Tag.transaction do
      if @initiative.update(initiative_params)
        if @initiative.start_date != old_start || @initiative.end_date != old_end
          track_dates_changed(@initiative, old_start, old_end)
        end
        true
      else
        false
      end
    end

    prepare_index_state(@initiative)

    if saved
      respond_to do |format|
        format.html { redirect_to initiatives_path(initiative_id: @initiative.id) }
        format.turbo_stream
        format.json { render json: { success: true, progress: @initiative.progress_percentage } }
      end
    else
      respond_to do |format|
        format.html { redirect_to initiatives_path(initiative_id: @initiative.id), alert: @initiative.errors.full_messages.to_sentence }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("initiative_inspector", partial: "initiatives/inspector", locals: { initiative: @initiative, cards: @cards }), status: :unprocessable_entity
        end
        format.json { render json: { errors: @initiative.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Tag.transaction do
      InitiativeActivity.track(@initiative, action: "timeline_cleared", description: "Removed from timeline")
      @initiative.update!(start_date: nil, end_date: nil, color: nil)
    end
    prepare_index_state(nil)

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

    def prepare_index_state(active_initiative)
      @initiatives = initiatives_scope
      set_tags_data
      @active_initiative = active_initiative || @initiatives.first
      set_initiative_cards
    end

    def initiatives_scope
      Current.account.tags.initiatives.chronologically.preload(:checkpoints, activities: { creator: :account })
    end

    def set_tags_data
      @tags = Current.account.tags.alphabetically.preload(:checkpoints)
      @unassigned_tags = @tags.reject(&:initiative?)
      @cards_count_by_tag_id = Tagging.where(account: Current.account).joins(:card).merge(Current.user.accessible_cards.open).group(:tag_id).count
      @new_tag_ids = Tag.new_tag_ids
      @recent_tag_ids = Tag.recent_tag_ids
    end

    def set_initiative_cards
      initiative = @initiative || @active_initiative
      if initiative
        @cards = Current.user.accessible_cards.open.merge(initiative.cards).with_users.preload(:board, :column)
        @closed_cards_count = Current.user.accessible_cards.closed.merge(initiative.cards).count
      else
        @cards = []
        @closed_cards_count = 0
      end
    end

    def track_dates_changed(initiative, old_start, old_end)
      desc = if initiative.start_date && initiative.end_date
        "Changed dates to #{initiative.start_date.strftime('%b %d, %Y')} – #{initiative.end_date.strftime('%b %d, %Y')}"
      elsif initiative.end_date
        "Changed target date to #{initiative.end_date.strftime('%b %d, %Y')}"
      elsif initiative.start_date
        "Changed start date to #{initiative.start_date.strftime('%b %d, %Y')}"
      else
        "Cleared schedule dates"
      end

      InitiativeActivity.track(
        initiative,
        action: "dates_changed",
        description: desc,
        particulars: {
          old_start_date: old_start&.iso8601,
          old_end_date: old_end&.iso8601,
          start_date: initiative.start_date&.iso8601,
          end_date: initiative.end_date&.iso8601
        }
      )
    end

    def initiative_params
      params.expect(tag: [ :title, :start_date, :end_date, :color ])
    end
end
