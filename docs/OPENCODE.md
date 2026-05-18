# OpenCode — instalación y uso (setup Manjaro + Ollama)

Guía para este equipo: **AMD Ryzen 5 4600G**, **RX 580 8GB**, **Ollama** con `qwen2.5:7b`, mismo stack que OpenClaw.

## Instalación rápida

```bash
# Desde este repo
./scripts/install-opencode.sh

# Recargar shell
source ~/.zshrc

# Comprobar
opencode --version    # ej. 1.15.4+
opencode models ollama
```

Instalación manual (última versión):

```bash
curl -fsSL https://opencode.ai/install | bash
# El binario queda en ~/.opencode/bin/opencode
```

Actualizar:

```bash
opencode upgrade
# o
opencode upgrade --method curl
```

## Configuración aplicada

Archivo: `~/.config/opencode/opencode.json` (copiado desde `config/opencode.json.example`).

| Opción | Valor | Motivo |
|--------|--------|--------|
| Modelo | `ollama/qwen2.5:7b` | Único modelo local, cabe en 8GB VRAM |
| `num_ctx` | `8192` | Equilibrio contexto/VRAM (no 64k: OOM o muy lento) |
| `num_predict` | `4096` | Respuestas largas sin cortar demasiado pronto |
| `timeout` / `chunkTimeout` | 600s / 120s | El 7b local tarda más que APIs cloud |
| `webfetch` / `websearch` | `deny` | Sin APIs extra; menos latencia y sorpresas |
| `bash` | `ask` | Pide confirmación antes de ejecutar comandos |

Variables en `~/.config/opencode/env.sh`:

- `OLLAMA_HOST=http://127.0.0.1:11434`
- `OPENCODE_DISABLE_MODELS_FETCH=true` — arranque más rápido si solo usas Ollama
- `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS=300000` — herramientas bash con margen en GPU local

## Uso básico

```bash
cd /ruta/a/tu/proyecto
opencode                    # TUI interactiva
```

Dentro de la TUI (comandos útiles):

| Comando | Acción |
|---------|--------|
| `/models` | Cambiar modelo (debería verse solo `ollama/qwen2.5:7b`) |
| `/new` | Nueva sesión |
| `/compact` | Compactar contexto manualmente |
| `/status` | Tokens, modelo, compactions |
| `Ctrl+C` | Cancelar generación |

Modo no interactivo (scripts, CI local):

```bash
opencode run "Explica qué hace main.py"
opencode run -m ollama/qwen2.5:7b "Refactoriza esta función" -f src/foo.ts
```

Continuar la última sesión:

```bash
opencode -c
opencode run -c "sigue con los tests"
```

## Integración oficial con Ollama

```bash
# Arranca OpenCode ya configurado (recomendado la primera vez)
ollama launch opencode --model qwen2.5:7b

# Solo escribir config (terminal interactiva)
ollama launch opencode --config --model qwen2.5:7b
```

`ollama launch` puede inyectar config vía `OPENCODE_CONFIG_CONTENT`; lo de `~/.config/opencode/opencode.json` **sigue aplicándose** (merge).

## Tips y hacks de rendimiento

### 1. Mantén Ollama caliente

```bash
systemctl --user status ollama
# Primera respuesta tras reinicio: ~8–15 s (carga del modelo)
# Siguientes: más rápidas si el modelo sigue en VRAM
```

Prueba rápida sin OpenCode:

```bash
ollama run qwen2.5:7b "ok"
```

### 2. Servidor en segundo plano (menos arranque en cada `run`)

Terminal A:

```bash
opencode serve --port 4096
```

Terminal B:

```bash
opencode run --attach http://127.0.0.1:4096 "tu prompt"
```

Evita reiniciar MCP y el backend en cada comando.

### 3. Contexto: no pidas 64k en 8GB

La doc de Ollama sugiere 64k para OpenCode; en **RX 580 8GB** con `qwen2.5:7b` usa **8192** (ya en tu config). Más contexto = más RAM/VRAM, truncado o timeouts.

Si las tool calls fallan, sube poco a poco: `num_ctx` 12288 en `opencode.json` y prueba; si OOM, vuelve a 8192.

### 4. Sesiones largas

- Usa `/compact` antes de que el contexto reviente.
- `/new` para empezar limpio en tareas nuevas.
- `OPENCODE_DISABLE_AUTOCOMPACT=1` solo si quieres desactivar compactación automática (no recomendado en chats largos).

### 5. Agente más liviano para explorar

```bash
opencode agent list
# Agente "plan" suele ser más conservador con cambios en archivos
opencode --agent plan
```

### 6. Logs y depuración

```bash
opencode --log-level DEBUG run "test" --print-logs
journalctl --user -u ollama -f
```

Busca en Ollama: `truncating input prompt` → contexto demasiado grande.

### 7. Convivencia con OpenClaw

| | OpenCode | OpenClaw |
|---|----------|----------|
| Uso | Coding en terminal / proyecto | Bot Telegram, gateway |
| Config | `~/.config/opencode/` | `~/.openclaw/` |
| Modelo | `ollama/qwen2.5:7b` | `ollama/qwen2.5:7b` |

Pueden compartir el mismo Ollama; **no lances dos inferencias pesadas a la vez** (cola en un solo runner).

### 8. Permisos y seguridad

- `bash: ask` — revisa comandos antes de ejecutar.
- Para CI desatendido (peligroso): `opencode run --dangerously-skip-permissions "..."` solo en entornos aislados.

### 9. Actualizar sin romper config

```bash
opencode upgrade
# Config en ~/.config/opencode/opencode.json no se toca
```

### 10. Desinstalar

```bash
opencode uninstall --dry-run
opencode uninstall --keep-config   # solo binario
```

## Solución de problemas

| Síntoma | Qué hacer |
|---------|-----------|
| `opencode: command not found` | `source ~/.zshrc` o `export PATH="$HOME/.opencode/bin:$PATH"` |
| No aparece `ollama/qwen2.5:7b` en `/models` | `systemctl --user start ollama`; revisa `opencode.json`; `opencode models ollama` |
| Muy lento vs `ollama run` | Normal: OpenCode añade system prompt, tools y compaction |
| Timeout / `fetch failed` | Sube `timeout` en provider; comprueba `chunkTimeout` |
| Tool calls fallan | Sube `num_ctx` en config del modelo (con cuidado en 8GB) |
| Solo modelos cloud en lista | `export OPENCODE_DISABLE_MODELS_FETCH=true` y config Ollama en JSON |

## Referencias

- [OpenCode CLI](https://opencode.ai/docs/cli/)
- [Config](https://opencode.ai/docs/config/)
- [Providers / Ollama](https://opencode.ai/docs/providers/)
- [Ollama + OpenCode](https://docs.ollama.com/integrations/opencode)
