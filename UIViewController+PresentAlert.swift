import Foundation
import UIKit
extension UIViewController {
    func presentAlert(alert : String) {
        let alert = UIAlertController(title: "Error", message: alert, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(OKAction)
        self.present(alert, animated: true, completion: nil)
    }
}
