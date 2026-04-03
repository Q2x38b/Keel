import SwiftUI

struct LessonColorPicker: View {
    @Binding var selectedColor: LessonColor
    let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(LessonColor.allCases) { color in
                    ColorOption(
                        color: color,
                        isSelected: selectedColor == color
                    )
                    .onTapGesture {
                        if selectedColor != color {
                            HapticManager.shared.selectionConfirm()
                        }
                        withAnimation(.spring(response: 0.3)) {
                            selectedColor = color
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Color Option
struct ColorOption: View {
    let color: LessonColor
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: 44, height: 44)

            if isSelected {
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(color.color, lineWidth: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 50, height: 50)
    }
}

// MARK: - Inline Color Picker (for compact forms)
struct InlineColorPicker: View {
    @Binding var selectedColor: LessonColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LessonColor.allCases) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                        )
                        .overlay(
                            selectedColor == color ?
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                : nil
                        )
                        .onTapGesture {
                            if selectedColor != color {
                                HapticManager.shared.selectionConfirm()
                            }
                            withAnimation(.spring(response: 0.3)) {
                                selectedColor = color
                            }
                        }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 32) {
        LessonColorPicker(selectedColor: .constant(.blue))
            .padding()

        Divider()

        InlineColorPicker(selectedColor: .constant(.green))
            .padding()
    }
    .background(Color(.systemBackground))
}
