#!/usr/bin/env python3
"""
J.A.RV.I.S. Production Environment Security Guardrail
======================================================
PreToolUse lifecycle hook for Antigravity CLI.
Intercepts shell commands targeting Production (rodo-prod0226) and enforces
mandatory user authorization prompt, preventing accidental production mutations.
"""

import sys
import json
import re

DANGEROUS_VERBS = [
    r"\bdeploy\b",
    r"\bdelete\b",
    r"\bdestroy\b",
    r"\bset\b",
    r"\bupdate\b",
    r"\bwrite\b",
    r"\bpatch\b",
    r"\bdrop\b",
    r"\brm\b",
    r"\bapply\b"
]

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input:
            print(json.dumps({"decision": "allow"}))
            return

        payload = json.loads(raw_input)
        tool_call = payload.get("toolCall", {})
        tool_name = tool_call.get("name", "")
        args = tool_call.get("args", {})

        if tool_name == "run_command":
            cmd = args.get("CommandLine", "")

            # Check if command targets Production rodo-prod0226
            if "rodo-prod0226" in cmd:
                # Check for mutating/destructive verbs
                is_mutating = any(re.search(verb, cmd, re.IGNORECASE) for verb in DANGEROUS_VERBS)
                if is_mutating:
                    # Enforce explicit user confirmation prompt
                    print(json.dumps({
                        "decision": "force_ask",
                        "reason": (
                            "J.A.R.V.I.S. SAFETY GATE ENGAGED: Command targets Production environment "
                            "(rodo-prod0226) with a mutating operation. Explicit user authorization required."
                        )
                    }))
                    return

        print(json.dumps({"decision": "allow"}))
    except Exception as e:
        # Fallback to allow on parser error to prevent blocking benign commands
        print(json.dumps({"decision": "allow"}))

if __name__ == "__main__":
    main()
