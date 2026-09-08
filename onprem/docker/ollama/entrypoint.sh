#!/bin/sh

/bin/ollama serve &
SERVE_PID=$!

sleep 2
while ! ollama list > /dev/null 2>&1; do sleep 1; done

echo "Models recognized!"
ollama list

IFS=','
for model in $EP_OLLAMA_MODEL; do
  model=$(echo "$model" | xargs)
  echo "Ensuring model available: ${model}"
  ollama pull "${model}"
done
unset IFS

# warmup=chat系モデルのみ実行したい場合、別変数で指定
if [ -n "$EP_WARMUP_MODEL" ]; then
  echo "Warming up model: ${EP_WARMUP_MODEL}"
  ( echo hi | ollama run "${EP_WARMUP_MODEL}" > /tmp/warmup.log 2>&1 )
  echo "Warmup completed (exit: $?)"
  cat /tmp/warmup.log
fi

wait $SERVE_PID