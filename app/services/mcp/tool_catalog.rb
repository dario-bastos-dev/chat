class Mcp::ToolCatalog
  TOOLS_FILE = Rails.root.join('config/mcp_tools.yml')

  def self.tools
    @tools ||= YAML.safe_load_file(TOOLS_FILE, aliases: true).map { |attributes| Mcp::Tool.new(attributes) }.freeze
  end

  def self.find(name)
    tools.find { |tool| tool.name == name }
  end
end
