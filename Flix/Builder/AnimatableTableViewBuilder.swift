//
//  AnimatableTableViewBuilder.swift
//  Flix
//
//  Created by DianQK on 04/10/2017.
//  Copyright © 2017 DianQK. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

public class AnimatableTableViewBuilder {
    
    typealias AnimatableSectionModel = RxDataSources.AnimatableSectionModel<IdentifiableSectionNode, IdentifiableNode>
    
    let dataSource = RxTableViewSectionedAnimatedDataSource<AnimatableSectionModel>()
    let disposeBag = DisposeBag()
    let delegeteService = TableViewDelegateService()
    
    let tableView: UITableView
    
    public var animationConfiguration: AnimationConfiguration {
        get {
            return dataSource.animationConfiguration
        }
        set {
            dataSource.animationConfiguration = newValue
        }
    }
    
    public let sectionProviders: Variable<[AnimatableTableViewSectionProvider]>
    
    private var nodeProviders: [_AnimatableTableViewMultiNodeProvider] = [] {
        didSet {
            for provider in nodeProviders {
                provider.register(tableView)
            }
        }
    }
    private var footerSectionProviders: [_AnimatableSectionPartionTableViewProvider] = [] {
        didSet {
            for provider in footerSectionProviders {
                provider.register(tableView)
            }
        }
    }
    private var headerSectionProviders: [_AnimatableSectionPartionTableViewProvider] = [] {
        didSet {
            for provider in headerSectionProviders {
                provider.register(tableView)
            }
        }
    }

    public init(tableView: UITableView, sectionProviders: [AnimatableTableViewSectionProvider]) {
        
        self.tableView = tableView
        self.sectionProviders = Variable(sectionProviders)
        
        self.animationConfiguration = AnimationConfiguration(
            insertAnimation: .fade,
            reloadAnimation: .none,
            deleteAnimation: .fade
        )
        
        dataSource.configureCell = { [weak self] dataSource, tableView, indexPath, node in
            guard let provider = self?.nodeProviders.first(where: { $0.identity == node.node.providerIdentity }) else { return UITableViewCell() }
            return provider._configureCell(tableView, indexPath: indexPath, node: node.node)
        }
        
        dataSource.canEditRowAtIndexPath = { [weak tableView, weak self] (dataSource, indexPath) in
            guard let tableView = tableView else { return false }
            let node = dataSource[indexPath]
            guard let provider = self?.nodeProviders.first(where: { $0.identity == node.node.providerIdentity }) else { return false } 
            if let provider = provider as? _TableViewEditable {
                return provider._tableView(tableView, canEditRowAt: indexPath, node: node.node)
            } else {
                return false
            }
        }

        tableView.rx.itemSelected
            .subscribe(onNext: { [weak tableView, unowned self] (indexPath) in
                guard let tableView = tableView else { return }
                let node = self.dataSource[indexPath].node
                let provider = self.nodeProviders.first(where: { $0.identity == node.providerIdentity })!
                provider._tap(tableView, indexPath: indexPath, node: node)
            })
            .disposed(by: disposeBag)
        
        tableView.rx.itemDeleted
            .subscribe(onNext: { [weak tableView, unowned self] (indexPath) in
                guard let tableView = tableView else { return }
                let node = self.dataSource[indexPath].node
                let provider = self.nodeProviders.first(where: { $0.identity == node.providerIdentity })! as? _TableViewDeleteable
                provider?._tableView(tableView, itemDeletedForRowAt: indexPath, node: node)
            })
            .disposed(by: disposeBag)
        
        self.delegeteService.heightForRowAt = { [unowned self] tableView, indexPath in
            let node = self.dataSource[indexPath].node
            let providerIdentity = node.providerIdentity
            let provider = self.nodeProviders.first(where: { $0.identity == providerIdentity })!
            return provider._tableView(tableView, heightForRowAt: indexPath, node: node)
        }
        
        self.delegeteService.heightForHeaderInSection = { [unowned self] tableView, section in
            guard let headerNode = self.dataSource[section].model.headerNode?.node else { return nil }
            let providerIdentity = headerNode.providerIdentity
            let provider = self.headerSectionProviders.first(where: { $0.identity == providerIdentity })!
            return provider._tableView(tableView, heightInSection: section, node: headerNode)
        }
        
        self.delegeteService.viewForHeaderInSection = { [unowned self] tableView, section in
            guard let node = self.dataSource[section].model.headerNode else { return UIView() }
            let provider = self.headerSectionProviders.first(where: { $0.identity == node.node.providerIdentity })!
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: provider.identity)!
            provider._configureSection(tableView, view: view, viewInSection: section, node: node.node)
            return view
        }

