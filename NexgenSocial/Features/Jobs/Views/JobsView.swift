import SwiftUI
import UniformTypeIdentifiers

/// The job board, mirroring the web page: Browse with filters, the
/// applications you've sent, the postings you own with their applicants, and
/// the form to post a role.
struct JobsView: View {
    @StateObject private var model = JobsViewModel()

    var body: some View {
        ZStack {
            Theme.navy950.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Find work, or hire. Never pay to apply for a job — any request for money or bank details is a fraud signal.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate400)

                    Picker("Section", selection: $model.tab) {
                        Text("Browse").tag(JobsViewModel.Tab.browse)
                        Text("Applications (\(model.myApplications.count))").tag(JobsViewModel.Tab.applications)
                        Text("Postings (\(model.myJobs.count))").tag(JobsViewModel.Tab.postings)
                        Text("Post").tag(JobsViewModel.Tab.post)
                    }
                    .pickerStyle(.segmented)

                    ErrorBanner(message: model.errorMessage)

                    switch model.tab {
                    case .browse:       browseTab
                    case .applications: applicationsTab
                    case .postings:     postingsTab
                    case .post:         PostJobForm(model: model)
                    }
                }
                .padding(14)
            }
            .pullToRefresh { await model.load() }
        }
        .navigationTitle("Jobs")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.cyan400)
        .task { await model.load() }
    }

    // MARK: - Browse

    private var browseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                TextField("Search title, company, or keywords…", text: $model.query)
                    .fieldStyle()
                HStack(spacing: 8) {
                    Picker("Arrangement", selection: $model.arrangement) {
                        Text("Any arrangement").tag("")
                        ForEach(JobsService.arrangements, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Type", selection: $model.employmentType) {
                        Text("Any type").tag("")
                        ForEach(JobsService.employmentTypes, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.cyan300)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("Location", text: $model.location).fieldStyle()
                    TextField("Min salary", text: $model.minSalary)
                        .keyboardType(.numberPad)
                        .fieldStyle()
                }
            }
            .padding(12)
            .card()
            // One reload per filter change, whichever control moved.
            .onChange(of: filterSignature) { _, _ in Task { await model.loadJobs() } }

            if model.jobs.isEmpty {
                emptyCard("No jobs match. Try widening your filters.")
            }
            ForEach(model.jobs) { job in
                JobCard(job: job, model: model)
            }
        }
    }

    private var filterSignature: String {
        [model.query, model.arrangement, model.employmentType, model.location, model.minSalary]
            .joined(separator: "|")
    }

    // MARK: - My applications

    private var applicationsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.myApplications.isEmpty {
                emptyCard("You haven't applied to anything yet.")
            }
            ForEach(model.myApplications) { application in
                VStack(alignment: .leading, spacing: 6) {
                    Text(application.job?.title ?? "Job")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(application.job?.companyName ?? "—") · \(application.job?.location ?? "—")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                    HStack {
                        Text(application.status)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.cyan300)
                        Spacer()
                        if !["WITHDRAWN", "REJECTED"].contains(application.status) {
                            Button("Withdraw") { Task { await model.withdraw(application) } }
                                .font(.system(size: 12))
                                .tint(Theme.danger)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .card()
            }
        }
    }

    // MARK: - My postings

    private var postingsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.myJobs.isEmpty {
                emptyCard("You haven't posted any jobs yet.")
            }
            ForEach(model.myJobs) { job in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(job.applicationCount ?? 0) applicant\((job.applicationCount ?? 0) == 1 ? "" : "s") · \(job.status ?? "OPEN")")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.slate400)
                        }
                        Spacer(minLength: 0)
                        Button("View applicants") { Task { await model.loadApplicants(for: job.id) } }
                            .font(.system(size: 12))
                            .buttonStyle(GhostButtonStyle())
                    }

                    if let applicants = model.applicants[job.id] {
                        if applicants.isEmpty {
                            Text("No applicants yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.slate400)
                        }
                        ForEach(applicants) { applicant in
                            ApplicantRow(applicant: applicant, jobId: job.id, model: model)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .card()
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.slate400)
            .frame(maxWidth: .infinity)
            .padding(24)
            .card()
    }
}

