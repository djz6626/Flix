//
//  TableViewSectionProvider.swift
//  Flix
//
//  Created by DianQK on 04/10/2017.
//  Copyright © 2017 DianQK. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

public enum UITableElementKindSection {
    case header
    case footer
}

public protocol _SectionPartionTableViewProvider {
    
    var identity: String { get }
    var cellType: UITableViewHeaderFooterView.Type { get }
    var tableElementKindSection: UITableElementKindSection { get }
    
    func _tableView(_ tableView: UITableView, heightInSection section: Int, node: _Node) -> CGFloat?
    func _configureSection(_ tableView: UITableView, view: UITableViewHeaderFooterView, viewInSection section: Int, node: _Node)
    
    func _genteralSectionPartion() -> Observable<_Node?>
    
}

extension _SectionPartionTableViewProvider {
    
    public func register(_ tableView: UITableView) {
        tableView.register(self.cellType, forHeaderFooterViewReuseIdentifier: self.identity)
    }

}

public protocol SectionPartionTableViewProvider: _SectionPartionTableViewProvider {
    
    associatedtype Cell: UITableViewHeaderFooterView
    associatedtype Value
    
    func tableView(_ tableView: UITableView, heightInSection section: Int, value: Value) -> CGFloat?
    func configureSection(_ tableView: UITableView, view: UITableViewHeaderFooterView, viewInSection section: Int, value: Value)
    
    func genteralSection() -> Observable<Value?>
    
}

extension SectionPartionTableViewProvider {
    
    public var cellType: UITableViewHeaderFooterView.Type { return Cell.self }
    
    public func _configureSection(_ tableView: UITableView, view: UITableViewHeaderFooterView, viewInSection section: Int, node: _Node) {
        if let valueNode = node as? ValueNode<Value> {
            self.configureSection(tableView, view: view as! Cell, viewInSection: section, value: valueNode.value)
        } else {
            fatalError()
        }
    }
    
    public func _genteralSectionPartion() -> Observable<_Node?> {
        let providerIdentity = self.identity
        return genteralSection().map { $0.map { ValueNode(providerIdentity: providerIdentity, value: $0) } }
    }
    
    public func _tableView(_ tableView: UITableView, heightInSection section: Int, node: _Node) -> CGFloat? {
        if let valueNode = node as? ValueNode<Value> {
            return self.tableView(tableView, heightInSection: section, value: valueNode.value)
        } else {
            fatalError()
        }
    }
    
    public func tableView(_ tableView: UITableView, heightInSection section: Int, node: _Node) -> CGFloat? {
        return nil
    }
    
}

public protocol _AnimatableSectionPartionProviderable {
    
    func _genteralAnimatableSectionPartion() -> Observable<IdentifiableNode?>
    
}

public typealias _AnimatableSectionPartionTableViewProvider = _AnimatableSectionPartionProviderable & _SectionPartionTableViewProvider

public protocol AnimatablePartionSectionTableViewProvider: SectionPartionTableViewProvider, _AnimatableSectionPartionProviderable where Value: Equatable, Value: StringIdentifiableType {

    func genteralAnimatableSectionPartion() -> Observable<IdentifiableNode?>
    
}

extension AnimatablePartionSectionTableViewProvider {
    
    public func _genteralAnimatableSectionPartion() -> Observable<IdentifiableNode?> {
        return genteralAnimatableSectionPartion()
    }
    
}

extension AnimatablePartionSectionTableViewProvider {
    
    public func _configureSection(_ tableView: UITableView, view: UITableViewHeaderFooterView, viewInSection section: Int, node: _Node) {
        if let valueNode = node as? IdentifiableValueNode<Value> {
            self.configureSection(tableView, view: view as! Cell, viewInSection: section, value: valueNode.value)
        } else {
            fatalError()
        }
    }
    
    public func _tableView(_ tableView: UITableView, heightInSection section: Int, node: _Node) -> CGFloat? {
        if let valueNode = node as? IdentifiableValueNode<Value> {
            return self.tableView(tableView, heightInSection: section, value: valueNode.value)
        } else {
            fatalError()
        }
    }
    
    public func tableView(_ tableView: UITableView, heightInSection section: Int, value: Value) -> CGFloat? {
        return nil
    }
    
    public func _genteralSectionPartion() -> Observable<_Node?> {
        let providerIdentity = self.identity
        return genteralSection().map { $0.map { IdentifiableValueNode(providerIdentity: providerIdentity, value: $0) } }
    }
    
    public func genteralAnimatableSectionPartion() -> Observable<IdentifiableNode?> {
        let providerIdentity = self.identity
        return genteralSection()
            .map { $0.map { IdentifiableNode(node: IdentifiableValueNode(providerIdentity: providerIdentity, value: $0)) } }
    }
    
}
