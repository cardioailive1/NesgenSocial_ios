import SwiftUI

struct AudiencePlannerView: View {
    @StateObject private var model = AudiencePlannerViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Who should see it")
                        HStack(spacing: 8) {
                            TextField("Min age", text: $model.minAge).keyboardType(.numberPad).fieldStyle()
                            TextField("Max age", text: $model.maxAge).keyboardType(.numberPad).fieldStyle()
                        }
                        TextField("City", text: $model.city).fieldStyle()
                        TextField("Country", text: $model.country).fieldStyle()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Interests")
                        FlowChips(items: model.allInterests, isSelected: model.isSelected) { interest in
                            model.toggleInterest(interest)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    Button("Estimate reach") { Task { await model.runEstimate() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan400)

                    if let estimate = model.estimate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(estimate.estimatedReach.map { "\($0.formatted()) people" } ?? "Withheld")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(estimate.suppressed ? Theme.slate400 : Theme.cyan400)
                            if let note = estimate.note {
                                Text(note)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.slate400)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Audience")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }
}
