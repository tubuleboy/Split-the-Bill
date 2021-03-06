//
//  AddItemsVC.swift
//  SplitBill
//
//  Created by Clive Liu on 11/23/20.
//

import UIKit
import Vision
import VisionKit


class AddItemsVC: SBTableViewController {
    
    private let addItemsButton = SBIconButton(icon: SFSymbols.action, tintColor: Colors.orange)
    private let priceTagPattern = "^-?\\$?-?\\d+\\.\\d{2}-?"
    private let pricePattern = "\\d+\\.\\d{2}"
    private let nonItemKeywords = ["total", "balance", "sales"]
    
    private var items = [Item]()
    private var textRecognitionRequest = VNRecognizeTextRequest()
    
    private lazy var activityIndicator = UIActivityIndicatorView(style: .large)
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTextRecognitionRequest()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        addItemsButton.makeCircle()
        addItemsButton.drawShadow()
    }
    
    override func layoutUI() {
        super.layoutUI()

        configureAddItemsButton()
        configureActivityIndicator()
    }
    
    override func configureTableView() {
        super.configureTableView()
        
        tableView.delegate = self
        tableView.dataSource = self
    }

}


extension AddItemsVC {

    private func configureAddItemsButton() {
        view.addSubview(addItemsButton)
        
        addItemsButton.addTarget(self, action: #selector(addItemsButtonTapped), for: .touchUpInside)
        
        let padding:CGFloat = 30
        let size: CGFloat = 44
        
        NSLayoutConstraint.activate([
            addItemsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -padding),
            addItemsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -padding),
            addItemsButton.widthAnchor.constraint(equalToConstant: size),
            addItemsButton.heightAnchor.constraint(equalToConstant: size)
        ])
    }
    
    private func configureActivityIndicator() {
        view.addSubview(activityIndicator)
        
        activityIndicator.useAutoLayout()
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    @objc
    private func addItemsButtonTapped() {
        guard !activityIndicator.isAnimating else { return }
        
        let alert = UIAlertController(title: "Choose an action", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Assign Items", style: .default, handler: { [weak self] (_) in
            self?.assign()
        }))
        
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] (_) in
            self?.addOrEditItem()
        }))
        
        alert.addAction(UIAlertAction(title: "Scan Receipt", style: .default, handler: { [weak self] (_) in
            self?.scanReceipt()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        
        present(alert, animated: true)
    }

    private func addOrEditItem(_ item: Item? = nil) {
        let alert = UIAlertController(title: "Item Info", message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.text = item?.identifier
            textField.borderStyle = .roundedRect
            textField.keyboardType = .alphabet
            textField.clearButtonMode = .whileEditing
            textField.placeholder = "Please enter item name"
            textField.leftView = SBAlertLabel(message: "Name: ")
            textField.leftViewMode = .always
        }
        
        alert.addTextField { (textField) in
            if let value = item?.value {
                textField.text = "\(value)"
            }
            textField.borderStyle = .roundedRect
            textField.keyboardType = .decimalPad
            textField.clearButtonMode = .whileEditing
            textField.placeholder = "Please enter item value"
            textField.leftView = SBAlertLabel(message: "Value: ")
            textField.leftViewMode = .always
        }
        
        alert.addTextField { (textField) in
            if let tax = item?.tax {
                textField.text = "\(tax)"
            }
            textField.borderStyle = .roundedRect
            textField.placeholder = "Default 0 %"
            textField.keyboardType = .decimalPad
            textField.clearButtonMode = .whileEditing
            textField.leftView = SBAlertLabel(message: "Tax: ")
            textField.leftViewMode = .always
        }
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [weak self] (_) in
            guard let self = self,
                  let name = alert.textFields?[0].text,
                  !name.isEmpty,
                  let valueText = alert.textFields?[1].text,
                  !valueText.isEmpty,
                  let value = Float(valueText),
                  let tax = alert.textFields?[2].text
            else {
                UIDevice.vibrate()
                return
            }
            
            let newItem = item ?? Item(context: PersistenceManager.shared.context)
            newItem.name = name
            newItem.value = value
            newItem.tax = Float(tax) ?? 0
            
            if item == nil {
                self.items.append(newItem)
            }
            self.tableView.reloadData()
            PersistenceManager.shared.saveContext()
        }))
        
        present(alert, animated: true)
    }
    
    private func scanReceipt() {
        let documentCameraVC = VNDocumentCameraViewController()
        documentCameraVC.delegate = self
        present(documentCameraVC, animated: true)
    }
    
    private func assign() {
        if items.isEmpty {
            UIDevice.vibrate()
        }else {
            let vc = AssignItemsVC(items: items)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}


extension AddItemsVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if items.isEmpty {
            showEmptyStateView()
            view.bringSubviewToFront(addItemsButton)
            view.bringSubviewToFront(activityIndicator)
        }else {
            hideEmptyStateView()
        }

        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SBTableViewCell.identifier) as! SBTableViewCell
        cell.set(object: items[indexPath.row], indicatorType: .bar, secondaryTextStyle: .includeTax)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SBTableViewCell
        cell.toggleSelection()
        addOrEditItem(items[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [createDeleteAction(indexPath: indexPath)])
    }
    
    private func createDeleteAction(indexPath: IndexPath) -> UIContextualAction {
        return UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.items.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            completion(true)
        }
    }

}


