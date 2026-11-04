# Conversational Dungeon Companion — experimental feature

This is an opt-in, NetHackWiki-grounded conversational AI implementation
for the Samsung Galaxy Tab A8 fixed tablet interface. It is not deployed
or tested on the tablet yet.

## GitHub and safe branches

Both Amphitere and ForkFront-Android-DS use feature/conversational-companion.
The feature is branched from feature/ai-companion, which contained the
working large wiki results pop-out. Neither tested v2 release checkpoint
nor any original v1 stable tag has been modified. No PR is merged.

## Android changes

- Continue using the existing **Ask NetHackWiki** button and wide wiki popup
  with no server configuration.
- **Configure secure AI** accepts a trusted HTTPS endpoint and a random
  pairing token (NOT an OpenAI API key). Android Keystore AES-GCM protects
  the locally saved token.
- **Ask AI (wiki-grounded)** sends a typed question, role and up to six
  recent chat turns to the configured backend. Conversation is memory-only.
- **Share HP/level: OFF** starts off on every new app session. Only after
  deliberate opt-in are a few status fields sent: HP, HP maximum, power,
  power maximum, AC, experience level, depth and hunger. The app does
  NOT send player name, inventory, map, coordinates or save files.
- In-world and factual advice modes remain available. The AI answer opens
  in the already-proven wide pop-out with clickable NetHackWiki sources.
  No game commands are executed automatically.

## Deploying the secure backend (one-time)

The Android APK cannot generate AI responses on its own. A separately
configured and deployed backend is necessary. The Node.js 20+ Vercel
function and tests are under services/companion/ in this main repository.

1. In Vercel, create a SEPARATE project that imports
   starez74/Amphitere. Set Root Directory to services/companion,
   framework preset Other, and deploy the experimental
   feature/conversational-companion branch as a preview (or explicitly
   select that as Production Branch). Do not merge into stable main.
2. Configure the Vercel project's environment variables:
   - OPENAI_API_KEY: your server-side OpenAI developer API key
   - COMPANION_CLIENT_TOKEN: a separate randomly generated pairing secret
     with at least 32 characters
   - OPENAI_MODEL: optional; default gpt-5.4-mini
3. Generate a suitable random pairing secret using Windows PowerShell:

       $bytes = New-Object byte[] 32
       $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
       try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
       [Convert]::ToBase64String($bytes)

   Copy it privately into Vercel COMPANION_CLIENT_TOKEN. Do NOT put any
   credential into a commit, a screenshot, or this chat.
4. Deploy. In the Android companion configuration use the deployed HTTPS
   address including /api/ask, for example
   https://YOUR-PROJECT.vercel.app/api/ask (or the Vercel preview URL),
   and enter the same pairing token. The provider API key never leaves
   the server. Android rejects plaintext HTTP and redirects.
5. Set OpenAI API budget limits and Vercel abuse controls. The backend's
   in-memory request limiter is per-instance ONLY: it does not provide
   a distributed rate limit. Add service-level WAF/rate limiting for
   public or multi-user deployment.

OpenAI API billing is separate from a ChatGPT subscription. API calls
may incur charges. Questions, role, conversation, and any opted-in
status fields are processed by the backend and the AI provider.
The Responses API request has store=false; provider operational retention
may differ. The backend does not save user conversations.

The server fetches NetHackWiki plain-text introductions. It instructs
the model to cite the retrieved evidence and to admit uncertainty.
If no useful source text exists, no model call is made and the user is
shown a no-evidence message with links. AI advice can still be wrong.

## Build and tablet testing

Save & Quit first, then use the branch-specific automatic script:

    $Script = "$env:TEMP\Build-ConversationalCompanion.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/starez74/Amphitere/feature/conversational-companion/scripts/Build-ConversationalCompanion.ps1" -OutFile $Script
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -Install

The script verifies expected origins and submodule commit, fetches
feature branches, fast-forward merges only, backs up the current APK,
builds via Gradle and updates the tablet with adb install -r. It does
not uninstall, wipe, delete saves or commit or push code.

### Acceptance checklist

- On a fresh app launch confirm Share HP/level starts OFF.
- Wiki-only search, normal fixed keyboard, movement and inventory
  continue to work with no backend deployment.
- Configure AI prompts for HTTPS URL and pairing token; enter no
  provider API key on Android.
- Ask AI with sharing OFF. Confirm the game neither moves nor uses
  question characters as commands.
- Ask with sharing ON and check an answer citing wiki articles
  and using HP/depth context, without pretending to see inventory.
- Toggle role/factual mode; close and reopen the wide AI answer.
- Invalid token/server outage returns a clear error and wiki-only
  remains available.
- Save & Quit, then restore the existing character and inventory.
- Never merge draft PRs until compiled and tested successfully.

## Backend tests

On a machine with Node.js 20+:

    cd services/companion
    node --test

This test path uses no real provider keys. Backend deployment,
model billing setup, and tablet installation are not performed
by GitHub commits.

## References

- NetHackWiki: https://nethackwiki.com/
- Wiki attribution: https://nethackwiki.com/wiki/NetHackWiki:Copyrights
- OpenAI Responses API: https://developers.openai.com/api/reference/resources/responses/methods/create
