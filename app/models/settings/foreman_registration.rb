class Setting::ForemanRegistration < ::Setting
  def self.load_defaults
    return unless ActiveRecord::Base.connection.table_exists?('settings')
    return unless super

    Setting.transaction do
      [self.set('foreman_registration_allowed_hosts',
                N_('IPs that are allowed to access this restricted API'),
                ['127.0.0.1'],),
      ].compact.each { |s| self.create! s.update(:category => "Setting::ForemanRegistration") }
    end

    true
  end
end
