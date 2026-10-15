# Flashies for iOS

A SwiftUI flashcard app. Organise your studies into **modules** (subjects), split each module into **chapters**, and import **CSV** or **Markdown** files into a chapter. The app extracts the cards from the files automatically.

## Features

- **Modules → Chapters → Flashcards.** Create, rename, colour, reorder and delete them.
- **Import CSV and Markdown files** from the Files app and its storage providers. You can pick several files at once.
- **Review before adding.** After a file is parsed you see every extracted card and can untick the ones you don't want. Cards that already exist in the chapter start unticked.
- **Imported files are tracked.** Each chapter lists the files it was built from. Deleting a file removes the cards that came from it.
- **Study mode** with 3D flip cards. Tap to flip, then swipe right (or tap *Got It*) if you knew it, or left (*Again*) if you didn't. There are options to shuffle, show the answer side first and review missed cards. On iPad, keyboard shortcuts work (space flips, ← / → grade).
- **Scheduled review** uses a Leitner box. Known cards return after 1, 3, 7, 14 and 30 days; missed cards return in 10 minutes. New cards are due immediately. A card is *mastered* after 3 correct answers in a row. You can also study chapters or modules ahead of schedule.
- **Tags and favourites** help filter the Review tab. Add them while editing cards, or toggle a favourite in a study session's Options menu.
- **Study statistics** show review counts, accuracy, current streak and a seven-day activity chart. Historical activity begins with this version; old aggregate counts are not converted into invented review events.
- **Optional daily reminders** use local notifications at your chosen time.
- **Markdown in cards**: **bold**, *italic*, `code`, lists and code blocks are rendered.
- Add and edit cards by hand. Search a chapter's cards.
- Data is stored locally on the device with SwiftData. Use chapter or module files to back up your library and move it between devices.
- Export and import whole chapters as `.flashies` files, including Markdown, card order, source-file labels and study progress.
- Export a chapter's cards as CSV for use in spreadsheets and other flashcard apps.
- Back up and restore complete modules with `.flashiesmodule` files, including chapters, tags, favourites, review schedules and history.

## Requirements

- Xcode 16 or later for local development; **Xcode 26 or later with the iOS 26 SDK for App Store Connect uploads**
- iOS 17 or later (iPhone and iPad)

## Getting started

1. Open `Flashcards.xcodeproj` in Xcode.
2. Select the **Flashcards** scheme and an iPhone simulator, then press **⌘R**.
3. On first launch, tap **Add a Sample Module** to explore, or create your own module.
4. To try importing, drag the files from [`SampleFiles/`](SampleFiles) onto the simulator (they're saved to the Files app). Then, in a chapter, tap **+ → Import CSV or Markdown**.

To run on a real device, choose your team under *Signing & Capabilities*. You may also need to change the bundle identifier (`com.amirlaj.Flashcards`).

Run the unit tests with **⌘U**.

The shared scheme also runs interface tests for module/chapter/card creation, tags and favourites, study sessions and export controls. These tests use disposable in-memory sample data. The unit suite covers legacy-library migration, notification permission decisions, review scheduling, and backup validation/restore.

For signing, screenshots, store text, privacy/support drafts, and the release validation/archive script, see [Release/README.md](Release/README.md).

## Module backups

Open a module and use **More → Export Module** to save a `.flashiesmodule` file. Restore it with **Library → + → Import Module**. Review the chapter list, choose a module name, and decide whether to keep study progress. A restore creates a copy with a distinct name, preserving the existing library. Tags and favourites are retained even when study progress is reset.

## Moving chapters between devices

1. Open a chapter and tap the **Export** icon (square with an upward arrow).
2. Choose **Export Chapter** and save the `.flashies` file in Files. You can share the saved file using the Files app.
3. In Flashies on the receiving device, open the destination module and choose **+ → Import Chapter**.
4. Pick the `.flashies` file, review the cards, optionally rename the chapter, and choose whether to **Keep Study Progress**. Tap **Import**.

Import always creates a new chapter. Matching names receive an “Imported” suffix; existing chapters are never overwritten. Empty chapters are supported too. The chapter file contains card text and source-file labels, not the original CSV/Markdown documents.

For other tools, choose **Export Cards as CSV**. CSV contains the front and back text only, without progress or chapter metadata. To bring CSV or Markdown cards into Flashies, open a chapter and use **+ → Import CSV or Markdown**.

The installed app is named **Flashies**. The Xcode project, scheme and bundle identifier retain their existing names so the app continues using its existing stored data.

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
