///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import TjekSDK
import UIKit

class PublicationListContentsViewController: UITableViewController {
    
    let publications: [Publication_v2]
    let shouldOpenIncito: (Publication_v2) -> Void
    let shouldOpenPagedPub: (Publication_v2) -> Void
    
    init(publications: [Publication_v2],
         shouldOpenIncito: @escaping (Publication_v2) -> Void,
         shouldOpenPagedPub: @escaping (Publication_v2) -> Void
        ) {
        self.publications = publications
        self.shouldOpenIncito = shouldOpenIncito
        self.shouldOpenPagedPub = shouldOpenPagedPub
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(PublicationListCell.self, forCellReuseIdentifier: "PublicationListCell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return publications.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let publication = publications[indexPath.row]
        let hasIncito = publication.hasIncitoPublication
        let hasPaged = publication.hasPagedPublication
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PublicationListCell", for: indexPath) as! PublicationListCell
        
        cell.selectionStyle = .none
        
        cell.textLabel?.text = publication.branding.name
        cell.incitoPubButton.isHidden = !hasIncito
        cell.pagedPubButton.isHidden = !hasPaged
        
        cell.didTapIncitoButton = { [weak self] in
            self?.shouldOpenIncito(publication)
        }
        cell.didTapPagedPubButton = { [weak self] in
            self?.shouldOpenPagedPub(publication)
        }
        return cell
    }
}

class PublicationListCell: UITableViewCell {
    
    var didTapIncitoButton: (() -> Void)?
    var didTapPagedPubButton: (() -> Void)?
    
    lazy var incitoPubButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("Incito", for: .normal)
        btn.backgroundColor = UIColor(red: 72/255, green: 68/255, blue: 148/255, alpha: 1)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 4
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        btn.addTarget(self, action: #selector(didTapIncito(_:)), for: .touchUpInside)
        return btn
    }()
    
    lazy var pagedPubButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("PDF", for: .normal)
        btn.backgroundColor = UIColor(red: 233/255, green: 90/255, blue: 26/255, alpha: 1)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 4
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        
        btn.addTarget(self, action: #selector(didTapPagedPub(_:)), for: .touchUpInside)
        return btn
    }()
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
        let stack = UIStackView(arrangedSubviews: [
            incitoPubButton, pagedPubButton
            ])
        stack.spacing = 4
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        self.contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor)
            ])
    }
    
    public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    @objc private func didTapIncito(_ sender: UIButton) {
        didTapIncitoButton?()
    }
    @objc private func didTapPagedPub(_ sender: UIButton) {
        didTapPagedPubButton?()
    }
}
