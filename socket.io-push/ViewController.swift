//
//  ViewController.swift
//  misakaDemo
//
//  Created by crazylhf on 15/10/26.
//  Copyright © 2015年 crazylhf. All rights reserved.
//

import UIKit

class ViewController: UIViewController, PushCallbackDelegate{
    
    let url = "http://spush.yy.com/api/push?pushAll=true&topic=chatRoom&json=%@&timeToLive="
    
    private var socketIOClient:SocketIOProxyClientOC!
    private var lastTimestamp = NSDate()
    
    private let msgType = "chat_message"
    
    @IBOutlet weak var textFieldBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var chatTextField: UITextField!
    @IBOutlet weak var chatTableView: UITableView!
    weak var tapView : UIView?
    let reuseId = "chatContentCell"
    
    var userName : String!
    
    private var chats : [ChatInfo]!
    
    
    
    //MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
         
        if AppDelegate.isTesting() {
            return
        }
        socketIOClient = (UIApplication.sharedApplication().delegate as! AppDelegate).socketIOClient
        socketIOClient.pushCallbackDelegate = self
        socketIOClient.subscribeBroadcast("chatRoom")
        
        self.chatTableView.separatorColor = UIColor.clearColor()
        
        if #available(iOS 8.0, *) {
            let userNameInputAlert = UIAlertController(title: "用户名", message: "userName", preferredStyle: .Alert)
            
            
            userNameInputAlert.addTextFieldWithConfigurationHandler({ [unowned self](textField) in
                textField.placeholder = "Input user name"
                textField.delegate = self
                })
            
            let ok = UIAlertAction(title: "ok", style: .Default, handler: { [unowned self] (action) in
                self.userName = userNameInputAlert.textFields?[0].text
                NSLog("\(userNameInputAlert.textFields![0].text)")
                })
            
            userNameInputAlert.addAction(ok)
            self.presentViewController(userNameInputAlert, animated: true, completion: nil)
        } else {
            // Fallback on earlier versions
            let userNameInputAlert = UIAlertView(title: "用户名", message: "userName", delegate: self, cancelButtonTitle: "ok")
            userNameInputAlert.alertViewStyle = .PlainTextInput
            userNameInputAlert.textFieldAtIndex(0)?.delegate = self
            userNameInputAlert.show()
        }
        
        self.registerKeyboardNotifications()
        self.addTapView()
        
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        self.tapView?.frame = self.chatTableView.frame
    }
    
    
    func onDisconnect(){
        print("onDisconnect");
        self.navigationItem.title = "Disconnected"
    }
    
    func onConnect(uid: String!, tags: [AnyObject]!) {
        print("onConnect \(uid)");
        let data:[String:String] = [
            "uid" : "123",
            "token" : "test"
        ]
        
        (UIApplication.sharedApplication().delegate as! AppDelegate).socketIOClient.bindUid(data)
        self.navigationItem.title = "Connected"
    }
    
    func onPush(data: NSData) {
        
        var dataDic : NSDictionary?
        do{
            dataDic = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? NSDictionary
        }catch _{
            return
        }
        
        self.parseChatDic(dataDic)

        
    }
    
    func log(level: String, message: String) {
        NSLog("Level : \(level) , message : \(message)")
    }
    
    //MARK: - Helpers
    
    func registerKeyboardNotifications(){
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillChange), name: UIKeyboardWillChangeFrameNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillHide), name: UIKeyboardWillHideNotification, object: nil)
        
    }
    
    
    func sendChat(msg:String){
        
        let message = msg
        
        
        let chatDic = [
            "nickName" : self.userName,
            "message" : message,
            "type" : msgType
        ]
        
        var jsonData : NSData! = nil
        do{
            
            jsonData = try NSJSONSerialization.dataWithJSONObject(chatDic, options: .PrettyPrinted)
        }catch _{
            return
        }
        
        guard let jsonStr = NSString(data: jsonData, encoding: NSUTF8StringEncoding) else{
            return
        }
        
        let set : NSMutableCharacterSet = NSMutableCharacterSet.alphanumericCharacterSet()
        
        guard let encodedStr = jsonStr.stringByAddingPercentEncodingWithAllowedCharacters(set) else{
            return
        }
        
        let jsonUrl = String(format: url, encodedStr)
        
        guard let reqUrl = NSURL(string: jsonUrl)  else{
            return
        }
        let urlReq = NSURLRequest(URL: reqUrl)
        
        let manager = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let dataTask = manager.dataTaskWithRequest(urlReq)
        
        dataTask.resume()
    }
    
    
    func parseChatDic(dic:NSDictionary?){
        if let dataDic = dic {
            
            let chatInfo = ChatInfo()
            chatInfo.nickName = dataDic["nickName"] as? String
            chatInfo.message = dataDic["message"] as? String
            chatInfo.type = dataDic["type"] as? String
            
            if chatInfo.type != msgType {
                return
            }
            
            if chats == nil {
                chats = [ChatInfo]()
            }
            
            let idx = NSIndexPath(forRow: chats.count, inSection: 0)
            chats.append(chatInfo)
            self.chatTableView.insertRowsAtIndexPaths([idx], withRowAnimation: .Fade)
            self.chatTableView.scrollToRowAtIndexPath(idx, atScrollPosition: .Bottom, animated: true)
        }
    }
    
    func addTapView(){
        if self.tapView == nil {
            let view = UIView()
            self.view.addSubview(view)
            self.tapView = view
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
            self.tapView?.addGestureRecognizer(tap)
        }
    }
    
    func hideKeyboard(){
        self.chatTextField.resignFirstResponder()
    }
    
    
}


//MARK: - TableView Data Source
extension ViewController:UITableViewDataSource{
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats == nil ?  0 :chats!.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell : UITableViewCell! = tableView.dequeueReusableCellWithIdentifier(reuseId)
        if cell == nil {
            cell = UITableViewCell(style: .Default , reuseIdentifier: reuseId)
        }
        
        let chat = chats[indexPath.row]
        cell.textLabel?.text = chat.nickName + ":" + chat.message
        
        
        return cell
    }
}

//MARK: - TableView Delegate
extension ViewController:UITableViewDelegate{
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}


//MARK: - UITextField Delegate

extension ViewController:UITextFieldDelegate{
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
        if textField == self.chatTextField{
            
            sendChat(textField.text!)
            
            textField.text = ""
        }
            
        else{
            if textField.text == nil || textField.text == "" {
                return false
            }
            self.userName = textField.text
        }
        
        //        textField.resignFirstResponder()
        return true
    }
    
}



//MARK: - Notification Callbacks

extension ViewController{
    func keyboardWillChange(noti:NSNotification){
        
        if !self.chatTextField.isFirstResponder(){
            return
        }
        if let height = (noti.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue().height{
            if height > 0 {
                self.tapView?.hidden = false
            }
            self.textFieldBottomConstraint.constant = height
            self.chatTextField.setNeedsLayout()
            var idx = -1
            if self.chats != nil && self.chats.count > 0 {
                idx = self.chats.count - 1
            }
            UIView.animateWithDuration(0.25){
                [unowned self] in
                self.view.layoutIfNeeded()
                if idx  >= 0{
                    let index = NSIndexPath(forRow: idx, inSection: 0)
                    
                    self.chatTableView.scrollToRowAtIndexPath(index, atScrollPosition: .Bottom, animated: true)
                }
                
            }
            
        }
    }
    
    func keyboardWillHide(noti:NSNotification){
        self.tapView?.hidden = true
        UIView.animateWithDuration(0.25){
            [unowned self] in
            self.textFieldBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
            
        }
    }
}
