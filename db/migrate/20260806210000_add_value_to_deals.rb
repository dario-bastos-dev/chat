# frozen_string_literal: true

# Reintroduz o valor monetario do negocio, removido pela migration
# 20260529123000. Diferente da versao anterior, nao ha coluna `currency` por
# negocio: a moeda e uma so por conta (`account.settings['crm_currency']`).
# Somar moedas diferentes numa coluna do Kanban ou num relatorio produz numero
# sem sentido, e valor normalizado exigiria taxa de cambio.
#
# Os negocios existentes comecam zerados; nao ha valor historico a restaurar,
# ja que a coluna antiga foi removida em producao.
class AddValueToDeals < ActiveRecord::Migration[7.1]
  def change
    add_column :deals, :value, :decimal, precision: 15, scale: 2, default: 0.0, null: false

    # Suporta a soma por etapa e o forecast ponderado sem varrer a tabela.
    add_index :deals, [:account_id, :pipeline_id, :stage_id, :value],
              where: "status = 'open'",
              name: 'idx_deals_open_value'
  end
end
