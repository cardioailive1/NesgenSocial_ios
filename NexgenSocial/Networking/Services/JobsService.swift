import Foundation

/// Job board: browsing with filters, the postings you own, the applications
/// you've sent, and moving applicants through the pipeline.
enum JobsService {

    static let arrangements = [("ONSITE", "On-site"), ("HYBRID", "Hybrid"), ("REMOTE", "Remote")]
    static let employmentTypes = [("FULL_TIME", "Full time"), ("PART_TIME", "Part time"),
                                  ("CONTRACT", "Contract"), ("INTERNSHIP", "Internship"),
                                  ("TEMPORARY", "Temporary"), ("VOLUNTEER", "Volunteer")]
    static let applicationStatuses = ["SUBMITTED", "REVIEWING", "INTERVIEWING", "OFFERED", "REJECTED"]

    static func browse(query: String = "",
                       arrangement: String = "",
                       employmentType: String = "",
                       location: String = "",
                       minSalary: String = "") async throws -> [JobPosting] {
        let path = APIEndpoints.Jobs.browse([
            "q": query, "arrangement": arrangement, "employmentType": employmentType,
            "location": location, "minSalary": minSalary,
        ])
        return try await APIClient.shared.get(path, as: JobsResponse.self).jobs
    }

    static func mine() async throws -> [JobPosting] {
        try await APIClient.shared.get(APIEndpoints.Jobs.mine, as: JobsResponse.self).jobs
    }

    static func myApplications() async throws -> [JobApplication] {
        try await APIClient.shared
            .get(APIEndpoints.Jobs.myApplications, as: JobApplicationsResponse.self).applications
    }

    static func applicants(for jobId: String) async throws -> [JobApplicant] {
        try await APIClient.shared
            .get(APIEndpoints.Jobs.applicants(jobId), as: JobApplicantsResponse.self).applications
    }

    static func post(_ fields: [String: String]) async throws {
        _ = try await APIClient.shared.post(APIEndpoints.Jobs.root,
                                            body: fields.filter { !$0.value.isEmpty },
                                            as: JobResponse.self)
    }

    /// A resume is optional, so a plain JSON post covers the common case and
    /// only an attached file needs the multipart path.
    static func apply(to jobId: String, coverLetter: String, resume: PickedDocument?) async throws {
        let path = APIEndpoints.Jobs.apply(jobId)
        if let resume {
            _ = try await APIClient.shared.upload(path,
                                                  fields: ["coverLetter": coverLetter],
                                                  files: [(name: "resume",
                                                           filename: resume.filename,
                                                           mimeType: resume.mimeType,
                                                           data: resume.data)],
                                                  as: EmptyResponse.self)
        } else {
            _ = try await APIClient.shared.post(path,
                                                body: ["coverLetter": coverLetter],
                                                as: EmptyResponse.self)
        }
    }

    static func setApplicationStatus(_ applicationId: String, status: String) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Jobs.application(applicationId),
                                             body: ["status": status],
                                             as: EmptyResponse.self)
    }

    static func setJobStatus(_ jobId: String, status: String) async throws {
        _ = try await APIClient.shared.patch(APIEndpoints.Jobs.job(jobId),
                                             body: ["status": status],
                                             as: JobResponse.self)
    }
}

/// A resume picked from the Files app. Photos come through
/// `PickedAttachment`; a document needs its own type because it carries the
/// real filename and content type the server checks against.
struct PickedDocument {
    let data: Data
    let filename: String
    let mimeType: String
}
