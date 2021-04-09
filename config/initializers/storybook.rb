module PermissiveCORSHeaders
  def self.before(response)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET"
  end
end

ViewComponent::Storybook::StoriesController.before_filter(PermissiveCORSHeaders) if Rails.env.development?
