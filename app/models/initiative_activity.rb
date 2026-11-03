class InitiativeActivity < ApplicationRecord
  belongs_to :account, default: -> { tag.account }
  belongs_to :tag, touch: true
  belongs_to :creator, class_name: "User", optional: true, default: -> { Current.user }

  attribute :particulars, :json, default: -> { {} }

  scope :chronologically, -> { order(created_at: :asc) }
  scope :reverse_chronologically, -> { order(created_at: :desc) }

  validates :action, :description, presence: true, length: { maximum: 255 }

  class << self
    def track(tag, action:, description:, particulars: {}, creator: Current.user)
      return unless tag.persisted? && creator.present?

      create!(
        account: tag.account,
        tag: tag,
        creator: creator,
        action: action.to_s.truncate(255),
        description: description.to_s.truncate(250),
        particulars: particulars
      )
    end
  end
end
