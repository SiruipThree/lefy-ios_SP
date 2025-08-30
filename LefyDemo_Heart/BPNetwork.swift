//
//  BPNetwork.swift
//  LefyDemo_Heart
//
//  Created by Three on 8/30/25.
//

import Foundation
import Alamofire

// MARK: - DTO

/// 上传血压的最小数据体
struct MeasurementUpload: Encodable {
    let user_id: String
    let sbp: Int
    let dbp: Int
    let hr: Int?
    let timestamp: String
}

// MARK: - Backend Config

enum Backend {
    /// 模拟器直接使用 127.0.0.1；若真机联调，把它改成你 Mac 的局域网 IP（如 192.168.x.x）
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
    /// 如需鉴权可填入 token（Django 目前不需要）
    static let token: String? = nil
}

// MARK: - API Calls

/// POST /measurements 上传一条测量
func uploadMeasurement(_ m: MeasurementUpload, completion: @escaping (Result<Void, Error>) -> Void) {
    let url = Backend.baseURL.appendingPathComponent("measurements")
    var headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
    if let token = Backend.token {
        headers.add(name: "Authorization", value: "Bearer \(token)")
    }
    AF.request(url, method: .post, parameters: m, encoder: JSONParameterEncoder.default, headers: headers)
        .validate(statusCode: 200..<300)
        .response { resp in
            if let error = resp.error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
}

/// 演示触发：在某个 VC 里调用即可（如 viewDidAppear 或按钮点击）
func demoUploadNow() {
    let demo = MeasurementUpload(
        user_id: "demo-user",
        sbp: 120,
        dbp: 75,
        hr: 70,
        timestamp: ISO8601DateFormatter().string(from: Date())
    )
    uploadMeasurement(demo) { result in
        print("=== Upload Django ===", result)
    }
}

// MARK: - Alamofire 安装自检（可选）

/// 访问 httpbin.org 验证 Alamofire 是否正常工作
func testAlamofire() {
    AF.request("https://httpbin.org/get").response { response in
        switch response.result {
        case .success(let data):
            if let data, let str = String(data: data, encoding: .utf8) {
                print("=== Test Alamofire === 请求成功:\n\(str)")
            } else {
                print("=== Test Alamofire === 请求成功，但无可显示数据")
            }
        case .failure(let error):
            print("=== Test Alamofire === 请求失败:", error)
        }
    }
}