// MARK: - Job card

struct JobCard: View {
    let job: JobPosting
    @ObservedObject var model: JobsViewModel

    @State private var expanded = false
    @State private var applying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                if let logo = job.companyLogoUrl {
                    RetryingImage(url: APIClient.mediaURL(logo))
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(job.companyName)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.slate300)
                    Text(metaLine)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.slate400)
                    if let salary = job.salaryText {
                        Text(salary)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.cyan300)
                    } else {
                        Text("Salary not disclosed")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.slate400)
                    }
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let description = job.description { detail(nil, description) }
                    if let responsibilities = job.responsibilities, !responsibilities.isEmpty {
                        detail("Responsibilities", responsibilities)
                    }
                    if let requirements = job.requirements, !requirements.isEmpty {
                        detail("Requirements", requirements)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(expanded ? "Show less" : "View details") { expanded.toggle() }
                    .font(.system(size: 12))
                    .tint(Theme.cyan300)

                if job.isOwner == true {
                    Text("YOUR POSTING")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.slate400)
                } else if job.appliedByViewer == true {
                    Text("Applied ✓")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.cyan300)
                } else if let applyUrl = job.applyUrl, let url = URL(string: applyUrl) {
                    Link("Apply on company site ↗", destination: url)
                        .font(.system(size: 12, weight: .semibold))
                        .tint(Theme.cyan300)
                } else {
                    Button("Apply") { applying = true }
                        .font(.system(size: 12))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan400)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
        .sheet(isPresented: $applying) {
            ApplyView(job: job, model: model)
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let location = job.location, !location.isEmpty { parts.append(location) }
        if let label = JobsService.arrangements.first(where: { $0.0 == job.arrangement })?.1 {
            parts.append(label)
        }
        if let label = JobsService.employmentTypes.first(where: { $0.0 == job.employmentType })?.1 {
            parts.append(label)
        }
        return parts.joined(separator: " · ")
    }

    private func detail(_ title: String?, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.slate400)
                    .textCase(.uppercase)
            }
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(Theme.slate300)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Apply

struct ApplyView: View {
    let job: JobPosting
    @ObservedObject var model: JobsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var coverLetter = ""
    @State private var resume: PickedDocument?
    @State private var pickingResume = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text(job.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    TextField("Cover letter — why you're a fit", text: $coverLetter, axis: .vertical)
                        .lineLimit(4...10)
                        .fieldStyle()

                    Button {
                        pickingResume = true
                    } label: {
                        Label(resume?.filename ?? "Attach resume (PDF or Word)",
                              systemImage: "doc.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cyan300)
                    }

                    if let localError {
                        Text(localError)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.danger)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            if await model.apply(to: job, coverLetter: coverLetter, resume: resume) {
                                dismiss()
                            }
                        }
                    }
                    .tint(Theme.cyan400)
                    .disabled(model.isWorking)
                }
            }
            .fileImporter(isPresented: $pickingResume,
                          allowedContentTypes: [.pdf, UTType("com.microsoft.word.doc") ?? .pdf,
                                                UTType("org.openxmlformats.wordprocessingml.document") ?? .pdf]) { result in
                switch result {
                case .success(let url):
                    // A security-scoped URL has to be opened before reading:
                    // the file lives outside the app's container.
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else {
                        localError = "That file couldn't be read."
                        return
                    }
                    resume = PickedDocument(data: data,
                                            filename: url.lastPathComponent,
                                            mimeType: Self.mimeType(for: url))
                    localError = nil
                case .failure(let error):
                    localError = error.localizedDescription
                }
            }
        }
    }

    /// The server rejects anything that isn't a PDF or Word document by MIME
    /// type, so the extension has to be mapped rather than guessed.
    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:     return "application/pdf"
        }
    }
}

// MARK: - Applicant row (employer side)

