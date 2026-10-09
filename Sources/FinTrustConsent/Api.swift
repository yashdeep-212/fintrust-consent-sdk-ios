import Foundation

public enum ConsentApiError: Error, CustomStringConvertible {
    case server(status: Int, message: String)
    case network(underlying: Error)
    case decoding

    public var description: String {
        switch self {
        case .server(let status, let message):
            return "Server error (\(status)): \(message)"
        case .network:
            return "Could not reach the consent server. Check apiBaseUrl / connectivity."
        case .decoding:
            return "Unexpected response from consent server."
        }
    }
}


internal enum ConsentApi {

    private static func request(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> Any? {
        let base = try ConsentConfig.shared.require().normalizedApiBaseUrl
        guard let url = URL(string: base + path) else {
            throw ConsentApiError.decoding
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ConsentApiError.network(underlying: error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json: Any? = try? JSONSerialization.jsonObject(with: data)

        if !(200...299).contains(status) {
            let message = (json as? [String: Any])?["message"] as? String
            throw ConsentApiError.server(status: status, message: message?.isEmpty == false ? message! : "Request failed (\(status))")
        }

        
        if let obj = json as? [String: Any], let inner = obj["data"] {
            return inner
        }
        return json
    }

    static func fetchCookies(organizationId: String) async throws -> [ConsentCookie] {
        let raw = try await request(path: "/api/cookies/organization/\(organizationId)")
        guard let array = raw as? [[String: Any]] else { return [] }
        return array.map { ConsentCookie.fromJson($0) }
    }

    @discardableResult
    static func submitConsent(payload: [String: Any]) async throws -> Any? {
        try await request(path: "/api/consents", method: "POST", body: payload)
    }

    @discardableResult
    static func identify(uniqueConsentId: String?, email: String?, deviceId: String?, phone: String? = nil, age: Int? = nil) async throws -> Any? {
       
        var body: [String: Any] = [:]
        body["email"] = email ?? NSNull()
        body["uniqueConsentId"] = uniqueConsentId ?? NSNull()
        body["deviceId"] = deviceId ?? NSNull()
        body["phone"] = phone ?? NSNull()
        body["age"] = age ?? NSNull()
        return try await request(path: "/api/consents/identify", method: "POST", body: body)
    }
}