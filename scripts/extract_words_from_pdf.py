#!/usr/bin/env python3
"""Extract B1 vocabulary words from Cambridge PDF (two-column layout)."""

import re
import pdfplumber

PDF_PATH = "/Users/bakdaulet/work/Projects/vocab-quiz-data/506887-b1-preliminary-vocabulary-list.pdf"
OUTPUT_PATH = "/Users/bakdaulet/work/Projects/vocab-quiz-data/b1_words.txt"

# Column split x-coordinate (left column: x < 300, right column: x >= 300)
COLUMN_SPLIT_X = 290

# Mapping of PDF abbreviations to our PartOfSpeech enum values
POS_MAP = {
    "n": "noun",
    "v": "verb",
    "adj": "adjective",
    "adv": "adverb",
    "pron": "pronoun",
    "prep": "preposition",
    "conj": "conjunction",
    "exclam": "interjection",
    "phr v": "phrase",
    "prep phr": "phrase",
    "det": "pronoun",
    "mv": "verb",
    "av": "verb",
    "n pl": "noun",
    "abbrev": "noun",
    "ad": "adverb",
}

# Pattern: word (pos_info)
ENTRY_PATTERN = re.compile(
    r'^(.+?)\s*\(([^)]+)\)\s*$'
)


def parse_pos(pos_str: str) -> list[str]:
    """Parse POS string like 'n & v', 'adj, adv & prep' into mapped values."""
    pos_str = pos_str.strip().lower()
    # Remove qualifiers like "Br Eng", "Am Eng: bookstore"
    # These appear as: (n) (Br Eng) (Am Eng: bookstore) — but within parens they'd be separate
    # In our regex they're part of the match, so clean them
    pos_str = re.sub(r'\b(br eng|am eng)[:\s]*\w*', '', pos_str).strip()
    pos_str = re.sub(r'\s+', ' ', pos_str).strip()

    # Split by & and ,
    parts = re.split(r'\s*[&,]\s*', pos_str)

    result = []
    for part in parts:
        part = part.strip()
        if part in POS_MAP:
            mapped = POS_MAP[part]
            if mapped not in result:
                result.append(mapped)

    return result


def extract_column_text(page, x_min, x_max):
    """Extract text lines from a specific column region."""
    # Crop the page to the column region
    cropped = page.within_bbox((x_min, 0, x_max, page.height))
    text = cropped.extract_text()
    if text:
        return text.split('\n')
    return []


def is_vocabulary_line(line: str) -> bool:
    """Check if a line looks like a vocabulary entry."""
    line = line.strip()
    if not line:
        return False
    # Skip bullet points
    if line.startswith(('•', '·', '–', '-')):
        return False
    # Skip section headers (single uppercase letter)
    if re.match(r'^[A-Z]\s*$', line):
        return False
    # Skip page footers
    if '©' in line or 'CUPA' in line or 'Page ' in line:
        return False
    if 'Preliminary' in line and 'for Schools' in line:
        return False
    # Skip intro/description text (long lines without parens)
    if len(line) > 60 and '(' not in line:
        return False
    return True


def parse_entry(line: str):
    """Parse a vocabulary entry line. Returns (word, pos_list) or None."""
    line = line.strip()

    if not is_vocabulary_line(line):
        return None

    # Try to match the pattern: word (pos)
    # Handle multiple POS annotations: word (n) (Br Eng) (Am Eng: bookstore)
    # We want the first parenthesized group that contains a POS abbreviation

    # Find all parenthesized groups
    paren_groups = re.findall(r'\(([^)]+)\)', line)
    if not paren_groups:
        return None

    # Find the POS group (first group that contains known POS abbreviations)
    pos_group = None
    for group in paren_groups:
        test = group.lower().strip()
        # Check if this group contains any POS abbreviation
        test_clean = re.sub(r'\b(br eng|am eng)[:\s]*\w*', '', test).strip()
        parts = re.split(r'\s*[&,]\s*', test_clean)
        if any(p.strip() in POS_MAP for p in parts):
            pos_group = group
            break

    if not pos_group:
        return None

    # Extract the word (everything before the first POS parenthetical)
    pos_start = line.index(f'({pos_group})')
    word = line[:pos_start].strip()

    # Clean the word
    word = word.strip('.,;:!? ')
    if not word or len(word) > 40:
        return None

    # Skip words that are clearly example sentences
    if ' ' in word and len(word.split()) > 4:
        return None

    pos_list = parse_pos(pos_group)
    if not pos_list:
        return None

    return (word, pos_list)


def extract_words():
    """Extract all words from the PDF."""
    words = {}  # normalized_word -> {"word": str, "pos": set}

    with pdfplumber.open(PDF_PATH) as pdf:
        for page_num, page in enumerate(pdf.pages):
            # Skip first 3 pages (title, intro, abbreviations)
            if page_num < 3:
                continue

            # Stop before appendix (starts at page 41 = index 40)
            if page_num >= 40:
                break

            # Extract text from left and right columns separately
            try:
                left_lines = extract_column_text(page, 0, COLUMN_SPLIT_X)
            except Exception:
                left_lines = []

            try:
                right_lines = extract_column_text(page, COLUMN_SPLIT_X, page.width)
            except Exception:
                right_lines = []

            # Process all lines from both columns
            for line in left_lines + right_lines:
                result = parse_entry(line)
                if result:
                    word, pos_list = result
                    key = word.lower()
                    if key not in words:
                        words[key] = {"word": word, "pos": set()}
                    words[key]["pos"].update(pos_list)

    return words


def main():
    words = extract_words()

    # Sort alphabetically
    sorted_words = sorted(words.items(), key=lambda x: x[0])

    # Write to file
    with open(OUTPUT_PATH, 'w') as f:
        for key, data in sorted_words:
            pos_str = ",".join(sorted(data["pos"]))
            f.write(f"{data['word']}\t{pos_str}\n")

    print(f"Extracted {len(sorted_words)} words to {OUTPUT_PATH}")

    # Print some stats
    pos_counts = {}
    for key, data in sorted_words:
        for pos in data["pos"]:
            pos_counts[pos] = pos_counts.get(pos, 0) + 1

    print("\nPOS distribution:")
    for pos, count in sorted(pos_counts.items(), key=lambda x: -x[1]):
        print(f"  {pos}: {count}")

    # Print first and last 10 words for verification
    print("\nFirst 10 words:")
    for key, data in sorted_words[:10]:
        print(f"  {data['word']}\t{','.join(sorted(data['pos']))}")

    print("\nLast 10 words:")
    for key, data in sorted_words[-10:]:
        print(f"  {data['word']}\t{','.join(sorted(data['pos']))}")


if __name__ == "__main__":
    main()
