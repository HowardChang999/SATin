import SwiftUI
import SwiftData

struct ImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var existingQuestions: [Question]

    @Binding var drafts: [ParsedQuestionDraft]
    let sourcePdfName: String
    let onClose: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var duplicatePolicy: DuplicatePolicy = .skip
    @State private var saveMessage: String = ""
    @State private var previewAssetPath: String = ""
    @State private var pagePreview: NSImage?

    private let pdfService = PDFImportService()

    enum DuplicatePolicy: String, CaseIterable, Identifiable {
        case skip = "Skip"
        case replace = "Replace"
        case keepBoth = "Keep Both"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Label("Import Review", systemImage: "doc.badge.plus")
                        .font(.title2.weight(.semibold))
                    Text(sourcePdfName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Duplicate", selection: $duplicatePolicy) {
                    ForEach(DuplicatePolicy.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 220)
            }
            .padding(12)
            .satinPanel()

            HStack(spacing: 12) {
                draftList
                if drafts.indices.contains(selectedIndex) {
                    DraftEditorCard(
                        draft: $drafts[selectedIndex],
                        pagePreview: pagePreview,
                        onGenerateFigure: { generateFigureForSelected() },
                        previewAssetPath: previewAssetPath,
                        canGenerateFigure: pagePreview != nil
                    )
                } else {
                    Text("No parsed questions")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            HStack {
                if !saveMessage.isEmpty {
                    Label(saveMessage, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { onClose() }
                Button { saveAll() } label: {
                    Label("Save Imported Questions", systemImage: "tray.and.arrow.down")
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(drafts.isEmpty)
            }
            .padding(12)
            .satinPanel()
        }
        .padding(16)
        .frame(minWidth: 1280, minHeight: 760)
        .onAppear { loadPagePreview() }
        .onChange(of: selectedIndex) { _, _ in loadPagePreview() }
    }

    private var draftList: some View {
        List(selection: $selectedIndex) {
            ForEach(Array(drafts.enumerated()), id: \.offset) { idx, draft in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.questionId.isEmpty ? "(Missing ID)" : draft.questionId)
                            .font(.headline)
                        Text("p.\(draft.sourcePageRange.lowerBound)-\(draft.sourcePageRange.upperBound)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if hasMissingRequired(draft) {
                        Text("Missing fields")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .tag(idx)
            }
        }
        .frame(width: 320)
        .listStyle(.sidebar)
        .satinCard()
    }

    private func loadPagePreview() {
        guard drafts.indices.contains(selectedIndex) else {
            pagePreview = nil
            return
        }
        let d = drafts[selectedIndex]
        pagePreview = pdfService.pagePreviewImage(pdfPath: d.sourcePdfPath, page1Based: d.sourcePageRange.lowerBound)
        if let latestAsset = d.figureAssets.last {
            previewAssetPath = pdfService.figureAbsolutePath(fileName: latestAsset.fileName)
        } else {
            previewAssetPath = ""
        }
        if pagePreview == nil && !d.sourcePdfPath.isEmpty {
            saveMessage = "Page preview unavailable for page \(d.sourcePageRange.lowerBound)."
        }
    }

    private func hasMissingRequired(_ d: ParsedQuestionDraft) -> Bool {
        d.questionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        d.choices.a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        d.choices.b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        d.choices.c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        d.choices.d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !["A", "B", "C", "D"].contains(d.correctAnswer.uppercased()) ||
        d.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generateFigureForSelected() {
        guard drafts.indices.contains(selectedIndex) else { return }
        var draft = drafts[selectedIndex]

        guard !draft.sourcePdfPath.isEmpty else {
            saveMessage = "Figure generation failed: missing PDF path."
            return
        }

        guard pagePreview != nil else {
            saveMessage = "Figure generation unavailable: page preview could not be loaded."
            return
        }

        if let asset = pdfService.generateFigureAsset(
            pdfPath: draft.sourcePdfPath,
            page1Based: draft.sourcePageRange.lowerBound,
            cropRect: draft.cropRect,
            questionId: draft.questionId.isEmpty ? "question" : draft.questionId
        ) {
            if !draft.figureAssets.contains(where: { $0.fileName == asset.fileName }) {
                draft.figureAssets.append(asset)
            }
            drafts[selectedIndex] = draft
            previewAssetPath = pdfService.figureAbsolutePath(fileName: asset.fileName)
            saveMessage = "Generated figure for \(draft.questionId.isEmpty ? "selected draft" : draft.questionId)."
        } else {
            saveMessage = "Figure generation failed. Check that the PDF path and page number are valid."
        }
    }

    private func saveAll() {
        let existingById = Dictionary(uniqueKeysWithValues: existingQuestions.map { ($0.questionId, $0) })
        var inserted = 0
        var skipped = 0
        var replaced = 0

        for draft in drafts {
            if hasMissingRequired(draft) {
                skipped += 1
                continue
            }

            let normalizedId = draft.questionId.trimmingCharacters(in: .whitespacesAndNewlines)
            let duplicate = existingById[normalizedId]

            if duplicate != nil {
                switch duplicatePolicy {
                case .skip:
                    skipped += 1
                    continue
                case .replace:
                    if let duplicate {
                        modelContext.delete(duplicate)
                        replaced += 1
                    }
                case .keepBoth:
                    break
                }
            }

            let finalId: String
            if duplicate != nil && duplicatePolicy == .keepBoth {
                finalId = "\(normalizedId)_\(UUID().uuidString.prefix(6))"
            } else {
                finalId = normalizedId
            }

            let question = Question(
                questionId: finalId,
                assessment: draft.assessment,
                test: draft.test,
                domain: draft.domain,
                skill: draft.skill,
                difficulty: draft.difficulty,
                questionText: draft.questionText,
                prompt: draft.prompt,
                choices: draft.choices,
                correctAnswer: draft.correctAnswer.uppercased(),
                rationale: draft.rationale,
                figureAssets: draft.figureAssets,
                sourcePdfName: draft.sourcePdfName,
                sourcePageRangeStart: draft.sourcePageRange.lowerBound,
                sourcePageRangeEnd: draft.sourcePageRange.upperBound,
                createdAt: .now
            )
            modelContext.insert(question)
            inserted += 1
        }

        modelContext.insert(ImportBatch(sourcePdfName: sourcePdfName, questionCount: inserted))
        do {
            try modelContext.save()
            saveMessage = "Imported \(inserted), replaced \(replaced), skipped \(skipped)."
        } catch {
            saveMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

private struct DraftEditorCard: View {
    @Binding var draft: ParsedQuestionDraft
    let pagePreview: NSImage?
    let onGenerateFigure: () -> Void
    let previewAssetPath: String
    let canGenerateFigure: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                requiredField("Question ID", text: $draft.questionId)

                HStack {
                    Picker("Domain", selection: $draft.domain) {
                        ForEach(Domain.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Skill", selection: $draft.skill) {
                        ForEach(Skill.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Difficulty", selection: $draft.difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Text("Question Text").font(.headline)
                TextEditor(text: $draft.questionText)
                    .frame(minHeight: 110)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                Text("Prompt").font(.headline)
                TextEditor(text: $draft.prompt)
                    .frame(minHeight: 90)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                requiredField("Choice A", text: $draft.choices.a)
                requiredField("Choice B", text: $draft.choices.b)
                requiredField("Choice C", text: $draft.choices.c)
                requiredField("Choice D", text: $draft.choices.d)

                HStack {
                    Text("Correct Answer")
                    Spacer()
                    Picker("", selection: $draft.correctAnswer) {
                        Text("A").tag("A")
                        Text("B").tag("B")
                        Text("C").tag("C")
                        Text("D").tag("D")
                    }
                    .frame(width: 120)
                }

                Text("Rationale").font(.headline)
                TextEditor(text: $draft.rationale)
                    .frame(minHeight: 110)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(draft.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.gray.opacity(0.3), lineWidth: 1))

                Divider().padding(.vertical, 4)

                Text("Figure Crop").font(.headline)
                if let pagePreview {
                    CropSelectionView(image: pagePreview, normalizedRect: $draft.cropRect)
                        .frame(height: 360)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ContentUnavailableView(
                        "No Page Preview",
                        systemImage: "doc.viewfinder",
                        description: Text("The source PDF page could not be loaded for this draft.")
                    )
                    .frame(height: 180)
                }

                HStack {
                    Button("Reset to Full Page") { draft.cropRect = .full }
                    Button("Generate / Refresh Figure") { onGenerateFigure() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canGenerateFigure)
                    Text("Assets: \(draft.figureAssets.count)")
                        .foregroundStyle(.secondary)
                }

                if !previewAssetPath.isEmpty {
                    Image(nsImage: NSImage(contentsOfFile: previewAssetPath) ?? NSImage())
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .background(Color.black.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .satinCard()
    }

    private func requiredField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.red : Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
}

private struct CropSelectionView: View {
    let image: NSImage
    @Binding var normalizedRect: NormalizedRect

    private enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    private enum DragMode {
        case drawing(start: CGPoint, current: CGPoint)
        case moving(start: CGPoint, original: CGRect)
        case resizing(handle: Handle, start: CGPoint, original: CGRect)
    }

    @State private var dragMode: DragMode?

    private let handleSize: CGFloat = 14
    private let minSelectionSize: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let imageSize = image.size
            let drawRect = fittedRect(container: geo.size, imageSize: imageSize)
            let selectionRect = rectFromNormalized(normalizedRect, in: drawRect)

            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .background(Rectangle().fill(Color.yellow.opacity(0.15)))
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(x: selectionRect.midX, y: selectionRect.midY)

                ForEach(Handle.allCases, id: \.self) { handle in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                        .frame(width: handleSize, height: handleSize)
                        .position(handlePoint(handle, in: selectionRect))
                }

                if case .drawing(let start, let current) = dragMode {
                    let live = drawingRect(from: start, to: current, in: drawRect)
                    Rectangle()
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .frame(width: live.width, height: live.height)
                        .position(x: live.midX, y: live.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let p = clamp(point: value.location, to: drawRect)
                        if dragMode == nil {
                            dragMode = mode(startingAt: p, selectionRect: selectionRect)
                        }
                        updateSelection(to: p, in: drawRect)
                    }
                    .onEnded { _ in
                        dragMode = nil
                    }
            )
        }
    }

    private func mode(startingAt point: CGPoint, selectionRect: CGRect) -> DragMode {
        if let handle = hitHandle(at: point, in: selectionRect) {
            return .resizing(handle: handle, start: point, original: selectionRect)
        }
        if selectionRect.contains(point) {
            return .moving(start: point, original: selectionRect)
        }
        return .drawing(start: point, current: point)
    }

    private func updateSelection(to point: CGPoint, in drawRect: CGRect) {
        guard let dragMode else { return }

        let updatedRect: CGRect
        switch dragMode {
        case .drawing(let start, _):
            self.dragMode = .drawing(start: start, current: point)
            updatedRect = drawingRect(from: start, to: point, in: drawRect)
        case .moving(let start, let original):
            let offset = CGSize(width: point.x - start.x, height: point.y - start.y)
            updatedRect = clampedMove(original.offsetBy(dx: offset.width, dy: offset.height), in: drawRect)
        case .resizing(let handle, let start, let original):
            let offset = CGSize(width: point.x - start.x, height: point.y - start.y)
            updatedRect = clampedResize(original, handle: handle, offset: offset, in: drawRect)
        }

        normalizedRect = normalizedFromRect(updatedRect, in: drawRect)
    }

    private func fittedRect(container: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func rectFromNormalized(_ n: NormalizedRect, in drawRect: CGRect) -> CGRect {
        let rect = CGRect(
            x: drawRect.minX + CGFloat(n.x) * drawRect.width,
            y: drawRect.minY + CGFloat(n.y) * drawRect.height,
            width: CGFloat(n.width) * drawRect.width,
            height: CGFloat(n.height) * drawRect.height
        )
        return clampedMove(rect, in: drawRect)
    }

    private func normalizedFromRect(_ rect: CGRect, in drawRect: CGRect) -> NormalizedRect {
        guard drawRect.width > 0, drawRect.height > 0 else { return .full }
        let clamped = clampedMove(rect, in: drawRect)
        let x = max(0, min(1, (clamped.minX - drawRect.minX) / drawRect.width))
        let y = max(0, min(1, (clamped.minY - drawRect.minY) / drawRect.height))
        let w = max(0.01, min(1 - x, clamped.width / drawRect.width))
        let h = max(0.01, min(1 - y, clamped.height / drawRect.height))
        return NormalizedRect(x: x, y: y, width: w, height: h)
    }

    private func drawingRect(from start: CGPoint, to end: CGPoint, in drawRect: CGRect) -> CGRect {
        let raw = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        return clampedMove(raw, in: drawRect)
    }

    private func clampedMove(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        let width = min(max(rect.width, minSelectionSize), bounds.width)
        let height = min(max(rect.height, minSelectionSize), bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func clampedResize(_ rect: CGRect, handle: Handle, offset: CGSize, in bounds: CGRect) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .topLeft:
            minX += offset.width
            minY += offset.height
        case .top:
            minY += offset.height
        case .topRight:
            maxX += offset.width
            minY += offset.height
        case .right:
            maxX += offset.width
        case .bottomRight:
            maxX += offset.width
            maxY += offset.height
        case .bottom:
            maxY += offset.height
        case .bottomLeft:
            minX += offset.width
            maxY += offset.height
        case .left:
            minX += offset.width
        }

        minX = min(max(minX, bounds.minX), bounds.maxX - minSelectionSize)
        maxX = max(min(maxX, bounds.maxX), bounds.minX + minSelectionSize)
        minY = min(max(minY, bounds.minY), bounds.maxY - minSelectionSize)
        maxY = max(min(maxY, bounds.maxY), bounds.minY + minSelectionSize)

        if maxX - minX < minSelectionSize {
            switch handle {
            case .topLeft, .bottomLeft, .left:
                minX = max(bounds.minX, maxX - minSelectionSize)
            default:
                maxX = min(bounds.maxX, minX + minSelectionSize)
            }
        }

        if maxY - minY < minSelectionSize {
            switch handle {
            case .topLeft, .top, .topRight:
                minY = max(bounds.minY, maxY - minSelectionSize)
            default:
                maxY = min(bounds.maxY, minY + minSelectionSize)
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func clamp(point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func handlePoint(_ handle: Handle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    private func hitHandle(at point: CGPoint, in rect: CGRect) -> Handle? {
        Handle.allCases.first { handle in
            let center = handlePoint(handle, in: rect)
            let hitRect = CGRect(
                x: center.x - handleSize,
                y: center.y - handleSize,
                width: handleSize * 2,
                height: handleSize * 2
            )
            return hitRect.contains(point)
        }
    }
}
