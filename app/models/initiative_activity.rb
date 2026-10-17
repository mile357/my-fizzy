class InitiativeActivity < ApplicationRecord
  belongs_to :account, default: -> { tag.account }
  belongs_to :tag, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  scope :chronologically, -> { order(created_at: :asc) }
  scope :reverse_chronologically, -> { order(created_at: :desc) }

  validates :action, :description, presence: true

  def self.track(tag, action:, description:, particulars: {}, creator: Current.user)
    return unless tag.persisted? && creator.present?

    create!(
      account: tag.account,
      tag: tag,
      creator: creator,
      action: action,
      description: description,
      particulars: particulars
    )
  end
end
