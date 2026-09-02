import Foundation

@MainActor
final class JobsViewModel: ObservableObject, LoadingViewModel {

    enum Tab: Int, CaseIterable { case browse, applications, postings, post }

    @Published var tab: Tab = .browse
    @Published private(set) var jobs: [JobPosting] = []
    @Published private(set) var myJobs: [JobPosting] = []
    @Published private(set) var myApplications: [JobApplication] = []
    /// Applicants per job id, loaded on demand from the postings tab.
    @Published private(set) var applicants: [String: [JobApplicant]] = [:]
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    // Browse filters
    @Published var query = ""
    @Published var arrangement = ""
    @Published var employmentType = ""
    @Published var location = ""
    @Published var minSalary = ""

    func load() async {
        await loadJobs()
        await loadMine()
    }

    func loadJobs() async {
        await attempt {
            jobs = try await JobsService.browse(query: query,
                                                arrangement: arrangement,
                                                employmentType: employmentType,
                                                location: location,
                                                minSalary: minSalary)
        }
    }

    func loadMine() async {
        do {
            myJobs = try await JobsService.mine()
            myApplications = try await JobsService.myApplications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadApplicants(for jobId: String) async {
        do {
            applicants[jobId] = try await JobsService.applicants(for: jobId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(to job: JobPosting, coverLetter: String, resume: PickedDocument?) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await JobsService.apply(to: job.id, coverLetter: coverLetter, resume: resume)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func withdraw(_ application: JobApplication) async {
        do {
            try await JobsService.setApplicationStatus(application.id, status: "WITHDRAWN")
            await loadMine()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setStatus(_ status: String, on applicant: JobApplicant, jobId: String) async {
        do {
            try await JobsService.setApplicationStatus(applicant.id, status: status)
            await loadApplicants(for: jobId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func postJob(_ fields: [String: String]) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await JobsService.post(fields)
            await load()
            tab = .postings
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
