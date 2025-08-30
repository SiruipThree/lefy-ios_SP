//
//  ViewController.swift
//  LefyDemo_Heart
//
//  Created by Three on 8/29/25.
//

import UIKit
import Alamofire
// MARK: - Animated Line Chart (UIKit + CoreAnimation)
final class AnimatedLineChartView: UIView {
    private let sbpLayer = CAShapeLayer()
    private let dbpLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true

        gridLayer.strokeColor = UIColor.tertiaryLabel.cgColor
        gridLayer.lineWidth = 0.5
        gridLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(gridLayer)

        for l in [sbpLayer, dbpLayer] {
            l.fillColor = UIColor.clear.cgColor
            l.lineWidth = 2
            l.lineJoin = .round
            l.lineCap = .round
            layer.addSublayer(l)
        }
        sbpLayer.strokeColor = UIColor.systemRed.cgColor
        dbpLayer.strokeColor = UIColor.systemBlue.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var sbp: [Double] = []
    private var dbp: [Double] = []

    func configure(sbp: [Double], dbp: [Double]) {
        self.sbp = sbp
        self.dbp = dbp
        setNeedsLayout()
        layoutIfNeeded()
        redraw(animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw(animated: false)
    }

    private func redraw(animated: Bool) {
        guard sbp.count > 1, sbp.count == dbp.count else {
            sbpLayer.path = nil
            dbpLayer.path = nil
            gridLayer.path = nil
            return
        }

        let inset: CGFloat = 12
        let rect = bounds.insetBy(dx: inset, dy: inset)

        // grid lines
        let grid = UIBezierPath()
        for i in 0...3 {
            let y = rect.minY + rect.height * CGFloat(i) / 3.0
            grid.move(to: CGPoint(x: rect.minX, y: y))
            grid.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        gridLayer.path = grid.cgPath

        // scale
        let all = sbp + dbp
        let minV = max(0.0, (all.min() ?? 0) - 5)
        let maxV = (all.max() ?? 1) + 5
        let dy = max(maxV - minV, 1)

        func path(for values: [Double]) -> CGPath {
            let p = UIBezierPath()
            let n = values.count
            let stepX = rect.width / CGFloat(max(n - 1, 1))
            for (idx, v) in values.enumerated() {
                let x = rect.minX + CGFloat(idx) * stepX
                let yRatio = (v - minV) / dy
                let y = rect.maxY - CGFloat(yRatio) * rect.height
                let pt = CGPoint(x: x, y: y)
                if idx == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            return p.cgPath
        }

        let sbpPath = path(for: sbp)
        let dbpPath = path(for: dbp)

        if animated {
            for (layer, newPath) in [(sbpLayer, sbpPath), (dbpLayer, dbpPath)] {
                layer.path = newPath
                layer.removeAllAnimations()
                let anim = CABasicAnimation(keyPath: "strokeEnd")
                anim.fromValue = 0
                anim.toValue = 1
                anim.duration = 0.8
                layer.strokeEnd = 1
                layer.add(anim, forKey: "stroke")
            }
        } else {
            sbpLayer.path = sbpPath
            dbpLayer.path = dbpPath
        }
    }
}
// MARK: - Upload Form (Modal)
final class UploadFormController: UIViewController {
    var onSubmit: ((Int, Int, Int?, Date) -> Void)?

    private let sbpField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "SBP (e.g. 120)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        tf.text = "120"
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private let dbpField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "DBP (e.g. 75)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        tf.text = "75"
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private let hrField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "HR (optional, e.g. 70)"
        tf.keyboardType = .numberPad
        tf.borderStyle = .roundedRect
        tf.text = "70"
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.preferredDatePickerStyle = .compact
        dp.datePickerMode = .dateAndTime
        dp.translatesAutoresizingMaskIntoConstraints = false
        return dp
    }()
    private let submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Submit", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let errorLabel: UILabel = {
        let lb = UILabel()
        lb.textColor = .systemRed
        lb.font = .systemFont(ofSize: 13, weight: .regular)
        lb.numberOfLines = 0
        lb.isHidden = true
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Measurement"

        stack.addArrangedSubview(sbpField)
        stack.addArrangedSubview(dbpField)
        stack.addArrangedSubview(hrField)
        let dateRow = UIStackView(arrangedSubviews: [UILabel()])
        dateRow.axis = .horizontal
        dateRow.spacing = 8
        // Add a left label for date
        let dateLabel = UILabel()
        dateLabel.text = "Timestamp"
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateRow.addArrangedSubview(dateLabel)
        dateRow.addArrangedSubview(datePicker)
        stack.addArrangedSubview(dateRow)
        stack.addArrangedSubview(errorLabel)

        let buttons = UIStackView(arrangedSubviews: [cancelButton, submitButton])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            buttons.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttons.heightAnchor.constraint(equalToConstant: 44)
        ])

