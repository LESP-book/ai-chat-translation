# frozen_string_literal: true

AiChatTranslation::Engine.routes.draw do
  post "/channels/:channel_id/messages/:message_id/translate" => "translation#translate",
       defaults: {
         format: :json,
       }
end

Discourse::Application.routes.draw { mount AiChatTranslation::Engine, at: "ai-chat-translation" }
