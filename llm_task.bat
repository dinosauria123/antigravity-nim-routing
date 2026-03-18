@echo off
setlocal enabledelayedexpansion

:: Load .env
set "_SCRIPT_DIR=%~dp0"
if exist "%_SCRIPT_DIR%.env" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%_SCRIPT_DIR%.env") do (
        set "%%A=%%B"
    )
)

:: Auth/Config
if not defined LLM_BACKEND set "LLM_BACKEND=nim"
set "BACKEND=%LLM_BACKEND%"
if not defined NVIDIA_API_KEY set "NVIDIA_API_KEY=%NVIDIA_API_KEY%"

:: Arg check
if "%~1"=="" (
    echo [Usage] llm_task.bat prompt
    echo         llm_task.bat model prompt
    exit /b 1
)
:: Prompt/Model
if "%~2"=="" (
    set "LLM_PROMPT=%~1"
    if /i "%BACKEND%"=="nim" (set "MODEL=qwen/qwen3.5-122b-a10b") else (set "MODEL=gemma3:1b")
) else (
    set "MODEL=%~1"
    set "LLM_PROMPT=%~2"
)

:: Temp files
set "TMP_JSON=%TEMP%\llm_req_%RANDOM%.json"
set "TMP_HDR=%TEMP%\llm_hdr_%RANDOM%.txt"
set "TMP_RESP=%TEMP%\llm_res_%RANDOM%.json"

:: Create Request Body via Python (Robust)
python -c "import os,json; d={'model':os.environ.get('MODEL'), 'messages':[{'role':'user','content':os.environ.get('LLM_PROMPT')}], 'max_tokens':4096, 'stream':False}; open(os.environ.get('TMP_JSON'), 'w', encoding='utf-8').write(json.dumps(d))"

:: Create Headers
if /i "%BACKEND%"=="nim" (
    set "BASE_URL=https://integrate.api.nvidia.com/v1"
    set "AUTH_VAL=Bearer %NVIDIA_API_KEY%"
) else (
    set "BASE_URL=http://127.0.0.1:11434/v1"
    set "AUTH_VAL=Bearer ollama"
)

(
echo Content-Type: application/json
echo Authorization: %AUTH_VAL%
) > "%TMP_HDR%"

:: Execute via Powershell
powershell -NoProfile -Command "$h=@{}; Get-Content '%TMP_HDR%' | ForEach-Object { if ($_ -match '^(.+?): (.+)$') { $h[$matches[1]]=$matches[2].Trim() } }; try { $r = Invoke-RestMethod -Uri '%BASE_URL%/chat/completions' -Method Post -Headers $h -InFile '%TMP_JSON%' -TimeoutSec 120; Write-Output $r.choices[0].message.content; } catch { Write-Error $_.Exception.Message; exit 1; }" > "%TMP_RESP%" 2>&1

if errorlevel 1 (
    echo Error occurred >&2
    type "%TMP_RESP%" >&2
    goto cleanup
)

:: Success: Output result
type "%TMP_RESP%"

:cleanup
if exist "%TMP_JSON%" del "%TMP_JSON%"
if exist "%TMP_HDR%" del "%TMP_HDR%"
if exist "%TMP_RESP%" del "%TMP_RESP%"
exit /b