struct ApplicantRow: View {
    let applicant: JobApplicant
    let jobId: String
    @ObservedObject var model: JobsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(applicant.applicant.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("@\(applicant.applicant.username)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.slate400)
                    if let occupation = applicant.applicant.occupation, !occupation.isEmpty {
                        Text(occupation)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.slate400)
                    }
                }
                Spacer(minLength: 0)
                Menu(applicant.status) {
                    ForEach(JobsService.applicationStatuses, id: \.self) { status in
                        Button(status) {
                            Task { await model.setStatus(status, on: applicant, jobId: jobId) }
                        }
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .tint(Theme.cyan300)
            }

            if let coverLetter = applicant.coverLetter, !coverLetter.isEmpty {
                Text(coverLetter)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate300)
            }
            if let url = APIClient.mediaURL(applicant.resumeUrl) {
                Link("Download resume ↗", destination: url)
                    .font(.system(size: 12))
                    .tint(Theme.cyan300)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.navy950)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Post a job

struct PostJobForm: View {
    @ObservedObject var model: JobsViewModel

    @State private var title = ""
    @State private var companyName = ""
    @State private var description = ""
    @State private var responsibilities = ""
    @State private var requirements = ""
    @State private var location = ""
    @State private var arrangement = "ONSITE"
    @State private var employmentType = "FULL_TIME"
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var salaryPeriod = "YEAR"
    @State private var applyUrl = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Job title", text: $title).fieldStyle()
            TextField("Company name", text: $companyName).fieldStyle()
            TextField("Job description", text: $description, axis: .vertical)
                .lineLimit(4...10).fieldStyle()
            TextField("Responsibilities (optional)", text: $responsibilities, axis: .vertical)
                .lineLimit(3...8).fieldStyle()
            TextField("Requirements (optional)", text: $requirements, axis: .vertical)
                .lineLimit(3...8).fieldStyle()
            TextField("Location", text: $location).fieldStyle()

            HStack(spacing: 8) {
                Picker("Arrangement", selection: $arrangement) {
                    ForEach(JobsService.arrangements, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Type", selection: $employmentType) {
                    ForEach(JobsService.employmentTypes, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.cyan300)

            Text("Salary range")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.slate400)
                .textCase(.uppercase)
            HStack(spacing: 8) {
                TextField("Min", text: $salaryMin).keyboardType(.numberPad).fieldStyle()
                TextField("Max", text: $salaryMax).keyboardType(.numberPad).fieldStyle()
                Picker("Period", selection: $salaryPeriod) {
                    Text("per year").tag("YEAR")
                    Text("per month").tag("MONTH")
                    Text("per hour").tag("HOUR")
                }
                .pickerStyle(.menu)
                .tint(Theme.cyan300)
            }
            Text("Several jurisdictions — including California, Colorado, New York and Washington — legally require a good-faith salary range in job postings, and comparable rules apply in the EU. Check what applies where this role is located.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)

            TextField("External application URL (optional)", text: $applyUrl).fieldStyle()

            Text("By posting you confirm this is a genuine, currently available role, that it does not discriminate on any legally protected characteristic, and that you will handle applicant data lawfully.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.slate400)

            Button(model.isWorking ? "Posting…" : "Post job") {
                Task {
                    if await model.postJob([
                        "title": title, "companyName": companyName, "description": description,
                        "responsibilities": responsibilities, "requirements": requirements,
                        "location": location, "arrangement": arrangement,
                        "employmentType": employmentType, "salaryMin": salaryMin,
                        "salaryMax": salaryMax, "salaryPeriod": salaryPeriod,
                        "salaryCurrency": "USD", "applyUrl": applyUrl,
                    ]) {
                        title = ""; description = ""; responsibilities = ""
                        requirements = ""; salaryMin = ""; salaryMax = ""
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isWorking || title.isEmpty || companyName.isEmpty || description.isEmpty)
        }
        .tint(Theme.cyan400)
        .foregroundStyle(.white)
        .padding(14)
        .card()
    }
}
