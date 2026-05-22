class DataImport::ContactManager
  def initialize(account)
    @account = account
    @existing_labels = @account.labels.pluck(:title).to_set
  end

  def build_contact(params)
    contact = find_or_initialize_contact(params)
    update_contact_attributes(params, contact)
    contact
  end

  def find_or_initialize_contact(params)
    contact = find_existing_contact(params)
    contact_params = params.slice(:email, :identifier, :phone_number)
    contact_params[:phone_number] = format_phone_number(contact_params[:phone_number]) if contact_params[:phone_number].present?
    contact ||= @account.contacts.new(contact_params)
    contact
  end

  def find_existing_contact(params)
    contact = find_contact_by_identifier(params)
    contact ||= find_contact_by_email(params)
    contact ||= find_contact_by_phone_number(params)

    update_contact_with_merged_attributes(params, contact) if contact.present? && contact.valid?
    contact
  end

  def find_contact_by_identifier(params)
    return unless params[:identifier]

    @account.contacts.find_by(identifier: params[:identifier])
  end

  def find_contact_by_email(params)
    return unless params[:email]

    @account.contacts.from_email(params[:email])
  end

  def find_contact_by_phone_number(params)
    return unless params[:phone_number]

    @account.contacts.find_by(phone_number: format_phone_number(params[:phone_number]))
  end

  def format_phone_number(phone_number)
    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def update_contact_with_merged_attributes(params, contact)
    contact.identifier = params[:identifier] if params[:identifier].present?
    contact.email = params[:email] if params[:email].present?
    contact.phone_number = format_phone_number(params[:phone_number]) if params[:phone_number].present?
    update_contact_attributes(params, contact)
    contact.save
  end

  private

  def update_contact_attributes(params, contact)
    contact.name = params[:name] if params[:name].present?
    contact.additional_attributes ||= {}
    contact.additional_attributes[:company_name] = params[:company_name] if params[:company_name].present?
    contact.additional_attributes[:city] = params[:city] if params[:city].present?
    assign_labels(params, contact)
    contact.assign_attributes(custom_attributes: contact.custom_attributes.merge(params.except(:identifier, :email, :name, :phone_number, :labels, :tags)))
  end

  def assign_labels(params, contact)
    raw_labels = params[:labels] || params[:tags]
    return if raw_labels.blank?

    label_names = raw_labels.to_s.split(',')
                            .map(&:strip)
                            .map { |name| name.gsub(/\s+/, '_') }
                            .map(&:downcase)
                            .map { |name| name.gsub(/[^\p{L}\p{N}_-]/, '') }
                            .compact_blank

    new_labels = label_names.reject { |name| @existing_labels.include?(name) }
    new_labels.each do |label_name|
      begin
        @account.labels.create!(title: label_name)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        # Ignorar falhas silenciosas ao criar tags duplicadas concorrentemente
      end
      @existing_labels << label_name
    end

    contact.label_list = label_names
  end
end
