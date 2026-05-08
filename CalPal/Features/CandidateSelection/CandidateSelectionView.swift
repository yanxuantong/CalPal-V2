import SwiftUI

struct CandidateSelectionView: View {
    let context: CandidateSelectionContext
    let onSelect: (CalendarEvent) -> Void
    var body: some View {
        NavigationStack {
            List(context.candidates) { event in
                Button { onSelect(event) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.headline)
                        Text(event.startDate.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                        Text(event.calendarName).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose event")
        }
    }
}
