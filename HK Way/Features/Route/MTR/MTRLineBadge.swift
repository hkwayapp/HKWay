import SwiftUI

struct MTRLineBadge: View {
    let line: MTRLine

    var body: some View {
        Text(LocalizedStringKey(line.title))
            .font(.headline.bold())
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(line.color, in: RoundedRectangle(cornerRadius: 22))
    }

    private var textColor: Color {
        ["SIL", "TCL", "DRL", "EAL"].contains(line.id) ? .black : .white
    }
}
