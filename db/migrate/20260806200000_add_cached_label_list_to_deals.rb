# frozen_string_literal: true

# `label_list` do acts_as_taggable_on consulta a tabela de taggings a cada
# chamada, o que gerava uma query por negocio na listagem do Kanban. O gem le de
# uma coluna `cached_<contexto>_list` quando ela existe e a mantem sozinho nos
# saves. E o mesmo caminho que o Chatwoot ja usa em `conversations`.
#
# O default precisa ser string vazia, e nao NULL: o gem so consulta o cache
# quando ele e non-nil, entao com NULL todo negocio sem etiqueta continuaria
# disparando a sua propria query.
class AddCachedLabelListToDeals < ActiveRecord::Migration[7.1]
  def up
    add_column :deals, :cached_label_list, :text, default: ''

    # Backfill dos negocios que ja tem etiquetas.
    execute(<<~SQL.squish)
      UPDATE deals SET cached_label_list = sub.labels
      FROM (
        SELECT taggings.taggable_id AS deal_id, string_agg(tags.name, ', ') AS labels
        FROM taggings
        JOIN tags ON tags.id = taggings.tag_id
        WHERE taggings.taggable_type = 'Deal' AND taggings.context = 'labels'
        GROUP BY taggings.taggable_id
      ) AS sub
      WHERE deals.id = sub.deal_id
    SQL

    execute("UPDATE deals SET cached_label_list = '' WHERE cached_label_list IS NULL")
  end

  def down
    remove_column :deals, :cached_label_list
  end
end
