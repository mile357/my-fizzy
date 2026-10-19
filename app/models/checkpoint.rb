class Checkpoint < ApplicationRecord
  belongs_to :account, default: -> { tag.account }
  belongs_to :tag, touch: true

  scope :completed, -> { where(completed: true) }
  scope :uncompleted, -> { where(completed: false) }
  scope :chronologically, -> { order(:created_at) }

  validates :content, presence: true

  def completed?
    completed
  end

  def toggle
    update(completed: !completed, completed_at: (completed ? nil : Time.current))
  end

  def toggle!
    update!(completed: !completed, completed_at: (completed ? nil : Time.current))
  end
end
