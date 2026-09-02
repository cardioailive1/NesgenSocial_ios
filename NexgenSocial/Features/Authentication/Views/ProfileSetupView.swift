import SwiftUI

/// Extended profile: the demographic fields, interests, and the privacy
/// consents that govern what any of it may be used for. Privacy toggles save
/// the moment they're flipped rather than waiting for a Save button — a
/// consent that needs a second confirming tap is a consent people lose track
/// of having given.
struct ProfileSetupView: View {
    @StateObject private var model = ProfileSetupViewModel()

    /// Mirrors the server's whitelist. A value it rejects comes back as a 400,
    /// so the picker offers only what will be accepted.
    private let relationshipOptions = [
        "", "SINGLE", "IN_RELATIONSHIP", "ENGAGED", "MARRIED",
        "DOMESTIC_PARTNERSHIP", "SEPARATED", "DIVORCED", "WIDOWED",
        "PREFER_NOT_TO_SAY",
    ]

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ErrorBanner(message: model.errorMessage)
                    if let statusMessage = model.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cyan400)
                    }

                    aboutYou
                    interestsSection
                    privacySection
                }
                .padding(14)
            }
        }
        .navigationTitle("Profile setup")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("About you")

            TextField("Bio", text: $model.bio, axis: .vertical)
                .lineLimit(2...5)
                .fieldStyle()
            TextField("What you do", text: $model.occupation).fieldStyle()
            TextField("Education", text: $model.education).fieldStyle()
            TextField("City", text: $model.city).fieldStyle()
            TextField("Country", text: $model.country).fieldStyle()
            TextField("Gender", text: $model.gender).fieldStyle()

            Picker("Relationship", selection: $model.relationshipStatus) {
                ForEach(relationshipOptions, id: \.self) { option in
                    Text(option.isEmpty ? "Not set" : label(for: option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(.white)

            Toggle("Add my birth date", isOn: $model.hasBirthDate)
                .foregroundStyle(.white)
            if model.hasBirthDate {
                DatePicker("Born", selection: $model.birthDate, displayedComponents: .date)
                    .foregroundStyle(.white)
            }
            Toggle("I have children", isOn: $model.hasChildren)
                .foregroundStyle(.white)

            Button(model.isSaving ? "Saving…" : "Save profile") { Task { await model.save() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan400)
                .disabled(model.isSaving)
        }
        .font(.system(size: 14))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Interests")
            Text("Used to suggest people and to target ads, but only if you allow interest targeting below.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.slate400)

            FlowChips(items: model.allInterests, isSelected: model.isSelected) { interest in
                Task { await model.toggleInterest(interest) }
            }

            if model.allInterests.isEmpty {
                Text("No interests configured on the server yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate400)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Privacy")

            privacyToggle("Interest-based ads",
                          "Ads may be matched to the interests above.",
                          get: { model.privacy.allowInterestTargeting ?? false },
                          field: "allowInterestTargeting")
            privacyToggle("Behavioral tracking",
                          "Links ad views and clicks to your account. Counts are recorded either way; this decides whether they're tied to you.",
                          get: { model.privacy.allowBehavioralTracking ?? false },
                          field: "allowBehavioralTracking")
            privacyToggle("Aggregate insights",
                          "Lets you be counted in advertisers' audience-size estimates. Never identifies you individually.",
                          get: { model.privacy.allowAggregateInsights ?? false },
                          field: "allowAggregateInsights")
            privacyToggle("Show my places",
                          "Others can see the places you've marked public.",
                          get: { model.privacy.showVisitedPlaces ?? false },
                          field: "showVisitedPlaces")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func privacyToggle(_ title: String, _ explanation: String,
                               get: @escaping () -> Bool, field: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: Binding(
                get: get,
                set: { newValue in Task { await model.savePrivacy(field, newValue) } }
            ))
            .font(.system(size: 14))
            .foregroundStyle(.white)

            Text(explanation)
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)
        }
    }

    private func label(for status: String) -> String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

}

/// Wrapping chip row. Uses SwiftUI's own `FlowLayout` equivalent via
/// `LazyVGrid` with adaptive columns, which wraps without a custom Layout.
struct FlowChips: View {
    let items: [Interest]
    let isSelected: (Interest) -> Bool
    let onTap: (Interest) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
            ForEach(items) { item in
                Button { onTap(item) } label: {
                    Text(item.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(isSelected(item) ? Theme.cyan400 : Theme.navy800)
                        .foregroundStyle(isSelected(item) ? Theme.navy950 : Theme.slate300)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
