# API Route Patterns

## The Golden Pattern: Auth → Validate → Execute → Respond

Every data-modifying endpoint follows the same order. Don't rearrange it.

### Express / TypeScript

```typescript
app.post("/api/resource", async (req, res) => {
  // 1. Auth check FIRST
  const userId = req.session.userId;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  // 2. Validate input
  const validated = resourceSchema.parse(req.body);

  // 3. Execute
  const result = await db.query("INSERT INTO ...", [validated.title, userId]);

  // 4. Respond
  res.status(201).json(result);
});
```

### Flask / Python

```python
@app.route("/api/resource", methods=["POST"])
@login_required
def create_resource():
    # 1. Auth check (handled by decorator)
    # 2. Validate input
    data = ResourceSchema(**request.json)
    # 3. Execute
    result = db.execute("INSERT INTO ...", data.dict())
    # 4. Respond
    return jsonify(result), 201
```

**Why this order matters:**
- Auth before validate: don't waste cycles parsing input from unauthenticated users
- Validate before execute: never pass unvalidated data to the database
- Structured JSON responses: always, even for errors

## Error Handling

```typescript
app.post("/api/resource", async (req, res) => {
  try {
    const validated = schema.parse(req.body);
    const result = await doSomething(validated);
    res.status(200).json(result);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: "Validation failed", details: error.errors });
    }
    console.error("Unexpected error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});
```

**Rules:**
- Validation errors → 400 with details
- Unexpected errors → 500 with generic message
- **Never expose stack traces** to the client
- Log the full error server-side

## Middleware Pattern

```typescript
const requestLogger = (req: Request, res: Response, next: NextFunction) => {
  console.log(`${req.method} ${req.path}`);
  next();
};

app.use(requestLogger);
```

Keep middleware isolated and composable. Each middleware does one thing. Test independently if complex.

## Read-Only Endpoints

Read endpoints skip the validation step but still check auth:

```typescript
app.get("/api/resource/:id", async (req, res) => {
  const userId = req.session.userId;
  if (!userId) return res.status(401).json({ error: "Unauthorized" });

  const result = await db.query("SELECT * FROM resources WHERE id = ?", [req.params.id]);
  if (!result) return res.status(404).json({ error: "Not found" });

  res.json(result);
});
```

## Calling External Processes

If your app calls Python scripts, CLI tools, or other subprocesses:

```typescript
import { spawn } from "child_process";

const process = spawn("python", ["scripts/process.py", "--input", inputPath]);
let stdout = "";
let stderr = "";

process.stdout.on("data", (data) => { stdout += data; });
process.stderr.on("data", (data) => { stderr += data; });

process.on("close", (code) => {
  if (code !== 0) {
    console.error("Process failed:", stderr);
    return res.status(500).json({ error: "Processing failed" });
  }
  res.json(JSON.parse(stdout));
});
```

**Rules for subprocess calls:**
- Capture both stdout and stderr
- Check exit code before using output
- Set a timeout (subprocesses can hang)
- Never pass unsanitized user input as CLI arguments
