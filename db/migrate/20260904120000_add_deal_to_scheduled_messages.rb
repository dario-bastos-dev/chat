# frozen_string_literal: true

# A mensagem programada continua pertencendo a conversa; o negocio e apenas a
# origem. Guardar essa origem e o que permite listar no negocio o que foi
# agendado a partir dele e impedir que a mesma programacao seja disparada duas
# vezes pela acao em massa do Kanban.
class AddDealToScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    add_reference :scheduled_messages, :deal, null: true, foreign_key: { on_delete: :nullify }
  end
end
