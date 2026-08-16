import Fluent
import Vapor

/// Receives enquiries from people who are not customers yet.
///
/// The only unauthenticated write endpoint in the service, which makes it the
/// only one a stranger can abuse. Three cheap defences, in preference to a
/// captcha that would tax every honest restaurateur on a poor connection:
///
///  1. A honeypot field no human sees. Filled in means a script.
///  2. A minimum fill time. A form submitted in under two seconds was not read.
///  3. A per-address cap, so one enquiry cannot become two hundred.
///
/// None of these is strong on its own. Together they stop the volume that
/// actually shows up, and none of them punish the person we want to hear from.
struct EnquiryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("enquiries", use: submit)
    }

    func submit(req: Request) async throws -> EnquiryReceipt {
        let input = try req.content.decode(EnquiryRequest.self)

        // 1. Honeypot. Named plausibly so a script fills it in; hidden and
        //    aria-hidden in the markup so no person or screen reader meets it.
        if let trap = input.website, !trap.isEmpty {
            // Answer as if accepted. Telling a bot it was caught only teaches
            // whoever wrote it which field to leave alone next time.
            req.logger.info("Enquiry rejected: honeypot filled.")
            return EnquiryReceipt(received: true)
        }

        // 2. Time on form.
        if let elapsed = input.elapsedMilliseconds, elapsed < 2_000 {
            req.logger.info("Enquiry rejected: submitted in \(elapsed)ms.")
            return EnquiryReceipt(received: true)
        }

        try input.validate()

        // 3. Volume per address.
        let normalized = User.normalize(email: input.email)
        let recent = try await Enquiry.query(on: req.db)
            .filter(\.$email == normalized)
            .count()
        guard recent < 5 else {
            throw Abort(
                .tooManyRequests,
                reason: "Abbiamo già diverse richieste da questo indirizzo. Rispondiamo a quelle."
            )
        }

        let enquiry = Enquiry(
            kind: input.kind,
            name: input.name,
            email: input.email,
            organizationName: input.organizationName,
            phone: input.phone,
            message: input.message,
            sourcePath: input.sourcePath
        )
        try await enquiry.save(on: req.db)

        req.logger.notice("Enquiry received: \(input.kind.rawValue).")
        return EnquiryReceipt(received: true)
    }
}

struct EnquiryRequest: Content {
    let kind: EnquiryKind
    let name: String
    let email: String
    let organizationName: String?
    let phone: String?
    let message: String?
    let sourcePath: String?

    /// Honeypot. A real person never sees this field.
    let website: String?
    /// Milliseconds between the form appearing and being sent.
    let elapsedMilliseconds: Int?

    func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= 2, trimmedName.count <= 120 else {
            throw Abort(.badRequest, reason: "Il nome non è valido.")
        }
        // Deliberately loose. Strict email regexes reject valid addresses, and
        // the address is verified by the reply arriving, not by a pattern.
        guard email.contains("@"), email.count >= 5, email.count <= 254 else {
            throw Abort(.badRequest, reason: "Indirizzo email non valido.")
        }
        if let message, message.count > 4_000 {
            throw Abort(.badRequest, reason: "Il messaggio è troppo lungo.")
        }
    }
}

/// Says only that it arrived.
///
/// No identifier comes back: an enquiry reference would let anybody probe for
/// other people's submissions, and the person sending it has no use for one.
struct EnquiryReceipt: Content {
    let received: Bool
}
