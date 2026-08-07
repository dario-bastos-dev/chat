# frozen_string_literal: true

# Corrige as chaves estrangeiras do CRM que foram criadas sem ON DELETE.
#
# 1. `deals.assignee_id`, `deals.inbox_id` e `deal_activities.user_id` -> SET NULL.
#    Nem User nem Inbox declaram associacao com negocios, entao a constraint do
#    banco era a unica coisa no caminho e ela bloqueava: excluir um agente com
#    negocios atribuidos, ou uma caixa de entrada referenciada por um negocio,
#    falhava com PG::ForeignKeyViolation. O negocio deve sobreviver ao agente e
#    ficar sem responsavel.
#
# 2. `deal_activities.deal_id` e `conversation_deals.deal_id` -> CASCADE.
#    A migration 20260213150000 colocou CASCADE em `deals.contact_id` para que
#    excluir um contato levasse os negocios junto, mas as tabelas filhas do
#    negocio continuaram em NO ACTION. Na pratica a cascata nunca completava:
#    o Postgres tentava apagar o negocio e era barrado pelas atividades. Como
#    atividades sao criadas automaticamente (nota de mudanca de etapa, nota de
#    auto-atribuicao), quase todo contato com negocio era indelevel.
class AddNullifyOnDeleteToDealReferences < ActiveRecord::Migration[7.1]
  def up
    change_fk :deals, :users, column: :assignee_id, on_delete: :nullify
    change_fk :deals, :inboxes, on_delete: :nullify
    change_fk :deal_activities, :users, on_delete: :nullify

    change_fk :deal_activities, :deals, on_delete: :cascade
    change_fk :conversation_deals, :deals, on_delete: :cascade
  end

  def down
    change_fk :deals, :users, column: :assignee_id, on_delete: nil
    change_fk :deals, :inboxes, on_delete: nil
    change_fk :deal_activities, :users, on_delete: nil

    change_fk :deal_activities, :deals, on_delete: nil
    change_fk :conversation_deals, :deals, on_delete: nil
  end

  private

  def change_fk(from_table, to_table, on_delete:, column: nil)
    if column
      remove_foreign_key from_table, column: column
    else
      remove_foreign_key from_table, to_table
    end

    add_foreign_key from_table, to_table, **{ column: column, on_delete: on_delete }.compact
  end
end
