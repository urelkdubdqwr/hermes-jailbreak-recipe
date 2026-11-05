# Disclaimer

This repository documents a prompt-layer experiment on **Hermes Agent running on a machine its operator owns**.

- It is research notes and installer code, released so the mechanism is auditable rather than mysterious.
- It is **not** a magic uncensoring tool. As measured in [`docs/results.md`](docs/results.md), prompt-layer work does not remove upstream model alignment — refusal behaviour comes back from the weights regardless of what the prompt says.
- Providers have terms of service. Running this against an account you do not own, or against a service in violation of its terms, is your decision and your consequence — the authors are not a party to it.
- Nothing here is a claim about any third party's systems, and no code in this repo attacks anything: it configures one local agent install.
- The operator-credential invariant (never echo, log, or print operator secrets, even on request) is deliberate. Keep it in your fork.
- Use on your own machine, at your own risk. No warranty, MIT terms.
