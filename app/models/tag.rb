class Tag < ApplicationRecord
  include Filterable

  belongs_to :account, default: -> { Current.account }
  has_many :taggings, dependent: :destroy
  has_many :cards, through: :taggings
  has_many :checkpoints, -> { order(:created_at) }, dependent: :destroy
  has_many :activities, -> { order(created_at: :desc) }, class_name: "InitiativeActivity", dependent: :destroy

  validates :title, presence: true, format: { without: /\A#/ }
  validates :color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/ }, allow_blank: true
  validate :end_date_cannot_precede_start_date
  normalizes :title, with: -> { it.downcase }

  class << self
    def new_tag_ids(account = Current.account)
      return Set.new unless account

      account.tags.where("tags.created_at >= ?", 1.day.ago).pluck(:id).to_set
    end

    def recent_tag_ids(account = Current.account)
      return Set.new unless account

      month_ago = 1.month.ago
      ids = account.tags.where("tags.created_at >= ? OR tags.updated_at >= ?", month_ago, month_ago).pluck(:id)
      ids += Tagging.where(account: account).where("created_at >= ?", month_ago).pluck(:tag_id)
      ids.to_set
    end
  end

  scope :alphabetically, -> { order("lower(title)") }
  scope :unused, -> { left_outer_joins(:taggings).where(taggings: { id: nil }, start_date: nil, end_date: nil) }
  scope :initiatives, -> { where.not(start_date: nil).or(where.not(end_date: nil)) }
  scope :chronologically, -> { order(Arel.sql("COALESCE(start_date, end_date, created_at)")) }

  def hashtag
    "#" + title
  end

  def cards_count
    if cards.loaded?
      cards.count(&:open?)
    else
      cards.open.count
    end
  end

  def initiative?
    start_date.present? || end_date.present?
  end

  def completed?
    if checkpoints.loaded?
      checkpoints.any? && checkpoints.all?(&:completed?)
    elsif cards.loaded?
      cards.any? && cards.none?(&:open?)
    elsif checkpoints.exists?
      !checkpoints.uncompleted.exists?
    elsif cards.exists?
      !cards.open.exists?
    else
      false
    end
  end

  def overdue?
    initiative? && end_date.present? && end_date < Date.current && !completed?
  end

  def progress_percentage
    if checkpoints.loaded?
      if checkpoints.any?
        ((checkpoints.count(&:completed?).to_f / checkpoints.size) * 100).round
      elsif cards.loaded?
        cards.any? ? ((cards.count(&:closed?).to_f / cards.size) * 100).round : 0
      else
        cards.any? ? ((cards.closed.count.to_f / cards.count) * 100).round : 0
      end
    elsif checkpoints.exists?
      total = checkpoints.count
      total > 0 ? ((checkpoints.completed.count.to_f / total) * 100).round : 0
    elsif cards.exists?
      total = cards.count
      total > 0 ? ((cards.closed.count.to_f / total) * 100).round : 0
    else
      0
    end
  end

  def display_color
    color.presence || "#3b82f6"
  end

  def contrast_text_color
    hex = display_color.to_s.delete_prefix("#")
    hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3

    if hex.length == 6
      r, g, b = hex.scan(/../).map { |c| c.to_i(16) }
      luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
      luminance > 0.62 ? "#0f172a" : "#ffffff"
    else
      "#ffffff"
    end
  end

  def previous_due_dates
    return [] unless end_date.present?

    dates = []
    activities.each do |act|
      if act.particulars.is_a?(Hash)
        [ act.particulars["old_end_date"], act.particulars["end_date"] ].compact.each do |d_val|
          begin
            dates << Date.parse(d_val.to_s)
          rescue ArgumentError, TypeError, Date::Error
            nil
          end
        end
      end

      if dates.empty? && act.description.present?
        if act.description =~ /–\s+([A-Za-z]{3}\s+\d{1,2},\s+\d{4})/
          begin
            dates << Date.parse(::Regexp.last_match(1))
          rescue ArgumentError, TypeError, Date::Error
            nil
          end
        elsif act.description =~ /Changed target date to\s+([A-Za-z]{3}\s+\d{1,2},\s+\d{4})/
          begin
            dates << Date.parse(::Regexp.last_match(1))
          rescue ArgumentError, TypeError, Date::Error
            nil
          end
        end
      end
    end

    dates.select { |d| d < end_date }.uniq.sort
  end

  private
    def end_date_cannot_precede_start_date
      if start_date.present? && end_date.present? && end_date < start_date
        errors.add(:end_date, "cannot precede start date")
      end
    end
end
