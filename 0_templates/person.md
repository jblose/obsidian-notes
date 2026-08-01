<%*
const meetingDate = tp.date.now("YYYY-MM-DD");
-%>
# <% tp.file.title %>

**Role:**  
**Team:**  
**Last Met:** <% meetingDate %>  
**Topics:**  

---

## 🧭 Focus Areas
- 

## 🔗 Mentions
```dataviewjs
const personTag = "#" + dv.current().file.name.replace(/\s+/g, "-").toLowerCase();
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
      if ((line.includes(dv.current().file.name) || line.includes(personTag)) && !line.includes("[x]")) {
        rows.push({ kind: f.kind, source: page.file.link, lineNumber: idx + 1, mention: line, mtime: page.file.mtime });
      }
    });
  }
}
rows.sort((a, b) => b.mtime - a.mtime);
dv.table(["Kind", "Source", "Line", "Mention", "Last Updated"], rows.map(r => [r.kind, r.source, r.lineNumber, r.mention, r.mtime]));
```

## 🗓 Meeting Log
### <% meetingDate %>
- Notes:
- Action:

## 💬 Feedback / Mentoring
- 
