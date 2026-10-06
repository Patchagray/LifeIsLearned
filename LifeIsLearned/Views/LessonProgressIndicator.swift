import SwiftUI

struct LessonProgressIndicator: View {
    let lesson: Lesson
    let index: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if lesson.usesSixStageProgress {
                VStack(alignment: .leading, spacing: 6) {
                    // Give large text one full-width current-stage label; retain the
                    // weighted track and complete physical VoiceOver description.
                    if typeSize >= .xxLarge {
                        Text(SixStageLesson.accessibilityLabels[index]).font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    GeometryReader { geometry in
                        HStack(alignment: .bottom, spacing: 5) {
                            ForEach(0..<5) { stage in
                                let width = max(0, geometry.size.width - 20) * CGFloat(SixStageLesson.pageRanges[stage].count) / 6
                                VStack(spacing: 6) {
                                    if typeSize < .xxLarge {
                                        Text(SixStageLesson.labels[stage]).font(.system(size: 10, weight: .medium))
                                            .lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    Capsule().fill(Palette.rule)
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Palette.teal)
                                                .frame(width: width * SixStageLesson.fill(stage: stage, page: index))
                                        }.frame(height: 3)
                                }.frame(width: width)
                            }
                        }
                    }.frame(height: typeSize >= .xxLarge ? 3 : 23)
                }.foregroundStyle(Palette.secondary)
            } else {
                HStack(spacing: 5) {
                    ForEach(lesson.pages.indices, id: \.self) { page in
                        Capsule().fill(page <= index ? Palette.teal : Palette.rule).frame(height: 3)
                    }
                }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(lesson.progressDescription(at: index))
            .accessibilityIdentifier(lesson.usesSixStageProgress ? "semantic-lesson-progress" : "legacy-lesson-progress")
    }
}
