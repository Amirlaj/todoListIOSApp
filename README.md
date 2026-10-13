# Flashcards for iOS

A SwiftUI flashcard app. Organise your studies into **modules** (subjects), split each module into **chapters**, and import **CSV** or **Markdown** files into a chapter. The app extracts the cards from the files automatically.

## Features

- **Modules → Chapters → Flashcards.** Create, rename, colour, reorder and delete them.
- **Import CSV and Markdown files** from the Files app, iCloud Drive and similar places. You can pick several files at once.
- **Review before adding.** After a file is parsed you see every extracted card and can untick the ones you don't want. Cards that already exist in the chapter start unticked.
- **Imported files are tracked.** Each chapter lists the files it was built from. Deleting a file removes the cards that came from it.
- **Study mode** with 3D flip cards. Tap to flip, then swipe right (or tap *Got It*) if you knew it, or left (*Again*) if you didn't. There are options to shuffle, show the answer side first and review missed cards. On iPad, keyboard shortcuts work (space flips, ← / → grade).
- **Progress tracking** uses a simple Leitner box. A card is *mastered* after 3 correct answers in a row. You can study a whole chapter, only its unmastered cards, or a whole module.
- **Markdown in cards**: **bold**, *italic*, `code`, lists and code blocks are rendered.
- Add and edit cards by hand. Search a chapter's cards.
- Data is stored on the device with SwiftData.

## Requirements

- Xcode 16 or later
- iOS 17 or later (iPhone and iPad)

## Getting started

1. Open `Flashcards.xcodeproj` in Xcode.
2. Select the **Flashcards** scheme and an iPhone simulator, then press **⌘R**.
3. On first launch, tap **Add a Sample Module** to explore, or create your own module.
4. To try importing, drag the files from [`SampleFiles/`](SampleFiles) onto the simulator (they're saved to the Files app). Then, in a chapter, tap **+ → Import CSV or Markdown**.

To run on a real device, choose your team under *Signing & Capabilities*. You may also need to change the bundle identifier (`com.amirlaj.Flashcards`).

Run the unit tests with **⌘U**.

## Supported file formats

The full guide is also in the app: open a chapter, then tap **+ → Supported Formats**.

### CSV (`.csv`, `.tsv`, `.txt`)

```csv
front,back
What is the powerhouse of the cell?,Mitochondria
"Phases of mitosis","Prophase, metaphase, anaphase, telophase"
```

- The first column is the front and the second is the back.
- The header row is optional. Headers such as `front/back`, `question/answer` or `term/definition` let you put the columns in any order. Other named columns (e.g. `example`) are added to the back of the card.
- Commas, semicolons and tabs are detected automatically. Quoted fields can contain commas, line breaks and `""` quotes. Exports from Excel, Numbers, Google Sheets, Anki and Quizlet work.

### Markdown (`.md`, `.markdown`, `.txt`)

You can mix these styles in one file:

| Style | Example |
|-------|---------|
| Heading = front, text below = back | `## What is a cell?` followed by the answer |
| Q&A labels | `Q: …` / `A: …` (also `Question:`/`Answer:`, `Front:`/`Back:`, `**Q1:**`) |
| Inline card | `perro :: dog` |
| Glossary list | `- **Osmosis**: movement of water…` |
| Table | each row of `\| Term \| Definition \|` |
| Multi-line card | question lines, a line with only `?`, then the answer |

Notes:

- A single `# Title` at the top is treated as the document title and doesn't become a card.
- If a heading ends with `?`, its whole section is the answer.
- Q&A answers continue until the next question, heading or `---`.
- Code blocks are never parsed for cards.

## Project structure

```
Flashcards/
  App/            App entry point and SwiftData container
  Models/         StudyModule, Chapter, Flashcard, SourceFile (SwiftData) + CardStore, SampleData
  Import/         CSVParser, MarkdownParser, ColumnMapping, FlashcardImporter (pure Foundation)
  Views/
    Modules/      Module list, module detail, module editor
    Chapters/     Chapter detail, import preview, card editor, format guide
    Study/        Study session and flip card
    Components/   Markdown rendering, progress ring, shared views
FlashcardsTests/  Parser tests (Swift Testing)
SampleFiles/      Example CSV and Markdown files to import
Config/Info.plist Declares the Markdown file type for the document picker
```

The parsers in `Import/` only depend on Foundation, so they're easy to unit test and reuse.