        submitButton.addTarget(self, action: #selector(onSubmitTap), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(onCancelTap), for: .touchUpInside)
    }

    @objc private func onCancelTap() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func onSubmitTap() {
        errorLabel.isHidden = true
        guard let sbp = Int(sbpField.text ?? ""), let dbp = Int(dbpField.text ?? "") else {
            errorLabel.text = "Invalid input: SBP/DBP must be integers"
            errorLabel.isHidden = false
            return
        }
        let hr = Int(hrField.text ?? "")
        onSubmit?(sbp, dbp, hr, datePicker.date)
    }
}

// MARK: - Custom Cell (Card style)
final class MeasurementCell: UITableViewCell {
    static let reuseId = "MeasurementCell"

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 14
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 20, weight: .semibold)
        lb.textColor = .label
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()

    private let subtitleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 13, weight: .regular)
        lb.textColor = .secondaryLabel
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(sbp: Int, dbp: Int, hr: Int?, timestamp: String) {
        let hrText = hr != nil ? "  HR: \(hr!)" : ""
        titleLabel.text = "\(sbp)/\(dbp)\(hrText)"
        subtitleLabel.text = timestamp
    }
}

// MARK: - Models

struct Measurement: Decodable {
    let sbp: Int
    let dbp: Int
    let hr: Int?
    let timestamp: String
}

struct MeasurementsResponse: Decodable {
    let ok: Bool
    let items: [Measurement]
}

// MARK: - Networking

private func fetchMeasurements(userId: String, completion: @escaping (Result<[Measurement], Error>) -> Void) {
    let url = Backend.baseURL.appendingPathComponent("measurements")
    let params: Parameters = ["user_id": userId]
    AF.request(url, method: .get, parameters: params)
        .validate(statusCode: 200..<300)
        .responseDecodable(of: MeasurementsResponse.self) { resp in
            switch resp.result {
            case .success(let data):
                completion(.success(data.items))
            case .failure(let err):
                completion(.failure(err))
            }
        }
}

private func uploadOneDemo(completion: @escaping (Result<Void, Error>) -> Void) {
    let demo = MeasurementUpload(
        user_id: "demo-user",
        sbp: 120, dbp: 75, hr: 70,
        timestamp: ISO8601DateFormatter().string(from: Date())
    )
    uploadMeasurement(demo, completion: completion)
}

