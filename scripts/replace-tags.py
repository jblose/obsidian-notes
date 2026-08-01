#!/usr/bin/env python3
"""Preview and replace Obsidian-style tags across Markdown notes."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_TARGETS = (
    "0_templates",
    "1_daily",
    "2_projects",
    "3_people",
    "4_mastertracker",
    "5_reference",
    "_dashboards",
)

TAG_VALUE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_/-]*$")
FENCE_OPEN_RE = re.compile(r"^(\s*)(`{3,}|~{3,})")


@dataclass(frozen=True)
class TagReplacement:
    source: str
    target: str
    pattern: re.Pattern[str]


def normalize_tag(tag: str) -> str:
    cleaned = tag.strip()
    if cleaned.startswith("#"):
        cleaned = cleaned[1:]

    if not cleaned:
        raise ValueError("tag cannot be empty")

    if not TAG_VALUE_RE.fullmatch(cleaned):
        raise ValueError(
            f"invalid tag '{tag}'; use letters, numbers, '_', '-', or '/'"
        )

    return f"#{cleaned}"


def build_replacement(source: str, target: str) -> TagReplacement:
    source_tag = normalize_tag(source)
    target_tag = normalize_tag(target)

    pattern = re.compile(
        rf"(?<![#A-Za-z0-9_/-]){re.escape(source_tag)}(?![A-Za-z0-9_/-])"
    )

    return TagReplacement(source=source_tag, target=target_tag, pattern=pattern)


def parse_mapping_entry(entry: str) -> tuple[str, str]:
    if "=" not in entry:
        raise ValueError(f"invalid mapping '{entry}'; expected OLD=NEW")

    source, target = entry.split("=", 1)
    return source.strip(), target.strip()


def load_mapping_file(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []

    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        try:
            pairs.append(parse_mapping_entry(line))
        except ValueError as exc:
            raise ValueError(f"{path}:{line_number}: {exc}") from exc

    return pairs


def collect_replacements(args: argparse.Namespace) -> list[TagReplacement]:
    pairs: list[tuple[str, str]] = []

    if args.source or args.target:
        if not (args.source and args.target):
            raise ValueError("use --source and --target together")
        pairs.append((args.source, args.target))

    for entry in args.map:
        pairs.append(parse_mapping_entry(entry))

    for mapping_file in args.mapping_file:
        pairs.extend(load_mapping_file(Path(mapping_file)))

    if not pairs:
        raise ValueError("provide --source/--target, --map, or --mapping-file")

    replacements = [build_replacement(source, target) for source, target in pairs]

    seen_sources: dict[str, str] = {}
    for replacement in replacements:
        existing_target = seen_sources.get(replacement.source)
        if existing_target and existing_target != replacement.target:
            raise ValueError(
                f"conflicting targets for {replacement.source}: "
                f"{existing_target} and {replacement.target}"
            )
        seen_sources[replacement.source] = replacement.target

    return replacements


def resolve_markdown_files(paths: list[str] | None) -> list[Path]:
    requested_paths = paths or list(DEFAULT_TARGETS)
    files: set[Path] = set()

    for raw_path in requested_paths:
        path = Path(raw_path)
        if not path.exists():
            raise FileNotFoundError(f"path not found: {raw_path}")

        if path.is_file():
            if path.suffix == ".md":
                files.add(path)
            continue

        for candidate in path.rglob("*.md"):
            if candidate.is_file():
                files.add(candidate)

    return sorted(files)


def replace_plain_text(text: str, replacements: list[TagReplacement]) -> tuple[str, int]:
    updated = text
    replacements_made = 0

    for replacement in replacements:
        updated, count = replacement.pattern.subn(replacement.target, updated)
        replacements_made += count

    return updated, replacements_made


def replace_outside_inline_code(
    line: str, replacements: list[TagReplacement]
) -> tuple[str, int]:
    parts: list[str] = []
    replacement_count = 0
    index = 0
    code_delimiter_length: int | None = None

    while index < len(line):
        if line[index] == "`":
            end = index
            while end < len(line) and line[end] == "`":
                end += 1

            tick_run = line[index:end]
            parts.append(tick_run)

            if code_delimiter_length is None:
                code_delimiter_length = len(tick_run)
            elif code_delimiter_length == len(tick_run):
                code_delimiter_length = None

            index = end
            continue

        end = index
        while end < len(line) and line[end] != "`":
            end += 1

        chunk = line[index:end]
        if code_delimiter_length is None:
            chunk, count = replace_plain_text(chunk, replacements)
            replacement_count += count

        parts.append(chunk)
        index = end

    return "".join(parts), replacement_count


def transform_markdown(
    content: str, replacements: list[TagReplacement], include_code: bool
) -> tuple[str, int]:
    output_lines: list[str] = []
    replacement_count = 0
    fence_marker: str | None = None
    fence_length = 0

    for line in content.splitlines(keepends=True):
        fence_match = FENCE_OPEN_RE.match(line)

        if fence_marker is None and fence_match:
            fence_marker = fence_match.group(2)[0]
            fence_length = len(fence_match.group(2))
            output_lines.append(line)
            continue

        if fence_marker is not None:
            updated_line = line
            count = 0
            if include_code:
                updated_line, count = replace_plain_text(line, replacements)

            if re.match(rf"^\s*{re.escape(fence_marker)}{{{fence_length},}}\s*$", line):
                fence_marker = None
                fence_length = 0
            output_lines.append(updated_line)
            replacement_count += count
            continue

        if include_code:
            updated_line, count = replace_plain_text(line, replacements)
        else:
            updated_line, count = replace_outside_inline_code(line, replacements)

        output_lines.append(updated_line)
        replacement_count += count

    return "".join(output_lines), replacement_count


def changed_lines(original: str, updated: str) -> list[tuple[int, str, str]]:
    original_lines = original.splitlines()
    updated_lines = updated.splitlines()
    diffs: list[tuple[int, str, str]] = []

    for index, (before, after) in enumerate(zip(original_lines, updated_lines), start=1):
        if before != after:
            diffs.append((index, before, after))

    return diffs


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Preview and replace exact #tags across Markdown notes."
    )
    parser.add_argument("--source", help="Source tag to replace, with or without #.")
    parser.add_argument("--target", help="Target tag, with or without #.")
    parser.add_argument(
        "--map",
        action="append",
        default=[],
        metavar="OLD=NEW",
        help="Additional replacement pair. Repeat to replace multiple tags.",
    )
    parser.add_argument(
        "--mapping-file",
        action="append",
        default=[],
        metavar="PATH",
        help="File containing OLD=NEW mappings, one per line.",
    )
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        metavar="PATH",
        help="Limit the search to a file or directory. Repeat as needed.",
    )
    parser.add_argument(
        "--include-code",
        action="store_true",
        help="Also replace tags inside fenced and inline code.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the changes. Without this flag, the script only previews them.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        replacements = collect_replacements(args)
        files = resolve_markdown_files(args.path)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    total_files_changed = 0
    total_replacements = 0

    for file_path in files:
        original = file_path.read_text()
        updated, replacement_count = transform_markdown(
            original,
            replacements,
            include_code=args.include_code,
        )

        if replacement_count == 0:
            continue

        total_files_changed += 1
        total_replacements += replacement_count

        relative_path = file_path.as_posix()
        print(f"{relative_path}: {replacement_count} replacement(s)")

        for line_number, before, after in changed_lines(original, updated):
            print(f"  L{line_number}: {before}")
            print(f"       -> {after}")

        if args.apply:
            file_path.write_text(updated)

    if total_files_changed == 0:
        print("No matching tags found.")
        return 0

    mode = "Applied" if args.apply else "Previewed"
    print(
        f"{mode} {total_replacements} replacement(s) across "
        f"{total_files_changed} file(s)."
    )
    if not args.apply:
        print("Re-run with --apply to write the changes.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
