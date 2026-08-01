# Alex Rivera

**Role:** Example collaborator  
**Team:** Documentation Practice  
**Last Met:** 2026-08-01  
**Topics:** onboarding, templates, dashboards  

---

## 🧭 Focus Areas
- Learning the daily note and project-note flow.
- Giving feedback on what is confusing for new users.

## 🔗 Mentions
```dataviewjs
const personTag = "#alex-rivera";
const folders = [
  { path: "1_daily", kind: "Daily" },
  { path: "5_reference", kind: "Reference" },
  { path: "2_projects", kind: "Project" }
];

let rows = [];
for (let f of folders) {
  const pages = dv.pages('"' + f.path + '"');
  for (let page of pages) {
    const content = await dv.io.load(page.file.path);
    const lines = content.split("\n");
    lines.forEach((line, idx) => {
      if ((line.includes("Alex Rivera") || line.includes(personTag)) && !line.includes("[x]")) {
        rows.push({ kind: f.kind, source: page.file.link, lineNumber: idx + 1, mention: line, mtime: page.file.mtime });
      }
    });
  }
}
rows.sort((a, b) => b.mtime - a.mtime);
dv.table(["Kind", "Source", "Line", "Mention", "Last Updated"], rows.map(r => [r.kind, r.source, r.lineNumber, r.mention, r.mtime]));
```

## 🗓 Meeting Log
### 2026-08-01
- Notes: Reviewed the sample vault.
- Action: Try the daily note workflow.

## 💬 Feedback / Mentoring
- Keep setup steps short and explicit.
