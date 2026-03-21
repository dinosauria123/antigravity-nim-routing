# Antigravity NIM Routing

A script that delegates part of Antigravity's processing to an LLM (NVIDIA NIM).

<img width="739" height="479" alt="IMG_1777" src="https://github.com/user-attachments/assets/cbafa4ec-a251-424e-86c1-4295005df93b" />

## Features

* **Requests to NVIDIA NIM (cloud LLM)**
* **Thinking mode** control (e.g., Qwen 3.5)
* **Automatic JSON escape handling**

## Setup

1. Download or `git clone` the repository.
2. Copy `.env.example` to create a `.env` file.
3. If using NVIDIA NIM, set your `NVIDIA_API_KEY` in `.env`.

```
cp .env.example .env
# Edit .env and enter your API key
```

## Usage

### Linux / macOS (`llm_task.sh`)

```
# Run with the default model
bash llm_task.sh "Hello. Please introduce yourself."

# Run with a specified model
bash llm_task.sh "qwen/qwen3.5-122b-a10b" "Please solve a complex math problem."

# Run with a switched backend (using NIM)
LLM_BACKEND=nim bash llm_task.sh "Hello"
```

### Windows (`llm_task.bat`)

On Windows, you can use `llm_task.bat`.

### Antigravity

Open the folder deployed with Antigravity and type something like the following into the Agent (Chat):  
`"Following the rules in .agent/rules/nim-routing, please create a web app that calculates pi to an arbitrary number of digits."`

## License

[MIT License](https://github.com/dinosauria123/antigravity-nim-routing/blob/main/LICENSE
