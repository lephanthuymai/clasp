import Foundation

public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 20
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaspError.invalidResponse
            }
            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) {
                result, pair in
                result[String(describing: pair.key).lowercased()] = String(describing: pair.value)
            }
            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: data
            )
        } catch let error as ClaspError {
            throw error
        } catch {
            throw ClaspError.transportFailure(message: "Network request failed.")
        }
    }
}
