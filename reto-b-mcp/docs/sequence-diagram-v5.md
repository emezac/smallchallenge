# Secuencia implementada — Reto B

![Arquitectura que contextualiza la secuencia](diagrams/mcp-end-to-end.svg)

![Estados que resultan de la secuencia](diagrams/action-state-machine.svg)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant A as AIFindr Agent Workflow
    participant O as Auth0
    participant M as Gateway MCP
    participant D as Domain + SQLite
    participant W as Worker
    participant B as Browser UI

    A->>M: initialize / tools/list (HTTPS)
    M-->>A: 401 + protected-resource metadata
    A->>O: Authorization Code + PKCE + resource + bank:actions
    O-->>A: JWT RS256 delegado
    A->>M: tools/list + Bearer
    M-->>A: 3 tools exactas

    U->>A: Estado de tarjeta simulada
    A->>M: get_card_status
    M->>D: card()
    D-->>M: ACTIVE
    M-->>A: Estado estructurado

    U->>A: Bloquear demo por motivo permitido
    A->>M: propose_action
    M->>D: crear PENDING_CONFIRMATION + hash(grant)
    D-->>M: alias + URL de un uso
    M-->>A: propuesta; todavía sin efecto
    A-->>U: Enlace exacto y advertencia de confirmación

    U->>B: GET /c/{grant}
    B->>D: canjear grant atómicamente
    D-->>B: 303 + cookies Secure/HttpOnly/SameSite
    B-->>U: Revisión PENDING_CONFIRMATION + CSRF
    U->>B: POST confirmar
    B->>D: validar sesión + CSRF + Origin + estado
    D-->>B: CONFIRMED
    B-->>U: 202 CONFIRMED

    W->>D: consumir trabajo confirmado
    D->>D: efecto BLOCKED + acción EXECUTED + auditoría
    U->>A: ¿Resultado?
    A->>M: get_action_status + get_card_status
    M->>D: consultar
    D-->>M: EXECUTED + BLOCKED
    M-->>A: resultado estructurado
    A-->>U: éxito simulado, sin JSON crudo
```

La confirmación no cruza el canal MCP. El `202 CONFIRMED` precede a `EXECUTED`; la separación fue observada en la prueba integrada del 2026-09-09.
