//
//  ViewController.swift
//  mPower2
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit
import BridgeAppUI
import DataTracking

class MainViewController: UITableViewController, RSDTaskViewControllerDelegate {
    
    let taskGroups: [RSDTaskGroup] = {
        
        let trackingTaskGroup : RSDTaskGroup = {
            
            var triggersInfo = RSDTaskInfoObject(with: "Triggers")
            triggersInfo.title = "Triggers"
            triggersInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: "Triggers")
            
            var symptomsInfo = RSDTaskInfoObject(with: "Symptoms")
            symptomsInfo.title = "Symptoms"
            symptomsInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: "Symptoms")
            
            var medicationInfo = RSDTaskInfoObject(with: "Medication")
            medicationInfo.title = "Medication"
            medicationInfo.resourceTransformer = RSDResourceTransformerObject(resourceName: "Medication")
            
            return RSDTaskGroupObject(with: "Tracking", tasks: [triggersInfo, symptomsInfo, medicationInfo])
        }()
        
        return [trackingTaskGroup]
    }()
    
    let scheduleManager = ClientDataScheduleManager()
    
    // MARK: Table data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.taskGroups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.taskGroups[section].tasks.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.taskGroups[section].title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let taskInfo = taskGroups[indexPath.section].tasks[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath)
        cell.textLabel?.text = taskInfo.title ?? taskInfo.identifier
        return cell
    }
    
    // MARK: Table delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let taskGroup = taskGroups[indexPath.section]
        let taskInfo = taskGroup.tasks[indexPath.row]
        let (taskPath, _) = scheduleManager.instantiateTaskViewModel(for: taskInfo, in: nil)
        let vc = RSDTaskViewController(taskViewModel: taskPath)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        if reason == .completed {
            // The schedule activity manager does this using reflection, but for simplicity, let's find the last MedicationTrackingResult
            var medTrackingResult: SBAMedicationTrackingResult?
            for result in taskController.taskViewModel.taskResult.stepHistory {
                if let medTrackingResultUnwrapped = result as? SBAMedicationTrackingResult {
                    medTrackingResult = medTrackingResultUnwrapped
                }
            }
            if let medTrackingResultUnwrapped = medTrackingResult {
                do {
                    if let dataScore = try medTrackingResultUnwrapped.dataScore() {
                        self.scheduleManager.previousReport[taskController.taskViewModel.taskResult.identifier] =
                            SBAReport(identifier: taskController.taskViewModel.taskResult.identifier, date: taskController.taskViewModel.taskResult.endDate.startOfDay(), json: dataScore)
                    }
                } catch {
                    print(error)
                }
            }
        }
        
        // dismiss the view controller
        (taskController as? UIViewController)?.dismiss(animated: true) {
        }
        
        print("\n\n=== Completed: \(reason) error:\(String(describing: error))")
        print(taskController.taskViewModel.taskResult)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        
    }
    
    func taskViewController(_ taskViewController: UIViewController, shouldShowTaskInfoFor step: Any) -> Bool {
        return false
    }
}

open class ClientDataScheduleManager: SBAScheduleManager {
    
    /// The previous client data for the tasks
    var previousReport = [String : SBAReport]()
    
    override open func report(with activityIdentifier: String) -> SBAReport? {
        return previousReport[activityIdentifier]
    }
    
    override open func fetchRequests() -> [FetchRequest] {
        return []
    }
}