        self.delegeteService.viewForFooterInSection = { [unowned self] tableView, section in
            guard let node = self.dataSource[section].model.footerNode else { return UIView() }
            let provider = self.footerSectionProviders.first(where: { $0.identity == node.node.providerIdentity })!
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: provider.identity)!
            provider._configureSection(tableView, view: view, viewInSection: section, node: node.node)
            return view
        }
        
        self.delegeteService.heightForFooterInSection = { [unowned self] tableView, section in
            guard let footerNode = self.dataSource[section].model.footerNode?.node else { return nil }
            let providerIdentity = footerNode.providerIdentity
            let provider = self.footerSectionProviders.first(where: { $0.identity == providerIdentity })!
            return provider._tableView(tableView, heightInSection: section, node: footerNode)
        }
        
        self.delegeteService.editActionsForRowAt = { [unowned self] tableView, indexPath in
            let node = self.dataSource[indexPath].node
            let providerIdentity = node.providerIdentity
            let provider = self.nodeProviders.first(where: { $0.identity == providerIdentity })!
            if let provider = provider as? _TableViewEditable {
                return provider._tableView(tableView, editActionsForRowAt: indexPath, node: node)
            } else {
                return nil
            }
        }
        
        tableView.rx.setDelegate(self.delegeteService).disposed(by: disposeBag)
        
        self.sectionProviders.asObservable()
            .do(onNext: { [weak self] (sectionProviders) in
                self?.nodeProviders = sectionProviders.flatMap { $0.animatableProviders }
                self?.footerSectionProviders = sectionProviders.flatMap { $0.animatableFooterProvider }
                self?.headerSectionProviders = sectionProviders.flatMap { $0.animatableHeaderProvider }
            })
            .flatMapLatest { (providers) -> Observable<[AnimatableSectionModel]> in
                let sections: [Observable<(section: IdentifiableSectionNode, nodes: [IdentifiableNode])?>] = providers.map { $0.genteralAnimatableSectionModel() }
                return Observable.combineLatest(sections).map { $0.flatMap { section -> AnimatableSectionModel? in
                    if let section = section {
                        return AnimatableSectionModel(model: section.section, items: section.nodes)
                    } else {
                        return nil
                    }
                    } }
            }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

    }
    
    public convenience init(tableView: UITableView, providers: [_AnimatableTableViewMultiNodeProvider]) {
        let sectionProviderTableViewBuilder = AnimatableTableViewSectionProvider(
            identity: "Flix",
            providers: providers,
            headerProvider: nil,
            footerProvider: nil
        )
        self.init(tableView: tableView, sectionProviders: [sectionProviderTableViewBuilder])
    }
    
}

class TableViewDelegateService: NSObject, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return self.editActionsForRowAt?(tableView, indexPath)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.heightForRowAt?(tableView, indexPath) ?? tableView.rowHeight
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.heightForHeaderInSection?(tableView, section) ?? tableView.sectionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return self.viewForHeaderInSection?(tableView, section)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return self.heightForFooterInSection?(tableView, section) ?? tableView.sectionFooterHeight
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return self.viewForFooterInSection?(tableView, section)
    }
    
    var heightForRowAt: ((_ tableView: UITableView, _ indexPath: IndexPath) -> CGFloat?)?
    var heightForFooterInSection: ((_ tableView: UITableView, _ section: Int) -> CGFloat?)?
    var heightForHeaderInSection: ((_ tableView: UITableView, _ section: Int) -> CGFloat?)?
    var viewForHeaderInSection: ((_ tableView: UITableView, _ section: Int) -> UIView?)?
    var viewForFooterInSection: ((_ tableView: UITableView, _ section: Int) -> UIView?)?
    var editActionsForRowAt: ((_ tableView: UITableView, _ indexPath: IndexPath) -> [UITableViewRowAction]?)?
    
}
