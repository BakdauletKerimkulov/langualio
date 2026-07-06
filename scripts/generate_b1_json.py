#!/usr/bin/env python3
"""Generate enriched B1 vocabulary JSON using Claude API.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 scripts/generate_b1_json.py

The script reads words from b1_words.txt, sends them in batches to Claude API,
and saves the result to assets/data/b1_words.json.

Intermediate batch results are saved to scripts/output/ for resumability.
"""

import json
import os
import re
import sys
import time

import anthropic

WORDS_FILE = "/Users/bakdaulet/work/Projects/vocab-quiz-data/b1_words.txt"
OUTPUT_DIR = "/Users/bakdaulet/work/langualio/scripts/output"
FINAL_OUTPUT = "/Users/bakdaulet/work/langualio/assets/data/b1_words.json"

BATCH_SIZE = 30  # words per API call
MODEL = "claude-sonnet-4-20250514"

SYSTEM_PROMPT = """You are a professional linguist creating a vocabulary database for a language learning app.
For each English word provided, generate a JSON object with accurate translations, IPA pronunciation, definitions, and example sentences.

Target audience: Russian-speaking learners at B1 (intermediate) level.

IMPORTANT rules:
- IPA must be accurate British English pronunciation
- Translations must be natural Russian equivalents
- Example sentences should be simple, B1-appropriate
- Definitions should be clear and concise
- If a word has multiple parts of speech, create a separate meaning object for each
- Use ONLY these part_of_speech values: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, phrase"""

USER_PROMPT_TEMPLATE = """Generate JSON for the following B1 vocabulary words. Each word has its part(s) of speech listed after a tab.

Return ONLY a JSON array (no markdown fences, no explanation). Each element must follow this exact schema:

{{
  "id": "b1_{{word_snake_case}}",
  "word": "the word",
  "ipa": "/IPA transcription/",
  "level": "b1",
  "meanings": [
    {{
      "part_of_speech": "noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection|phrase",
      "translation": "основной русский перевод",
      "alternative_translations": ["альтернатива1", "альтернатива2"],
      "definition_en": "English definition",
      "definition_ru": "Определение на русском",
      "example_en": "Example sentence in English.",
      "example_ru": "Пример предложения на русском."
    }}
  ],
  "topic": null,
  "tags": [],
  "created_at": null,
  "updated_at": null,
  "status": null,
  "created_by": null
}}

Rules for "id": lowercase, replace spaces with underscore, prefix "b1_". E.g. "break down" → "b1_break_down".
Rules for "meanings": one meaning object per part_of_speech. If word has "noun,verb" → two meaning objects.

Words:
{words}"""


def load_words():
    """Load words from b1_words.txt."""
    words = []
    with open(WORDS_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) == 2:
                words.append({"word": parts[0], "pos": parts[1]})
    return words


def get_completed_batches():
    """Get set of already completed batch indices."""
    completed = set()
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        return completed

    for f in os.listdir(OUTPUT_DIR):
        match = re.match(r'batch_(\d+)\.json', f)
        if match:
            completed.add(int(match.group(1)))
    return completed


def process_batch(client, batch_words, batch_idx):
    """Send a batch of words to Claude API and save the result."""
    words_text = "\n".join(f"{w['word']}\t{w['pos']}" for w in batch_words)

    prompt = USER_PROMPT_TEMPLATE.format(words=words_text)

    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = client.messages.create(
                model=MODEL,
                max_tokens=8192,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )

            text = response.content[0].text.strip()

            # Remove markdown fences if present
            if text.startswith("```"):
                text = re.sub(r'^```\w*\n?', '', text)
                text = re.sub(r'\n?```$', '', text)
                text = text.strip()

            entries = json.loads(text)

            # Save batch
            output_path = os.path.join(OUTPUT_DIR, f"batch_{batch_idx:04d}.json")
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(entries, f, ensure_ascii=False, indent=2)

            print(f"  Batch {batch_idx}: {len(entries)} entries saved")
            return entries

        except json.JSONDecodeError as e:
            print(f"  Batch {batch_idx}: JSON parse error (attempt {attempt+1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2)
            else:
                # Save raw text for debugging
                error_path = os.path.join(OUTPUT_DIR, f"batch_{batch_idx:04d}_error.txt")
                with open(error_path, 'w') as f:
                    f.write(text)
                print(f"  Raw response saved to {error_path}")
                return None

        except anthropic.RateLimitError:
            wait = 30 * (attempt + 1)
            print(f"  Rate limited, waiting {wait}s...")
            time.sleep(wait)

        except Exception as e:
            print(f"  Batch {batch_idx}: Error (attempt {attempt+1}): {e}")
            if attempt < max_retries - 1:
                time.sleep(5)
            else:
                return None

    return None


def merge_batches():
    """Merge all batch files into final output."""
    all_entries = []

    batch_files = sorted(
        f for f in os.listdir(OUTPUT_DIR)
        if re.match(r'batch_\d+\.json', f)
    )

    for bf in batch_files:
        path = os.path.join(OUTPUT_DIR, bf)
        with open(path, encoding='utf-8') as f:
            entries = json.load(f)
            all_entries.extend(entries)

    # Sort by word alphabetically
    all_entries.sort(key=lambda e: e.get("word", "").lower())

    # Remove duplicates by id
    seen_ids = set()
    unique_entries = []
    for entry in all_entries:
        eid = entry.get("id", "")
        if eid not in seen_ids:
            seen_ids.add(eid)
            unique_entries.append(entry)

    return unique_entries


def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ERROR: Set ANTHROPIC_API_KEY environment variable")
        print("  export ANTHROPIC_API_KEY=sk-ant-...")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    # Load words
    words = load_words()
    print(f"Loaded {len(words)} words")

    # Split into batches
    batches = [words[i:i+BATCH_SIZE] for i in range(0, len(words), BATCH_SIZE)]
    print(f"Split into {len(batches)} batches of {BATCH_SIZE}")

    # Check which batches are already done
    completed = get_completed_batches()
    print(f"Already completed: {len(completed)} batches")

    # Process remaining batches
    failed = []
    for idx, batch in enumerate(batches):
        if idx in completed:
            continue

        print(f"Processing batch {idx}/{len(batches)-1} ({batch[0]['word']} - {batch[-1]['word']})...")
        result = process_batch(client, batch, idx)

        if result is None:
            failed.append(idx)
            print(f"  FAILED batch {idx}")

        # Small delay between requests to be respectful
        time.sleep(1)

    if failed:
        print(f"\n{len(failed)} batches failed: {failed}")
        print("Re-run the script to retry failed batches.")

    # Merge all batches
    print("\nMerging all batches...")
    all_entries = merge_batches()
    print(f"Total unique entries: {len(all_entries)}")

    # Save final output
    with open(FINAL_OUTPUT, 'w', encoding='utf-8') as f:
        json.dump(all_entries, f, ensure_ascii=False, indent=2)

    print(f"\nSaved to {FINAL_OUTPUT}")
    print(f"File size: {os.path.getsize(FINAL_OUTPUT) / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
