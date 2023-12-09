# frozen_string_literal: true

class AllowedEmailDomain < ApplicationRecord
  RESERVED_DOMAINS = [
    'gmail.com',
    'yahoo.com',
    'hotmail.com',
    'aol.com',
    'msn.com',
    'hotmail.co.uk',
    'hotmail.fr',
    'live.com',
    'outlook.com',
    'icloud.com'
  ].freeze

  validates :group_id, presence: true
  validates :domain, presence: true
  validate :allow_root_group_only
  validates :domain, exclusion: { in: RESERVED_DOMAINS,
    message: _('The domain you entered is not allowed.') }
  validates :domain, format: { with: /\w*\./,
    message: _('The domain you entered is misformatted.') }

  belongs_to :group, class_name: 'Group', foreign_key: :group_id

  def allow_root_group_only
    if group&.parent_id
      errors.add(:base, _('Allowed email domain restriction only permitted for top-level groups'))
    end
  end

  def email_matches_domain?(email)
    email.end_with?(email_domain)
  end

  def email_domain
    @email_domain ||= "@#{domain}"
  end
end