// MARK: - View Controller

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    
    private let chartView: AnimatedLineChartView = {
        let v = AnimatedLineChartView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let statusLabel: UILabel = {
        let lb = UILabel()
        lb.text = "Ready"
        lb.textAlignment = .center
        lb.numberOfLines = 1
        lb.font = .systemFont(ofSize: 17, weight: .medium)
        lb.textColor = .label
        lb.backgroundColor = .secondarySystemBackground
        lb.layer.cornerRadius = 10
        lb.layer.masksToBounds = true
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let refreshButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Refresh", for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let uploadButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Upload", for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    private let controlsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let statsView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        return v
    }()
    
    private let statsLabel: UILabel = {
        let lb = UILabel()
        lb.textAlignment = .center
        lb.numberOfLines = 0
        lb.font = .systemFont(ofSize: 15, weight: .medium)
        lb.textColor = .label
        return lb
    }()

    private var items: [Measurement] = []
    private let isoFormatter = ISO8601DateFormatter()
    private let shortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Measurements"

        view.addSubview(tableView)
        view.addSubview(statusLabel)

        controlsStack.addArrangedSubview(refreshButton)
        controlsStack.addArrangedSubview(uploadButton)
        view.addSubview(controlsStack)
        view.addSubview(chartView)
        
        statsView.addSubview(statsLabel)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 12),
            statsLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 12),
            statsLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -12),
            statsLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -12)
        ])
        tableView.tableFooterView = statsView
        
        refreshButton.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)
        uploadButton.addTarget(self, action: #selector(onUpload), for: .touchUpInside)

        tableView.dataSource = self
        tableView.delegate = self

        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
        tableView.refreshControl = rc

        tableView.register(MeasurementCell.self, forCellReuseIdentifier: MeasurementCell.reuseId)
        tableView.separatorStyle = .none

        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsStack.heightAnchor.constraint(equalToConstant: 40),

            chartView.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 8),
            chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 160),

            tableView.topAnchor.constraint(equalTo: chartView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.backgroundColor = .systemGroupedBackground
        view.backgroundColor = .systemGroupedBackground
        
        controlsStack.alignment = .fill
        refreshButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        uploadButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        testAlamofire()
        refreshData()
    }

    // MARK: - Actions

    @objc private func onRefresh() {
        refreshData()
    }

    @objc private func onUpload() {
        let form = UploadFormController()
        form.modalPresentationStyle = .formSheet
        form.onSubmit = { [weak self] sbp, dbp, hr, date in
            guard let self = self else { return }
            self.dismiss(animated: true, completion: nil)
            self.statusLabel.text = "Uploading to Django..."
            let payload = MeasurementUpload(
                user_id: "demo-user",
                sbp: sbp,
                dbp: dbp,
                hr: hr,
                timestamp: ISO8601DateFormatter().string(from: date)
            )
            uploadMeasurement(payload) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.statusLabel.text = "Upload Django: success"
                        self.refreshData()
                    case .failure(let err):
                        self.statusLabel.text = "Upload Django: failed\n\(err.localizedDescription)"
                    }
                }
            }
        }
        present(form, animated: true, completion: nil)
    }

    @objc private func onPullToRefresh() {
        refreshData()
    }

    private func refreshData() {
        statusLabel.text = "Loading measurements..."
        fetchMeasurements(userId: "demo-user") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let arr):
                    self?.items = Array(arr.prefix(20)) // show up to 20
                    self?.tableView.reloadData()
                    self?.updateStats()
                    self?.updateChart()
                    self?.statusLabel.text = "Loaded \(self?.items.count ?? 0) item(s)"
                    self?.tableView.refreshControl?.endRefreshing()
                case .failure(let err):
                    self?.statusLabel.text = "Load failed: \(err.localizedDescription)"
                    self?.tableView.refreshControl?.endRefreshing()
                }
            }
        }
    }
    private func updateChart() {
        guard !items.isEmpty else {
            chartView.configure(sbp: [], dbp: [])
            return
        }
        let last = Array(items.suffix(min(20, items.count)))
        let sbpSeries = last.map { Double($0.sbp) }
        let dbpSeries = last.map { Double($0.dbp) }
        chartView.configure(sbp: sbpSeries, dbp: dbpSeries)
    }
    private func updateStats() {
        guard !items.isEmpty else {
            statsLabel.text = "No data"
            sizeStatsFooter()
            return
        }
        let sbps = items.map { Double($0.sbp) }
        let dbps = items.map { Double($0.dbp) }
        let hrs  = items.compactMap { $0.hr }.map { Double($0) }
    
        let avgSBP = sbps.reduce(0, +) / Double(sbps.count)
        let avgDBP = dbps.reduce(0, +) / Double(dbps.count)
        let avgHR: Double? = hrs.isEmpty ? nil : (hrs.reduce(0, +) / Double(hrs.count))
    
        statsLabel.text = String(format: "Avg (%d):  SBP %.1f   DBP %.1f   HR %@", items.count, avgSBP, avgDBP, (avgHR != nil ? String(format: "%.1f", avgHR!) : "—"))
        sizeStatsFooter()
    }
    
    private func sizeStatsFooter() {
        let targetWidth = view.bounds.width - 32
        let size = statsLabel.sizeThatFits(CGSize(width: targetWidth - 24, height: CGFloat.greatestFiniteMagnitude))
        let height = size.height + 24
        statsView.frame = CGRect(x: 16, y: 0, width: targetWidth, height: height)
        tableView.tableFooterView = statsView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeStatsFooter()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MeasurementCell.reuseId, for: indexPath) as? MeasurementCell else {
            return UITableViewCell()
        }
        let m = items[indexPath.row]
        var ts = m.timestamp
        if let date = isoFormatter.date(from: m.timestamp) {
            ts = shortFormatter.string(from: date)
        }
        cell.configure(sbp: m.sbp, dbp: m.dbp, hr: m.hr, timestamp: ts)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88
    }
}
