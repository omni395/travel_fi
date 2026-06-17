ActiveJob::Base.queue_adapter = :inline

PASSWORD = '12345678'

# During seed, enable delivery errors to diagnose SMTP issues
original_raise_errors = ActionMailer::Base.raise_delivery_errors
ActionMailer::Base.raise_delivery_errors = true

begin
  # Отключаем PaperTrail во время сидирования — версии и бродкасты не нужны
  PaperTrail.request.enabled = false

  # ========== CREATE ROLES ==========
  # Создаем роли для Rolify
  Role.find_or_create_by!(name: 'admin')
  Role.find_or_create_by!(name: 'moderator')
  Role.find_or_create_by!(name: 'user')

  puts "✅ Roles created: admin, moderator, user"

  # Attach default avatar if missing (utility method used in seed creation blocks)
  def attach_default_avatar(user)
    return unless user.respond_to?(:avatar)
    return if user.avatar.attached?
    path = Rails.root.join('app', 'assets', 'images', 'no-image.png')
    if File.exist?(path)
      # Очищаем старый перед attach (на случай если было что-то до этого)
      user.avatar.purge if user.avatar.attached?

      # Tempfile с ensure для гарантированного управления ресурсами
      file = File.open(path, 'rb')
      begin
        user.avatar.attach(io: file, filename: 'no-image.png', content_type: 'image/png')
      ensure
        file.close if file
      end
    end
  end

  # ========== ADMIN ==========
  admin = User.find_or_create_by!(email: 'admin@example.com') do |user|
    user.name = 'Admin'
    user.status = 'active'
    user.password = PASSWORD
    user.password_confirmation = PASSWORD
    user.confirmed_at = Time.current
  end

  # Назначаем роль admin через Rolify (после after_create :assign_default_role)
  admin.add_role(:admin) unless admin.has_role?(:admin)
  admin.remove_role(:user) if admin.has_role?(:user)
  attach_default_avatar(admin)
  UserService.create_default_settings(admin)

  puts "✅ Admin created: admin@example.com (active)"

  # ========== SEED BOT (для seed:pois rake task) ==========
  seed_bot = User.find_or_create_by!(email: 'seed-bot@example.com') do |user|
    user.name = 'Seed Bot'
    user.status = 'active'
    user.password = SecureRandom.hex(16)
    user.password_confirmation = user.password
    user.confirmed_at = Time.current
  end
  seed_bot.add_role(:user) unless seed_bot.has_role?(:user)
  Setting.create_for_user(seed_bot)

  puts "✅ Seed Bot created: seed-bot@example.com"

  # ========== GROUP 1: 5 users - CONFIRMED & ACTIVE ==========
  (1..5).each do |i|
    user = User.find_or_create_by!(email: "user-confirmed-#{i}@example.com") do |user|
      user.name = "Confirmed User #{i}"
      user.status = 'active'
      user.password = PASSWORD
      user.password_confirmation = PASSWORD
      user.confirmed_at = Time.current
    end

    # Роль :user назначается автоматически через after_create :assign_default_role
    # Для уже существующих пользователей роль уже есть
    attach_default_avatar(user)
    UserService.create_default_settings(user)
  end

  puts "✅ Created 5 ACTIVE users: user-confirmed-[0..4]@example.com"

  # ========== GROUP 2: 5 users - REGISTERED (pending verification, emails sent NOW) ==========
  (1..5).each do |i|
    # Ensure raw token is available outside of the block's scope
    raw_token, enc_token = Devise.token_generator.generate(User, :confirmation_token)
    user = User.find_or_create_by!(email: "user-pending-#{i}@example.com") do |u|
      u.name = "Pending User #{i}"
      u.status = 'pending_verification'
      u.password = PASSWORD
      u.password_confirmation = PASSWORD
      u.confirmation_token = enc_token
      u.confirmation_sent_at = Time.current
    end

    # Роль :user назначается автоматически через after_create :assign_default_role
    attach_default_avatar(user)
    UserService.create_default_settings(user)

    # If we created the record (or it already exists) and we generated a raw_token, deliver the mail with raw token
    if user.persisted? && user.confirmed_at.blank? && raw_token.present?
      UserMailer.confirmation_instructions(user, raw_token).deliver_now
    elsif user.persisted? && user.confirmed_at.blank?
      # fallback to using whatever value user.confirmation_token returns if raw isn't available
      UserMailer.confirmation_instructions(user, user.confirmation_token).deliver_now
    end
  rescue => e
    Rails.logger.error "[SEEDS] Email delivery failed for #{user&.email || 'unknown'}: #{e.class}: #{e.message}"
    puts "   ⚠️  Email failed for #{user&.email || 'unknown'}: #{e.message}"
  end

  puts "✅ Created 5 PENDING_VERIFICATION users: user-pending-[0..4]@example.com"
  puts "   📧 Confirmation emails queued"

  # ========== GROUP 3: 5 users - Verification expires TOMORROW ==========
  (1..5).each do |i|
    # Generate raw+enc token outside of the creation block so we can use raw in email
    raw_token, enc_token = Devise.token_generator.generate(User, :confirmation_token)
    user = User.find_or_create_by!(email: "user-expires-#{i}@example.com") do |u|
      u.name = "Expires User #{i}"
      u.status = 'pending_verification'
      u.password = PASSWORD
      u.password_confirmation = PASSWORD
      # Set confirmation_sent_at to 6 days ago (expires in 1 day with 7-day window)
      u.confirmation_sent_at = 6.days.ago
      u.confirmation_token = enc_token
    end

    # Роль :user назначается автоматически через after_create :assign_default_role
    attach_default_avatar(user)
    UserService.create_default_settings(user)
    if user.persisted? && user.confirmed_at.blank? && raw_token.present?
      UserMailer.confirmation_instructions(user, raw_token).deliver_now
    elsif user.persisted? && user.confirmed_at.blank?
      UserMailer.confirmation_instructions(user, user.confirmation_token).deliver_now
    end
  rescue => e
    Rails.logger.error "[SEEDS] Email delivery failed for #{user&.email || 'unknown'}: #{e.class}: #{e.message}"
    puts "   ⚠️  Email failed for #{user&.email || 'unknown'}: #{e.message}"
  end

  puts "✅ Created 5 users expiring TOMORROW: user-expires-[0..4]@example.com"
  puts "   📧 Confirmation emails queued (but tokens expire in 1 day)"

  # ========== GROUP 4: 5 users - ACTIVE 6 months ago (inactivity check tomorrow) ==========
  (1..5).each do |i|
    user = User.find_or_create_by!(email: "user-inactive-#{i}@example.com") do |u|
      u.name = "Inactive User #{i}"
      u.status = 'active'
      u.password = PASSWORD
      u.password_confirmation = PASSWORD
      u.confirmed_at = 6.months.ago
    end
    # Update updated_at after user is created (cannot update_column on new record)
    user.update_column(:created_at, 6.months.ago) if user.persisted?
    user.update_column(:updated_at, 6.months.ago) if user.persisted?

    # Роль :user назначается автоматически через after_create :assign_default_role
    attach_default_avatar(user)
    UserService.create_default_settings(user)
  end

  puts "✅ Created 5 INACTIVE users: user-inactive-[0..4]@example.com"
  puts "   ⏰ Last activity: 6 months ago (will change to INACTIVE tomorrow)"

  # ========== POI CATEGORIES ==========
  require_relative "seeds/poi_categories"

  puts "\n🎉 Seeding completed!"
  puts "\n📊 User Summary:"
  puts "  - 1 Admin:          admin@example.com"
  puts "  - 5 Active:         user-confirmed-[0..4]@example.com"
  puts "  - 5 Pending:        user-pending-[0..4]@example.com"
  puts "  - 5 Expires tomorrow: user-expires-[0..4]@example.com"
  puts "  - 5 Inactive (6mo):  user-inactive-[0..4]@example.com"
  puts "\n🔐 Password: #{PASSWORD}"
  puts "📧 Check Mailhog: http://localhost:8025"

ensure
  # Restore original setting
  ActionMailer::Base.raise_delivery_errors = original_raise_errors
end
