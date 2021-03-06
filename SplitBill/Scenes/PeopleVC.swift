//
//  PeopleVC.swift
//  SplitBill
//
//  Created by Clive Liu on 11/11/20.
//

import UIKit


class PeopleVC: SBTableViewController {
    
    private var people = [Person]()
    
    
    override func layoutUI() {
        super.layoutUI()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPerson))
    }
    
    override func configureTableView() {
        super.configureTableView()
        
        tableView.delegate = self
        tableView.dataSource = self
    }

}


extension PeopleVC {
    
    private func personExist(name: String) -> Bool {
        for person in people {
            if person.name.lowercased() == name.lowercased() {
                return true
            }
        }
        return false
    }
    
    @objc
    private func addPerson() {
        let alert = UIAlertController(title: "Add Person", message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "John Doe"
        }
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [weak self] (action) in
            guard let text = alert.textFields?.first?.text,
                  !text.isEmpty,
                  !(self?.personExist(name: text) ?? true)
            else { return }
            
            let person = Person(context: PersistenceManager.shared.context)
            person.name = text
            
            self?.people.append(person)
            self?.tableView.reloadData()
        }))
        
        present(alert, animated: true, completion: nil)
    }

}


extension PeopleVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        PersistenceManager.shared.loadPeople { [weak self] (result) in
            switch result {
            case .success(let people):
                self?.people = people
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return people.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SBTableViewCell.identifier) as! SBTableViewCell
        cell.set(object: people[indexPath.row], indicatorType: .bar, secondaryTextStyle: .amountOnly)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SBTableViewCell
        let person = people[indexPath.row]
        let vc = PersonItemListVC(person: person)
        
        cell.toggleSelection()
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [createResetAction(indexPath: indexPath), createDeleteAction(indexPath: indexPath)])
    }

    private func createResetAction(indexPath: IndexPath) -> UIContextualAction {
        return UIContextualAction(style: .normal, title: "Reset") { [weak self] (action, view, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            let person = self.people[indexPath.row]
            person.reset()
            
            self.tableView.reloadData()
            completion(true)
        }
    }

    private func createDeleteAction(indexPath: IndexPath) -> UIContextualAction {
        return UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            let person = self.people[indexPath.row]
            self.people.remove(at: indexPath.row)
            
            PersistenceManager.shared.context.delete(person)
            PersistenceManager.shared.saveContext()
            
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            completion(true)
        }
    }

}
