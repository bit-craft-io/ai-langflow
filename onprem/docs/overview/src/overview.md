TODO 要修正
## 概要
- Client から Bridge を介して Dify に通信
- LM Studio（ローカルLLM）の応答スコアが閾値未満の場合、Cloud LLM に通信

## 使用技術
- Docker
- Ollama（ローカルLLM推論）
- Dify（ワークフロー制御、スコア判定）
- FireCrawl（RAG作成）
- Searxng（Web検索）
- VoiceVox（音声合成）
- Python 3.x

<div style="page-break-before: always;"></div>

## シーケンス図

<div style="border: 2px solid #333; padding: 10px; width: 100%; box-sizing: border-box; text-align: center;">

```plantuml
hide footbox

skinparam sequenceArrowThickness 1.5
skinparam roundcorner 6
skinparam sequenceParticipantBorderThickness 1
skinparam defaultFontSize 14

skinparam BoxPadding 20
skinparam sequenceMessageAlign center
skinparam SequenceMessageMargin 8

skinparam sequenceLifeLineBorderThickness 1
skinparam sequenceLifeLineBorderColor #black
skinparam ActivityBottomMargin 0

header " "
footer " "

participant "    Client    " as Client
participant "    Bridge    " as Bridge
participant "     Dify     " as Dify
participant "   VoiceVox   " as VoiceVox
participant "   Local LLM  " as Ollama

box "\nDocker Network\n" #F5F5F5
    participant Bridge
    participant Dify
    participant VoiceVox
    participant Ollama
end box

participant "   Cloud LLM  " as LLM


Client <--> Bridge: WebSocket 接続確立
activate Client
activate Bridge
Client -> Bridge : リクエスト

Bridge -> Dify : 転送
activate Dify
group Workflow: 大まかな動作を記述
    Dify -> Dify : Global 変数を操作

    group dify plugin: firecrawl
        note right of Dify
            RAG
        end note
    end

    Dify -> Ollama : リクエスト（推論）
    activate Ollama
    Ollama --> Dify : 結果
    deactivate Ollama

    alt LLM応答信頼度スコア（閾値70）
        Dify --> Bridge: 結果
    else
        group dify plugin: searxng
            note right of Dify
                Web検索
            end note
        end
        Dify -> LLM : リクエスト（推論）
        activate LLM
        LLM --> Dify : 結果
        deactivate LLM
    end
end

Dify --> Bridge : 結果
deactivate Dify

Bridge -> VoiceVox : リクエスト（文字データを音声データに変換）
activate VoiceVox
VoiceVox --> Bridge : 結果
deactivate VoiceVox

Bridge --> Client : 結果（テキスト / 音声データ）
deactivate Bridge
deactivate Client

loop 数秒毎に問い合わせ（間隔は環境変数で管理）

    Client -> Bridge : リクエスト
    activate Client
    activate Bridge

    Bridge -> Dify : 転送
    activate Dify
    Dify -> Dify : Global 変数を操作
    Dify --> Bridge : 結果
    deactivate Dify

    Bridge --> Client : 結果（Json）
    deactivate Bridge
    deactivate Client

    Client -[hidden]-> VoiceVox : dummy_space
end
```
</div>
