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
    filtered = by_search(filtered)
    filtered = by_label(filtered)
    filtered = by_custom_field(filtered)
    filtered = by_value_range(filtered)
    filtered
  end

  private

  EXACT_FILTERS = %i[pipeline_id stage_id status assignee_id contact_id inbox_id].freeze

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
