import UIKit
import Kingfisher
class EquipmentCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    func configure(e: Equipment){
        nameLabel.text = e.name
        guard let imageUrl = e.photoUrl else {return}
        guard let url = URL(string: EquipmentRepository.baseUrl() + imageUrl) else {return}
        imageView.kf.setImage(with: url, options: [.transition(.fade(0.2))])
    }
}
