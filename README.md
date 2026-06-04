# SATin

A local-first macOS app for SAT Reading and Writing practice.

> SATin is an independent third-party application and is not affiliated with, endorsed by, or sponsored by the College Board.

## Features

- **Import Questions from PDF** — Parse structured SAT practice question sets from PDF files. Review, edit, and manage crops for figure assets before saving.
- **Practice Sessions** — Filter questions by domain, skill, and difficulty. Timed sessions with answer submission, mistake tracking, and question marking.
- **Summary & Analytics** — Post-session breakdown including accuracy, speed score, difficulty-weighted score, skill-level analysis, and per-question review.
- **Vocabulary** — Look up unfamiliar words using the built-in offline dictionary, save them with notes and definitions, and track mastery.
- **Rationale Translation** — Translate question rationales into multiple languages (Simplified Chinese, Traditional Chinese, Spanish, Korean, Arabic, Japanese, or custom).
- **Export** — Export questions (JSON, CSV, Markdown, PDF) and vocabulary (CSV, JSON, Markdown).
- **Local-First** — All data stored on-device via SwiftData. No accounts, no cloud sync.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (for development)

## Usage

1. **Import questions** — Go to Library, click "Import PDF", and select a SAT Reading and Writing question PDF.
2. **Start practicing** — Go to Practice, set your filters (domain/skill/difficulty), and begin.
3. **Review results** — After each session, view your practice score, skill breakdown, and review individual questions.
4. **Build vocabulary** — Tap any unfamiliar word during practice to look up its definition and save it to your vocabulary list.

### Supported PDF Format

Imported PDFs should contain questions in a structured text format with the following fields per question:

- `Question ID:` — Unique identifier
- Domain/Skill/Difficulty metadata on lines containing `Reading and Writing |`
- `Correct Answer:` — A, B, C, or D
- `A.`, `B.`, `C.`, `D.` — Choice text
- `Rationale` — Explanation of the correct answer

## Tech Stack

- **Language:** Swift 6
- **Framework:** SwiftUI, SwiftData, PDFKit
- **Platform:** macOS native (AppKit integration)
- **Data:** Local on-device persistence with SwiftData

## Project Structure

```
Sources/SATin/
├── Models/            # SwiftData models and domain enums
├── Services/          # PDF parsing, scoring, dictionary, translation, export
├── ViewModels/        # Practice session state management
└── Views/             # SwiftUI views (Home, Practice, Library, Settings, etc.)
```

## Building

Open `SATin.xcodeproj` in Xcode, or build with Swift Package Manager:

```bash
swift build
```

## License

This project is for educational and personal study use. Users are responsible for the copyright compliance of any imported question content.
