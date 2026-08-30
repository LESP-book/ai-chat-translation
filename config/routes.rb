# frozen_string_literal: true

AiChatTranslation::Engine.routes.draw do
  post "/channels/:channel_id/messages/:message_id/translate" => "translation#translate",
       defaults: {
         format: :json,
       }
end

Discourse::Application.routes.draw do
  mount AiChatTranslation::Engine, at: "ai-chat-translation"

  scope "/admin/plugins/ai-chat-translation", constraints: AdminConstraint.new do
    get "/dashboard" => "admin/plugins#index"
    get "/dashboard/progress" => "ai_chat_translation/admin/dashboard#progress", :format => :json
    get "/translation-scopes" => "ai_chat_translation/admin/translation_scopes#show", :format => :json
  end
end
