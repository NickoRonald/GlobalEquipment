import UIKit
import Lottie
import StoreKit
class CardsViewController: UIViewController, ButtonRowDelegate {
    var equipment = [Equipment]()
    var selectedTypes = [EquipmentType]()
    private var cards = [Equipment]()
    var correctCard : Equipment? = nil
    var choices = [String]()
    private var correctChoiceIndex = 0
    var deckSize = 10
    var currentDeckIndex = -1
    var difficulty = Difficulty.EASY
    var incorrectGuesses = 0
    var totalGuesses = 0
    @IBOutlet weak var guessStackView: UIStackView!
    @IBOutlet weak var guessStackViewHeight: NSLayoutConstraint!
    var oneSecondTimer: Timer?
    var timeRemaining = 10.0
    override func viewDidLoad() {
        super.viewDidLoad()
        saveTabView(tabName: "Cards")
        resetTest()
        updateUi()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.initOneSecondTimer(start: false)
    }
    @IBOutlet weak var cardCountLabel: UILabel!
    @IBOutlet weak var equipmentImageView: UIImageView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    private func updateUi() {
        let current = getCurrentCardNumber().description
        let total = deckSize.description
        cardCountLabel.text = "\(current) of \(total)"
        if difficulty == Difficulty.EASY{
            timeRemainingLabel.isHidden = true
        }
        EquipmentRepository.setImage(equipmentImageView, correctCard?.photoUrl)
        createGuessRows()
    }
    var numRows = 0
    var rowHeight = 38
    func createGuessRow(choice0: String, choice1: String, choice2: String,
                        answer: String) {
        guard let guessRowView = Bundle.main.loadNibNamed("ButtonRow", owner: self, options: nil)?.first as? ButtonRow else {return}
        let frame = CGRect(x: 0, y: 0, width: Int(self.view.frame.width), height: rowHeight)
        guessRowView.frame = frame
        guessRowView.configure(option0: choice0,
                               option1: choice1,
                               option2: choice2, correctAnser: answer)
        guessRowView.delegate = self
        self.guessStackView.addArrangedSubview(guessRowView)
        numRows += 1
    }
    func adjustStackViewHeight(stackViewHeight: NSLayoutConstraint, numRows: Int, rowHeight: Int){
        guessStackViewHeight.constant = CGFloat(numRows * rowHeight)
        guessStackView.layoutIfNeeded()
    }
    func createGuessRows() {
        for view in guessStackView.subviews {view.removeFromSuperview()}
        var numEows = 0
        switch difficulty {
        case Difficulty.EASY : numEows = 1
        case Difficulty.MEDIUM : numEows = 2
        case Difficulty.HARD : numEows = 3 }
        for row in 0 ..< numEows {
            createGuessRow(choice0: choices[row * 3],
                           choice1: choices[row * 3 + 1],
                           choice2: choices[row * 3 + 2],
            answer: shorten(correctCard?.name))
        }
        adjustStackViewHeight(stackViewHeight: guessStackViewHeight,
                              numRows: numEows, rowHeight: rowHeight)
    }
    fileprivate let promptedKey = "PROMPTED"
    func buttonPressed(buttonText: String?) {
        let correct = checkGuessAndIncrementTotal(selectedAnswer: buttonText ?? "")
        if isEnd(){ 
            self.initOneSecondTimer(start: false)
            let percentage = calculateCorrectPercentage()
            saveQuizResults(categories: selectedTypes.description, score: percentage, difficulty: difficulty)
            let previouslyPrompted = UserDefaults.standard.bool(forKey: promptedKey) ?? false
            if percentage > 90 && !previouslyPrompted {
                showRequestRatingAlert(percentage)
            } else {
                showQuizCompleteAlert(percentage)
            }
            showQuizCompleteAlert(percentage)
        } else if correct || buttonText == nil { 
            setNextCardGetChoicesResetTimer()
            updateUi()
        }
    }
    fileprivate func showQuizCompleteAlert(_ percentage: Int) {
        let alert = UIAlertController(title: "Question and answer Completed", message: "You got \(percentage)% correct.", preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Q&A", style: .default) { (_) in
            self.resetTest()
            self.updateUi()
        }
        let changeAction = UIAlertAction(title: "Change Q&A", style: .default) { (_) in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(restartAction)
        alert.addAction(changeAction)
        self.present(alert, animated: true, completion: nil)
    }
    fileprivate let appId = "id1479007624"
    fileprivate func showRequestRatingAlert(_ percentage: Int) {
        UserDefaults.standard.set(true, forKey: promptedKey)
        let alert = UIAlertController(title: "Congratulations!", message: "You got \(percentage) correct.  Would you please rate the app? This will be the only time that you're prompted to leave a rating.", preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "No thanks", style: .default) { (_) in
            self.dismiss(animated: true, completion: nil)
        }
        let reviewAction = UIAlertAction(title: "Rate now", style: .default) { (_) in
            if #available( iOS 10.3,*){
                SKStoreReviewController.requestReview()
            } else {
                guard let url = URL(string: "itms-apps://itunes.apple.com/app/\(self.appId)") else {
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(dismissAction)
        alert.addAction(reviewAction)
        self.present(alert, animated: true, completion: nil)
    }
    private func getChoicesForDifficulty() -> Int {
        switch difficulty {
        case .EASY : return 3
        case .MEDIUM : return 6
        case .HARD : return 9}
    }
    private func generateChoices(correctCard: Equipment?){
        var possibleCards = equipment
        possibleCards.shuffle()
        var i = -1
        choices.removeAll()
        while (choices.count < getChoicesForDifficulty() && i < possibleCards.count - 1){
            i = i + 1
            if (possibleCards[i].name == correctCard?.name) {continue} 
            choices.append(shorten(possibleCards[i].name))
        }
        correctChoiceIndex = Int(arc4random_uniform(UInt32(getChoicesForDifficulty()-1)))
        choices[correctChoiceIndex] = shorten(correctCard?.name) 
    }
    func getCurrentCardNumber()->Int {return currentDeckIndex + 1}
    private func generateCards(){
        var possibleCards = equipment.filter { (e) -> Bool in return selectedTypes.contains(e.type)}
        if deckSize > possibleCards.count{
            cards.append(contentsOf: possibleCards)
            deckSize = possibleCards.count
        } else {
            possibleCards.shuffle()
            for i in 0 ..< deckSize {
                let card = possibleCards[i]
                cards.append(card)
            }
        }
    }
    func checkGuessAndIncrementTotal(selectedAnswer: String)->Bool{
        let correct = selectedAnswer == choices[correctChoiceIndex]
        totalGuesses = totalGuesses + 1
        if !correct {incorrectGuesses = incorrectGuesses + 1}
        return correct
    }
    func setNextCardGetChoicesResetTimer(){
        currentDeckIndex = currentDeckIndex + 1
        if currentDeckIndex >= cards.count {return}
        correctCard = cards[currentDeckIndex]
        generateChoices(correctCard: correctCard)
        resetTimer()
    }
    func isEnd()->Bool{
        return (currentDeckIndex == cards.endIndex - 1)
    }
    func calculateCorrectPercentage()-> Int{
        return Int((Double(totalGuesses - incorrectGuesses)) / Double(totalGuesses) * 100)
    }
    func resetTest(){
        totalGuesses = 0
        incorrectGuesses = 0
        currentDeckIndex = -1
        cards = [Equipment]()
        generateCards()
        setNextCardGetChoicesResetTimer()
    }
    let timeInterval = 0.5
    func initOneSecondTimer(start: Bool) {
        if(start) {
            if(self.oneSecondTimer == nil) {
                let t = Timer.scheduledTimer(timeInterval: timeInterval,target: self,selector: #selector(oneSecondUIRefresh), userInfo: nil,repeats: true)
                self.oneSecondTimer = t
            }
        } else {
            if(self.oneSecondTimer != nil) {
                self.oneSecondTimer?.invalidate()
                self.oneSecondTimer = nil
            }
        }
    }
    @objc func oneSecondUIRefresh() {
        timeRemaining = timeRemaining - timeInterval
        let timeText = String(format: "00:%02d", Int(timeRemaining))+" Remaining"
        timeRemainingLabel.text = timeText
        if timeRemaining < 1 {
            buttonPressed(buttonText: nil)
        }
    }
    private func resetTimer(){
        setTimeToDifficulty()
        self.initOneSecondTimer(start: true)
    }
    private func setTimeToDifficulty() {
        switch difficulty {
        case .EASY : timeRemaining = 999
        case .MEDIUM : timeRemaining = 11
        case .HARD : timeRemaining = 6}
    }
    private func shorten(_ longName: String?)-> String {
        if let descriptionStart = longName?.index(of: ";"){
            return String(longName?[..<descriptionStart] ?? "")
        } else {
            return longName ?? ""
        }
    }
    @IBAction func closeButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
