# frozen_string_literal: true

module JsonHelpers
  def json
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end
end
