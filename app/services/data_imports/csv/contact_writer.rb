class DataImports::Csv::ContactWriter
  STANDARD_FIELDS = %w[name email identifier phone_number].freeze
  SOCIAL_PROFILE_FIELDS = %w[facebook github instagram telegram tiktok linkedin twitter].freeze
  LABEL_FIELDS = %w[labels tags].freeze
  DIAGNOSTIC_FIELDS = %w[errors].freeze

  def initialize(account, fields)
    @account = account
    @fields = fields.except(*DIAGNOSTIC_FIELDS)
    @fields['email'] = @fields['email'].strip.downcase if @fields['email'].present?
    phone = @fields['phone_number']&.strip&.delete_prefix("'")
    @fields['phone_number'] = phone.start_with?('+') ? phone : "+#{phone}" if phone.present?
  end

  def perform
    labels = validated_labels
    contact = matched_contact || @account.contacts.new
    outcome = contact.new_record? ? 'created' : 'updated'
    assign_fields(contact)
    raise ActiveRecord::RecordInvalid, contact unless contact.valid?

    Contacts::SyncAttributes.new(contact).perform
    contact = persist(contact)
    apply_labels(contact, labels)
    [contact, outcome]
  end

  private

  def matched_contact
    contacts = %w[identifier email phone_number].filter_map do |field|
      next if @fields[field].blank?

      @account.contacts.lock.find_by(field => @fields[field])
    end.uniq(&:id)
    raise CustomExceptions::DataImport::InvalidCsvError, 'The identifiers match different contacts.' if contacts.size > 1

    contacts.first
  end

  def assign_fields(contact)
    contact.assign_attributes(@fields.slice(*STANDARD_FIELDS).compact_blank)
    contact.additional_attributes = contact.additional_attributes.to_h.merge(@fields.slice('company_name', 'city').compact_blank)
    assign_social_profiles(contact)
    custom_fields = @fields.except(*STANDARD_FIELDS, *LABEL_FIELDS, *SOCIAL_PROFILE_FIELDS)
    contact.custom_attributes = contact.custom_attributes.to_h.merge(custom_fields.compact_blank)
    contact.updated_at = Time.current
    contact.created_at ||= Time.current
  end

  def persist(contact)
    # Validation and normalization happen above; suppress normal contact callbacks during imports.
    # rubocop:disable Rails/SkipsModelValidations
    if contact.new_record?
      result = Contact.insert_all!([contact.attributes.slice(*Contact.column_names).except('id')], returning: %w[id])
      @account.contacts.find(result.rows.first.first)
    else
      contact.update_columns(contact.changes.slice(*Contact.column_names).transform_values(&:last))
      contact
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Merged over the networks the contact already has, so a sheet with only some columns keeps the rest.
  def assign_social_profiles(contact)
    social_profiles = @fields.slice(*SOCIAL_PROFILE_FIELDS).compact_blank
    return if social_profiles.blank?

    existing = contact.additional_attributes['social_profiles'] || {}
    contact.additional_attributes['social_profiles'] = existing.merge(social_profiles)
  end

  # Labels named in the sheet (`labels` or `tags`) are normalized to label titles and created when the
  # account does not have them yet, instead of rejecting the row.
  def validated_labels
    labels = (@fields['labels'].presence || @fields['tags']).to_s.split(',')
                                                           .map { |label| normalize_label(label) }
                                                           .compact_blank.uniq
    missing = labels - @account.labels.where(title: labels).pluck(:title)
    missing.each { |title| create_label(title) }

    labels
  end

  def normalize_label(label)
    label.strip.gsub(/\s+/, '_').downcase.gsub(/[^\p{L}\p{N}_-]/, '')
  end

  def create_label(title)
    @account.labels.create!(title: title)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    # Another row of the same import created it first.
    nil
  end

  def apply_labels(contact, labels)
    return if labels.empty?

    tags = ActsAsTaggableOn::Tag.find_or_create_all_with_like_by_name(labels)
    tag_ids = tags.map(&:id) - contact.taggings.where(context: 'labels').pluck(:tag_id)
    taggings = tag_ids.map do |tag_id|
      { tag_id: tag_id, taggable_type: 'Contact', taggable_id: contact.id, context: 'labels', created_at: Time.current }
    end
    ActsAsTaggableOn::Tagging.insert_all(taggings) # rubocop:disable Rails/SkipsModelValidations
  end
end
