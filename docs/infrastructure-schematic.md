# AI Governance Infrastructure Schematic

Use this diagram when explaining how the accelerator wires Microsoft 365, Purview DSPM, Defender for AI, Azure AI Foundry, and Fabric within a single tenant boundary.

```
                      +----------------------------------------------+
                      |          Microsoft Entra Tenant Boundary      |
                      |                                              |
                      |  +------------------+        +-------------+ |
                      |  |  Microsoft 365   |        |  Fabric /   | |
                      |  |  (Teams, EXO,    |        |  OneLake    | |
                      |  |  SharePoint, etc)|        |  Workspaces | |
                      |  +--------+---------+        +------+------+ |
                      |           |                           |      |
                      |           | Unified Audit / KYD        |      |
                      |           v                           v      |
                      |  +------------------+       +---------------+ |
                      |  |  Purview DSPM    |<----->| Defender for  | |
                      |  |  (Spec-driven    |  Alerts| AI / Defender| |
                      |  |  policies, scans)|       | for Cloud     | |
                      |  +----+------+------+       +-------+-------+ |
                      |       ^      ^                      |         |
                      |       |      |                      |         |
                      |  DLP /|      |Scan metadata         |Diag +   |
                      |  Retention   |                      |signals   |
                      |       |      |                      v         |
                      |  +----+------+-----+      +------------------+|
                      |  |   Azure AI       |<---->|  Log Analytics   ||
                      |  |   Foundry        |  Diag|  Workspace       ||
                      |  | (projects,       |  data|  (Sentinel/SOC)  ||
                      |  |  Content Safety) |      +------------------+|
                      |  +---------+--------+               ^          |
                      |            |                        |          |
                      |            |Secure Interactions     |Evidence   |
                      |            v                        |Exports    |
                      |       +----+-----+                  |          |
                      |       |  Users & |<-----------------+          |
                      |       |  AI Apps |  Prompts/Results            |
                      |       +----------+                             |
                      +----------------------------------------------+
```

## Interaction callouts
- **Secure interactions (KYD)**: M365 sends Foundry prompts/responses to Purview DSPM via Unified Audit, landing in user mailboxes for retention/eDiscovery.
- **Purview ↔ Defender for AI**: DSPM recommendations illuminate Defender posture; Defender for AI sends detections back to Purview activity explorer.
- **Foundry ↔ Log Analytics**: `07-Enable-Diagnostics.ps1` streams diagnostic logs from Cognitive Services/Foundry to Log Analytics, powering Defender analytics and SOC hunting.
- **Fabric/OneLake ↔ Purview**: Registration/scans keep Fabric datasets classified so downstream Foundry agents respect sensitivity labels.
- **Evidence exports**: Purview audit exports (Management Activity) and compliance inventory dumps feed Log Analytics or storage for regulators.
