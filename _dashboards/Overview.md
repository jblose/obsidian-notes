# 🧭 Notes Dashboard

```dataviewjs
const today = window.moment().format("YYYY-MM-DD");
dv.header(2, `[[1_daily/${today}|Open today's daily note]]`);
```

## 📝 Open Todos
```dataview
TASK
FROM "4_mastertracker" OR "1_daily" OR "3_people" OR "2_projects"
WHERE !completed
SORT file.mtime DESC
```

## 🧱 Active Projects
```dataview
TABLE status AS "Status", owners AS "Owners", file.mtime AS "Last Updated"
FROM "2_projects"
WHERE status != "Done"
SORT file.mtime DESC
```

## 💡 Ideas Collected
```dataviewjs
const folders = [
  { path: "1_daily", kind: "Daily" },
  { path: "5_reference", kind: "Reference" },
  { path: "2_projects", kind: "Project" },
  { path: "3_people", kind: "Person" },
];

let rows = [];
for (let f of folders) {
  const pages = dv.pages('"' + f.path + '"');
  for (let page of pages) {
    const content = await dv.io.load(page.file.path);
    const lines = content.split("\n");
    lines.forEach((line, idx) => {
      if (line.includes("#idea")) {
        rows.push({ kind: f.kind, source: page.file.link, lineNumber: idx + 1, idea: line, mtime: page.file.mtime });
      }
    });
  }
}
rows.sort((a, b) => b.mtime - a.mtime);
dv.table(["Kind", "Source", "Line", "Idea", "Last Updated"], rows.map(r => [r.kind, r.source, r.lineNumber, r.idea, r.mtime]));
```

## 🧍 People
```dataview
TABLE Role, Team, file.mtime AS "Last Updated"
FROM "3_people"
SORT file.mtime DESC
```

## 📚 Reference Materials
```dataview
TABLE category AS "Category", summary AS "Summary", file.mtime AS "Last Updated"
FROM "5_reference"
WHERE type = "reference"
SORT file.mtime DESC
```

## 🧩 Recent Decisions
```dataview
TABLE decision AS "Decision", owner AS "Owner", file.link AS "Source"
FROM "2_projects"
WHERE contains(file.tags, "decision")
SORT file.mtime DESC
LIMIT 10
```

> Tag a decision line in any project with **#decision** to make it appear here.