extension AddItemsVC: VNDocumentCameraViewControllerDelegate {
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        activityIndicator.startAnimating()
        
        controller.dismiss(animated: true) { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                for pageNumber in 0 ..< scan.pageCount {
                    let image = scan.imageOfPage(at: pageNumber)
                    self?.processImage(image: image)
                }
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func processImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to get cgimage from input image")
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([textRecognitionRequest])
        } catch {
            print(error)
        }
    }
    
    private func configureTextRecognitionRequest() {
        textRecognitionRequest = VNRecognizeTextRequest(completionHandler: { [weak self] (request, error) in
            if let results = request.results, !results.isEmpty {
                if let requestResults = request.results as? [VNRecognizedTextObservation] {
                    self?.addTextObservations(recognizedText: requestResults)
                }
            }
        })
        
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.recognitionLanguages = ["en-US"]
        textRecognitionRequest.usesLanguageCorrection = true
    }
    
    private func addTextObservations(recognizedText: [VNRecognizedTextObservation]) {
        var lines = filterTextObservations(recognizedText)
        filterRecognizedText(&lines)
        addRecognizedText(lines)
    }
    
    private func filterTextObservations(_ recognizedText: [VNRecognizedTextObservation]) -> [[VNRecognizedText]] {
        let observations = recognizedText.sorted(by: {$0.boundingBox.maxY > $1.boundingBox.maxY})

        var lines = [[VNRecognizedText]]()
        var rects = [CGRect]()
        
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let centerY = (observation.boundingBox.minY + observation.boundingBox.maxY) / 2
            
            if let rect = rects.last, rect.minY <= centerY, centerY <= rect.maxY {
                lines[lines.count - 1].append(candidate)
            }else {
                rects.append(observation.boundingBox)
                lines.append([candidate])
            }
        }
        
        return lines
    }
    
    private func filterRecognizedText(_ lines: inout [[VNRecognizedText]]) {
        lines = lines.filter({ [weak self] in
            guard let self = self else { return false }
            
            for text in $0 {
                if self.isPriceTag(text: text.string) {
                    return true
                }
            }
            return false
        })
    }
    
    private func addRecognizedText(_ lines: [[VNRecognizedText]]) {
        for line in lines {
            var name = ""
            var price: Float = 0
            
            for text in line {
                if isPriceTag(text: text.string) {
                    let negative = text.string.contains("-")
                    
                    price = extractPrice(text: text.string)
                    
                    if negative {
                        price = -price
                    }
                }else {
                    name += text.string
                }
            }
            
            if price == 0 { continue }
            
            if noMoreItems(name) { break }
            
            let item = Item(context: PersistenceManager.shared.context)
            item.name = name
            item.value = price
            
            items.append(item)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private func extractPrice(text: String) -> Float {
        do {
            let regex = try NSRegularExpression(pattern: pricePattern, options: [])
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                if let price = Float((text as NSString).substring(with: match.range)) {
                    return price
                }
            }
        } catch {
            print(error)
        }
        return 0
    }
    
    private func isPriceTag(text: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: priceTagPattern, options: [])
            if let _ = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                return true
            }
        } catch {
            print(error)
        }
        return false
    }
    
    private func noMoreItems(_ text: String) -> Bool {
        let text = text.lowercased()
        for keyword in nonItemKeywords {
            if text.contains(keyword) {
                return true
            }
        }
        return false
    }
    
}
