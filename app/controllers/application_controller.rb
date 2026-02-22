class ApplicationController < ActionController::API
  rescue_from UnauthorizedError do
    render json: { error: 'unauthorized' }, status: :unauthorized
  end
end
