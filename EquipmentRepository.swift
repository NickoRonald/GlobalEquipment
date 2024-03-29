import Foundation
import Kingfisher
import CoreData
class EquipmentRepository {
    static func baseUrl() -> String {return "http://api.jjmtaylor.com:8080/"}
    static func getAllUrl() -> String {return baseUrl() + "getAllCombined"}
    static func app(completion: @escaping (AppDelegate) -> ()) {
        DispatchQueue.main.async {
            completion(UIApplication.shared.delegate as! AppDelegate)
        }
    }
    enum method:String {case GET;case POST;case PATCH;case DELETE}
    static var equipment : [Equipment]?
    static func getEquipment(completionHandler: @escaping (String?)->()) -> [Equipment]?{
        if equipment != nil && equipment!.count > 0 { return equipment } 
        equipment = getEquipmentFromDatabase() 
        if !fetchNeeded() && equipment != nil && equipment!.count > 0 { return equipment }
        getEquipmentFromNetwork {(equipment, error) in completionHandler(error)}
        return nil
    }
    static func getEquipmentFromDatabase() -> [Equipment]? {
        let moc = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        do {
            var equipment = [Equipment]()
            guard let gunResults = try moc.fetch(Gun.fetchRequest()) as? [Gun] else {return nil}
            guard let landResults = try moc.fetch(Land.fetchRequest()) as? [Land] else {return nil}
            guard let airResults = try moc.fetch(Air.fetchRequest()) as? [Air] else {return nil}
            guard let seaResults = try moc.fetch(Sea.fetchRequest()) as? [Sea] else {return nil}
            equipment.append(contentsOf: gunResults)
            equipment.append(contentsOf: landResults)
            equipment.append(contentsOf: airResults)
            equipment.append(contentsOf: seaResults)
            return equipment
        } catch {
            print(error)
        }
        return nil
    }
    fileprivate static func getEquipmentFromNetwork(completionHandler: @escaping ([Equipment]?,String?)->()) {
        guard let url = URL(string: getAllUrl()) else {
            completionHandler(nil,"Failed to convert url to string"); return
        }
        let headers = ["Cache-Control": "no-cache"]
        let request = NSMutableURLRequest(url: url, cachePolicy: .useProtocolCachePolicy,timeoutInterval: 10.0)
        request.httpMethod = method.GET.rawValue
        request.allHTTPHeaderFields = headers
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            if (error != nil) { completionHandler(nil, error?.localizedDescription)
            } else {
                app() { app in
                    do {
                        let moc = app.persistentContainer.newBackgroundContext()
                        let decoder = JSONDecoder()
                        decoder.userInfo[CodingUserInfoKey.context!] = moc
                        guard let jsonData = data else {
                            completionHandler(nil, "Network returned an empty response.")
                            return
                        }
                        let combined = try decoder.decode(CombinedList.self, from: jsonData)
                        try moc.save()
                        setLastFetchDate()
                        prefetchImages(combined: combined)
                        completionHandler(combined.getEquipment(), nil)
                    } catch { completionHandler(nil, error.localizedDescription); return }
                }
            }
        })
        dataTask.resume()
    }
    static let fetchDateKey = "fetchDateKey"
    fileprivate static func getLastFetchDate() -> Date {
        let lastFetchTimeInterval = UserDefaults.standard.double(forKey: fetchDateKey)
        return Date(timeIntervalSince1970: lastFetchTimeInterval)
    }
    fileprivate static func setLastFetchDate(_ date: Date = Date()) {
        let timeInterval = date.timeIntervalSince1970
        UserDefaults.standard.set(timeInterval,forKey: fetchDateKey)
    }
    fileprivate static func fetchNeeded() -> Bool {
        let lastFetch = getLastFetchDate().timeIntervalSince1970
        let now = Date().timeIntervalSince1970
        let oneWeek = Double(7 * 24 * 60 * 60)
        return now - oneWeek > lastFetch
    }
    fileprivate static func prefetchImages(combined : CombinedList) {
        var urls = [URL]()
        ImageCache.default.maxCachePeriodInSecond = -1
        let e = combined.getEquipment()
        let placeholder = URL(string: EquipmentRepository.baseUrl())!
        let photoUrls = e.map { URL(string: EquipmentRepository.baseUrl() + ($0.photoUrl ?? "")) ?? placeholder }
        let indIconUrls = e.map { URL(string: EquipmentRepository.baseUrl() + ($0.individualIconUrl ?? "")) ?? placeholder }
        let airGroupIconUrls = combined.air.map {
            URL(string: EquipmentRepository.baseUrl() + ($0.groupIconUrl ?? "")) ?? placeholder }
        let landGroupIconUrls = combined.land.map {
            URL(string: EquipmentRepository.baseUrl() + ($0.groupIconUrl ?? "")) ?? placeholder }
        let gunGroupIconUrls = combined.guns.map {
            URL(string: EquipmentRepository.baseUrl() + ($0.groupIconUrl ?? "")) ?? placeholder }
        urls.append(contentsOf: photoUrls)
        urls.append(contentsOf: indIconUrls)
        urls.append(contentsOf: airGroupIconUrls)
        urls.append(contentsOf: landGroupIconUrls)
        urls.append(contentsOf: gunGroupIconUrls)
        let prefetcher = ImagePrefetcher(urls: urls) {skippedResources, failedResources, completedResources in}
        prefetcher.start()
    }
    static func setImage(_ imageView: UIImageView ,_ url: String?){
        guard let imageUrl = url else {return}
        guard let url = URL(string: EquipmentRepository.baseUrl() + imageUrl) else {return}
        imageView.kf.setImage(with: url, options: nil)
    }
}
