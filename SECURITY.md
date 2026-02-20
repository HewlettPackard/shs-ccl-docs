# Security Policy

This document describes how to report security issues for the **HewlettPackard/shs-ccl-docs** repository and how maintainers handle coordinated disclosure.

## Supported Versions

Security fixes are applied to the default development branch.

| Version | Supported |
| ------- | --------- |
| default branch (e.g., `main`) | :white_check_mark: |

> Note: If this repository uses release branches or tags in the future, maintainers may choose to backport fixes when feasible.

## Reporting a Vulnerability (Private Disclosure)

Security is taken seriously. **Please do not open public GitHub issues for suspected security vulnerabilities.**

### Preferred method: GitHub Security Advisories

Use **GitHub Security Advisories** to report vulnerabilities privately:

1. Navigate to the repository’s **Security** tab: `../../security`
2. Click **"Report a vulnerability"**
3. Fill out the advisory form using the guidance below

This enables private discussion and coordinated disclosure without requiring email.

### Alternative contact

If you cannot use GitHub Security Advisories, contact **github@hpe.com**.

## Information to Include

Please provide as much of the following information as possible:

- Your name and affiliation (optional but helpful)
- Type of issue (e.g., code execution via tooling, supply-chain compromise, credential leakage, XSS in generated docs, unsafe deserialization, etc.)
- The location of the affected content (file paths and line numbers, or links to specific commits)
- The branch/tag/commit SHA where you observed the issue
- Any special configuration required to reproduce the issue (OS, container image, build target, CI workflow name)
- Step-by-step reproduction instructions (scripts, screenshots, logs)
- Proof-of-concept (PoC) code or minimal reproducer (if available)
- Impact assessment (what an attacker can do, prerequisites, affected environments)

Even if you cannot provide every detail, **please report promptly**—partial reports are welcome.

## What Should Be Reported

Report security issues that affect the repository, its build/publish pipeline, or users who consume artifacts produced from this repository, including:

- Vulnerabilities in documentation build tooling (scripts, containers, dependencies)
- Issues in CI/CD workflows (e.g., GitHub Actions) that could enable unauthorized code execution or secret exfiltration
- Exposure of credentials, tokens, private keys, or sensitive configuration in the repository history
- Unsafe content that could lead to client-side compromise when viewing published docs (e.g., malicious HTML/JS in generated output)
- Dependency vulnerabilities that are exploitable in the context of this repo’s tooling

Non-security bugs (typos, formatting, broken links, feature requests) should be filed as normal GitHub issues.

## Response, Patch, and Disclosure

The maintainers will respond to valid vulnerability reports as follows:

1. **Triage** the report and determine scope, severity, and affected components
2. If the issue is not deemed a vulnerability, provide a reasoned explanation
3. **Initiate a private conversation** with the reporter within **3 business days**
4. Develop a remediation plan and identify any mitigations users can apply immediately
5. Assign a severity rating (e.g., CVSS) when applicable
6. Implement and test a fix
7. Coordinate a disclosure timeline with the reporter

### Public disclosure

After a fix is available, maintainers may publish a public advisory via `../../security/advisories` describing the issue, affected versions/commits, and mitigations.

## Scope and Threat Model Notes

Because **shs-ccl-docs** is documentation-focused, the most likely security risks include:

- Compromise of documentation build or publishing pipelines
- Malicious changes to scripts or tooling that run in CI or locally
- Dependency/supply-chain vulnerabilities in the documentation toolchain
- Content injection leading to unsafe rendered output in published documentation

## Preferred Languages

English is preferred for vulnerability reports and follow-up communications.
