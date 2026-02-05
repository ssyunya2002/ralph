---
name: ralph-openclaw
description: "Run Ralph autonomous agent loop using OpenClaw sessions instead of external AI tools. Each task runs in a fresh sub-agent session for context isolation. Progress persists via prd.json and progress.txt. Use when you have a prd.json and want to execute user stories autonomously."
user-invocable: true
---

# Ralph OpenClaw - Autonomous Agent Loop

Runs the Ralph autonomous agent pattern using OpenClaw's session system instead of external tools like Amp or Claude Code.

---

## How It Works

**Traditional Ralph:**
```
ralph.sh → spawns amp/claude → one story → clean context → repeat
```

**Ralph OpenClaw:**
```
Main session → spawns sub-agent → one story → clean context → repeat
```

Each iteration:
1. Reads `prd.json` to find next incomplete story (highest priority)
2. Spawns a fresh sub-agent session with the task
3. Waits for sub-agent to complete
4. On success: updates `prd.json` (marks story as `passes: true`), appends learnings to `progress.txt`, git commit
5. Repeats until all stories complete or max iterations reached

---

## Key Benefits

✅ **Context Isolation**: Each task runs in a completely fresh sub-agent session—no memory of previous work, no context bloat

✅ **Long-Running**: Can handle many stories without running out of tokens or memory

✅ **Resumable**: If the main session crashes, just restart and `prd.json` remembers progress

✅ **Network Access**: Sub-agents can use the `network` agent for external operations (gh, curl, APIs)

✅ **No External Tools Needed**: Works entirely within OpenClaw—no amp or claude-cli required

---

## Prerequisites

1. **prd.json**: Create this first (use the ralph skill to convert a PRD, or write manually following the format)
2. **Git Repository**: Your project should be a git repo (for commit history)
3. **progress.txt**: Create this file with a header:
   ```
   # Ralph Progress Log
   Started: [date/time]
   ---
   ```

---

## The Loop Algorithm

**Main Session:**

```javascript
while (true) {
    // 1. Read prd.json
    let prd = JSON.parse(readFile('prd.json'));

    // 2. Find next incomplete story (lowest priority number where passes=false)
    let nextStory = prd.userStories
        .filter(s => !s.passes)
        .sort((a, b) => a.priority - b.priority)[0];

    if (!nextStory) {
        // All done!
        console.log('<promise>COMPLETE</promise>');
        break;
    }

    // 3. Spawn sub-agent for this story
    let taskPrompt = buildTaskPrompt(nextStory, prd);
    let result = sessions_spawn({
        task: taskPrompt,
        agentId: 'main',
        label: `ralph-${nextStory.id}`,
        timeout: 1800  // 30 minutes max per task
    });

    // 4. Evaluate result
    if (result.success || result.includes('passes: true')) {
        // Mark as complete
        nextStory.passes = true;

        // Update prd.json
        writeFile('prd.json', JSON.stringify(prd, null, 2));

        // Append learnings to progress.txt
        appendFile('progress.txt', `\n\n## ${new Date().toISOString()}\n\n${result.learnings || 'No learnings.'}`);

        // Git commit
        exec('git add prd.json progress.txt');
        exec(`git commit -m "Ralph: ${nextStory.id} completed - ${nextStory.title}"`);
    } else {
        // Failed - add to notes and continue to next story
        nextStory.notes = `Failed: ${result.error || 'Unknown error'}`;
        writeFile('prd.json', JSON.stringify(prd, null, 2));
        break;  // Or retry? Depends on config
    }
}
```

---

## Task Prompt Template

Each sub-agent receives this prompt:

```
You are a sub-agent working on a Ralph autonomous agent loop.

## Your Task

Story ID: {story.id}
Title: {story.title}
Description: {story.description}

## Acceptance Criteria

{acceptance criteria, numbered}

## Instructions

1. Implement the story above
2. Follow all acceptance criteria exactly
3. Run typecheck (e.g., npm run typecheck or tsc --noEmit)
4. If tests exist, run them
5. If this is a UI story, verify visually in the browser
6. When COMPLETE, update the prd.json file:
   - Find story with id "{story.id}"
   - Set "passes": true
   - Save the file

## Context

