# frozen_string_literal: true

# Centraliza os filtros de negocios para que o board, a listagem e o
# "carregar mais" de cada coluna do Kanban compartilhem exatamente o mesmo
# criterio. Antes a busca e os filtros rodavam no frontend sobre a pagina ja
# carregada, o que fazia o Kanban ignorar tudo que estivesse alem dos 50
# primeiros registros.
class Deals::Finder
  def initialize(scope:, params: {})
    @scope = scope
    @params = params
  end

  def perform
    filtered = @scope
    filtered = by_exact_columns(filtered)
    filtered = by_assignee(filtered)
    filtered = by_created_at(filtered)
    filtered = by_search(filtered)
    filtered = by_label(filtered)
    filtered = by_custom_field(filtered)
    filtered = by_value_range(filtered)
    filtered
  end

  private

  EXACT_FILTERS = %i[pipeline_id stage_id status contact_id inbox_id].freeze
  # Valor de `assignee_id` para os negocios sem responsavel.
  UNASSIGNED = 'none'

  def by_exact_columns(scope)
    EXACT_FILTERS.each_with_object({}) do |key, filters|
      filters[key] = @params[key] if @params[key].present?
    end.then { |filters| filters.any? ? scope.where(filters) : scope }
  end

  # Busca pelo titulo do negocio ou pelo nome do contato.
  def by_search(scope)
    return scope if @params[:q].blank?

    term = "%#{@params[:q].to_s.strip}%"
    scope.left_joins(:contact)
         .where('deals.title ILIKE :term OR contacts.name ILIKE :term', term: term)
  end

  def by_label(scope)
    return scope if @params[:label].blank?

    scope.tagged_with(@params[:label], on: :labels)
  end

  def by_assignee(scope)
    return scope if @params[:assignee_id].blank?
    return scope.where(assignee_id: nil) if @params[:assignee_id].to_s == UNASSIGNED

    scope.where(assignee_id: @params[:assignee_id])
  end

  # O front manda os limites ja convertidos para o fuso de quem filtra (inicio e
  # fim do dia local), entao aqui e so comparar.
  def by_created_at(scope)
    from = parse_time(@params[:created_from])
    to = parse_time(@params[:created_to])
    scope = scope.where(deals: { created_at: from.. }) if from
    scope = scope.where(deals: { created_at: ..to }) if to
    scope
  end

  def parse_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def by_value_range(scope)
    scope = scope.where(deals: { value: @params[:min_value].to_f.. }) if @params[:min_value].present?
    scope = scope.where(deals: { value: ..@params[:max_value].to_f }) if @params[:max_value].present?
    scope
  end

  def by_custom_field(scope)
    key = @params[:custom_field_key]
    value = @params[:custom_field_value]
    return scope if key.blank? || value.blank?

    scope.where('deals.custom_attributes ->> ? ILIKE ?', key.to_s, "%#{value}%")
  end
end
