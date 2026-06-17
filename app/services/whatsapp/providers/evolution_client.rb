require 'faraday/net_http_persistent'

class Whatsapp::Providers::EvolutionClient
  def self.connection(api_base_url)
    @connections ||= {}
    @connections[api_base_url] ||= Faraday.new(url: api_base_url) do |builder|
      builder.adapter :net_http_persistent do |http|
        http.idle_timeout = 100
        http.read_timeout = 30
      end
    end
  end
end