- This is a FRESH session with no memory of previous stories
- Previous stories have been implemented, tested, and committed
- Git history shows all previous work
- progress.txt contains learnings from earlier iterations
- AGENTS.md contains project-specific patterns and conventions

Work autonomously. When done, report completion.
```

---

## Running the Loop

**Manual Execution (in main session):**

Tell the main agent:
> "Run ralph-openclaw loop. Read prd.json, spawn sub-agents for each story, update progress."

The main agent will:
1. Load prd.json
2. Iterate through stories
3. Spawn sub-agents for each
4. Update progress and commit after each success

**Automated Mode (future):**

Could add a shell script like `ralph-openclaw.sh` that:
1. Reads prd.json
2. Uses OpenClaw CLI to spawn sub-agents
3. Polls for completion
4. Updates prd.json
5. Repeats

---

## File Structure

```
project-root/
├── prd.json              # Task list with progress tracking
├── progress.txt          # Append-only learnings log
├── AGENTS.md             # Updated by sub-agents with learnings
├── .git/                 # Commits = progress history
└── [your project files]
```

---

## Stop Condition

The loop exits when:
- All stories have `passes: true` → outputs `<promise>COMPLETE</promise>`
- Max iterations reached (configurable)
- Fatal error encountered

---

## Debugging

**Check current state:**
```bash
# Which stories are done?
cat prd.json | jq '.userStories[] | {id, title, passes}'

# What did we learn so far?
cat progress.txt

# Git history of Ralph commits
git log --oneline --grep="Ralph"
```

**If a sub-agent gets stuck:**
- Check the sub-agent's transcript via sessions_list and sessions_history
- The main session can still proceed with other stories

---

## Example Workflow

**Step 1: Create PRD**
```
"Create a PRD for adding user authentication"
→ Generates tasks/prd-auth.md
```

**Step 2: Convert to Ralph format**
```
"Convert tasks/prd-auth.md to prd.json"
→ Generates prd.json with userStories[]
```

**Step 3: Run Ralph OpenClaw**
```
"Run ralph-openclaw loop for prd.json"
→ Main agent spawns sub-agents:
   - Sub-agent 1: US-001 (Add users table)
   - Sub-agent 2: US-002 (Create auth service)
   - Sub-agent 3: US-003 (Build login UI)
   - ...
→ All complete, outputs COMPLETE
```

---

## Differences from Original Ralph

| Aspect | Original Ralph | Ralph OpenClaw |
|--------|----------------|----------------|
| AI Tool | Amp or Claude Code CLI | OpenClaw sessions_spawn |
| Context | Fresh CLI instance per task | Fresh sub-agent session per task |
| Network | Full access | Sub-agents use network agent |
| Persistence | git + prd.json + progress.txt | Same! |
| Trigger | Shell script | Conversational or future CLI |
| Cost | Depends on tool | Depends on model |

---

## Best Practices

1. **Keep stories small**: Each story should fit in one context window
2. **Order by dependencies**: Schema → Backend → Frontend
3. **Always include "Typecheck passes"**: Quality gate for every story
4. **For UI stories**: Add "Verify in browser" to acceptance criteria
5. **Let sub-agents update AGENTS.md**: Future iterations benefit from learnings
6. **Git commit after each success**: Progress is recoverable

---

## Notes for Sub-Agents

When you receive a Ralph OpenClaw task:

✅ DO:
- Read AGENTS.md for project context
- Read progress.txt for learnings from earlier stories
- Check git log for recent commits
- Implement the story exactly as specified
- Run quality checks (typecheck, tests)
- Update prd.json to mark your story as complete

❌ DON'T:
- Start on other stories (only do YOUR story)
- Skip acceptance criteria
- Forget to update prd.json when done
- Leave uncommitted changes
- Assume knowledge from previous stories (read progress.txt)

---

## Troubleshooting

**"Sub-agent didn't update prd.json"**
→ The main session can manually mark it as passes: true and proceed

**"Sub-agent failed repeatedly"**
→ Add error details to the story's `notes` field and skip to the next story

**"Lost track of progress"**
→ Check prd.json passes flags and git log for Ralph commits

---

## Future Enhancements

- Parallel execution of independent stories
- Automatic retry on failure
- Progress dashboard
- Integration with OpenClaw CLI for one-command execution
