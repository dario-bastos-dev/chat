# Participantes passam a ser so quem alguem adiciona (ou menciona). Caixas ja existentes
# mantem o valor que tinham; so as novas nascem sem tornar o responsavel participante.
class ChangeAutoAddAssigneeAsParticipantDefault < ActiveRecord::Migration[7.1]
  def change
    change_column_default :inboxes, :auto_add_assignee_as_participant, from: true, to: false
  end
end
