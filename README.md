# SATin

A local-first macOS app for SAT Reading and Writing practice.

> SATin is an independent third-party application and is not affiliated with, endorsed by, or sponsored by the College Board.
>
> SATin is solely a practice shell — it does not host, distribute, or include any copyrighted SAT questions or materials. Users must source their own questions from authorized channels (such as the official College Board question bank). Users are solely responsible for ensuring that any imported content complies with applicable copyright laws and terms of service.

## Features

- **Import Questions from PDF** — Parse structured SAT practice question sets from PDF files exported from the [College Board Question Bank](https://satsuiteeducatorquestionbank.collegeboard.org/). Review, edit, and manage crops for figure assets before saving.
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

### Getting Questions

SATin does not include any copyrighted questions. You provide your own content by exporting from the official [College Board SAT Question Bank](https://satsuiteeducatorquestionbank.collegeboard.org/).

1. Visit [satsuiteeducatorquestionbank.collegeboard.org](https://satsuiteeducatorquestionbank.collegeboard.org/)
2. Browse and select questions you want to practice with
3. Export your selection as a PDF file
4. In SATin, go to **Library → Import PDF** and select the exported file
5. Review the parsed questions and save them to your local question bank

### Practicing

1. Go to **Practice**, set filters (domain/skill/difficulty), and begin a session
2. Answer questions and submit — incorrect answers allow retry or reveal
3. After each session, view your practice score, skill breakdown, and review individual questions
4. Use **Practice Mistakes** to retry questions you got wrong

### Vocabulary

- Tap any unfamiliar word during practice to look up its definition
- Save words with notes to your vocabulary list
- Track mastery and export vocabulary in CSV, JSON, or Markdown

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

## Disclaimer & License

SATin is an independent third-party application and is **not affiliated with, endorsed by, or sponsored by the College Board**.

SATin is solely a practice shell — it does **not** host, distribute, or include any copyrighted SAT questions or materials. Users must source their own questions from authorized channels (such as the official College Board question bank). Users are solely responsible for ensuring that any imported content complies with applicable copyright laws and terms of service.

This project is for educational and personal study use only.
