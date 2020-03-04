//
//  ViewControllerDisk.swift
//  HackintoshBuild
//
//  Created by bugprogrammer on 2020/1/22.
//  Copyright © 2020 bugprogrammer. All rights reserved.
//

import Cocoa

class ViewControllerDisk: NSViewController {
    
    @objcMembers class DiskInfoObject: NSObject {
        dynamic var name: String = ""
        dynamic var type: String = ""
        dynamic var mounted: String = ""
        dynamic var size: String = ""
        dynamic var bsd: String = ""
        dynamic var isboot: String = ""
        
        init(_ name: String, _ type: String, _ mounted: String, _ size: String, _ bsd: String, _ isboot: String) {
            self.name = name
            self.type = type
            self.mounted = mounted
            self.size = size
            self.bsd = bsd
            self.isboot = isboot
        }
    }
    
    @objc dynamic var diskInfoObject: [DiskInfoObject] = []
        
    @IBOutlet weak var diskTableView: NSTableView!
    @IBOutlet weak var refreshButton: NSButton!
    
    var diskInfo:String = ""
    var arrayPartition:[String] = []
    var index: Int = 0
    let taskQueue = DispatchQueue.global(qos: .background)
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        refreshButton.isEnabled = false
        arrayPartition = []
        diskInfoObject = []
        diskTableView.reloadData()
        runBuildScripts("diskInfo",[])
    }
    
    @IBAction func diskTools(_ sender: NSButton) {
        index = diskTableView.row(for: sender)

        refreshButton.isEnabled = false
        if diskInfoObject[index].mounted == "未挂载" {
            runBuildScripts("diskMount", [diskInfoObject[index].bsd])
        }
        else {
            runBuildScripts("diskUnmount", [diskInfoObject[index].bsd])
        }

    }
    
    @IBAction func Refresh(_ sender: Any) {
        refreshButton.isEnabled = false
        arrayPartition = []
        diskInfoObject = []
        diskTableView.reloadData()
        runBuildScripts("diskInfo",[])
    }
    func runBuildScripts(_ shell: String,_ arguments: [String]) {
        AraHUDViewController.shared.showHUDWithTitle(title: "正在进行中")
        taskQueue.async {
            if let path = Bundle.main.path(forResource: shell, ofType:"command") {
                let task = Process()
                task.launchPath = path
                task.arguments = arguments
                task.environment = ["PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:"]
                task.terminationHandler = { task in
                    DispatchQueue.main.async(execute: { [weak self] in
                        guard let `self` = self else { return }
                        AraHUDViewController.shared.hideHUD()
                        if shell == "diskInfo" {
                            MyLog(self.diskInfo)
                            self.arrayPartition = self.diskInfo.components(separatedBy:"\n")
                            if self.arrayPartition.last == "" {
                                self.arrayPartition.removeLast()
                            }
                            if self.arrayPartition.first == "" {
                                self.arrayPartition.removeFirst()
                            }
                            
                            for i in 0..<self.arrayPartition.count-1 {
                                var diskFinal = self.arrayPartition[i].components(separatedBy: ":")
                                if diskFinal.last == self.arrayPartition.last {
                                    diskFinal.append("当前引导分区")
                                }
                                if diskFinal.count < 6 {
                                    diskFinal.append("")
                                }
                                self.diskInfoObject.append(DiskInfoObject(diskFinal[0],diskFinal[1],NSLocalizedString(diskFinal[2], comment: ""),diskFinal[3],diskFinal[4],diskFinal[5]))
                                MyLog(diskFinal.count)
                                MyLog(diskFinal)
                            }
                            if !self.arrayPartition.last!.contains(" ") {
                                self.arrayPartition.removeLast()
                            }
                            self.diskTableView.reloadData()
                        } else if shell == "diskMount" {
                            let alert = NSAlert()
                            if self.diskInfo.contains("mounted") {
                                alert.messageText = "EFI 挂载成功"
                                self.diskInfoObject[self.index].mounted = "已挂载"
                                self.diskTableView.reloadData()
                            } else {
                                alert.messageText = "EFI 挂载失败"
                            }
                            alert.runModal()
                        }
                        else {
                            let alert = NSAlert()
                            if self.diskInfo.contains("unmounted") {
                                alert.messageText = "EFI 卸载成功"
                                self.diskInfoObject[self.index].mounted = "未挂载"
                                self.diskTableView.reloadData()
                            } else {
                                alert.messageText = "EFI 挂载失败"
                            }
                            alert.runModal()
                        }
                        self.refreshButton.isEnabled = true
                    })
                }
                self.taskOutPut(task)
                task.launch()
                task.waitUntilExit()
            }
        }
    }
    
    func taskOutPut(_ task:Process) {
        diskInfo = ""
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading, queue: nil) { notification in
            let output = outputPipe.fileHandleForReading.availableData
            if output.count > 0 {
                outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
                let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
                DispatchQueue.main.async(execute: {
                    let previousOutput = self.diskInfo
                    let nextOutput = previousOutput + outputString
                    self.diskInfo = nextOutput
                })
            }
        }
    }
}

class MountCell: NSTableCellView {
    @IBOutlet weak var mountButton: NSButton!
}

extension ViewControllerDisk: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return diskInfoObject.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return diskInfoObject[row]
    }
    
}