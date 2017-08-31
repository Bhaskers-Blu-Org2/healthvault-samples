//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the ""Software""), to deal
//  in the Software without restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
//  and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
//  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.

import Foundation
import HealthVault
import UserNotifications

class ReminderManager: NSObject
{
    private var dataSource: ReminderManagerDataSource
    private var notificationDelegate: UNUserNotificationCenterDelegate

    private let notificationCenter = UNUserNotificationCenter.current()
    private var isAuthorized = false
    private var isUpdatingReminders = false
    private var isUpdatingRemindersLock = NSObject()
        
    private let dayOfWeekMap = [MHVScheduleScheduledDaysEnum.mhvSunday() : 1,
                                MHVScheduleScheduledDaysEnum.mhvMonday() : 2,
                                MHVScheduleScheduledDaysEnum.mhvTuesday() : 3,
                                MHVScheduleScheduledDaysEnum.mhvWednesday() : 4,
                                MHVScheduleScheduledDaysEnum.mhvThursday() : 5,
                                MHVScheduleScheduledDaysEnum.mhvFriday() : 6,
                                MHVScheduleScheduledDaysEnum.mhvSaturday() :  7]
    
    private let reminderOffsetMap = [MHVScheduleReminderStateEnum.mhvBefore5Minutes() : 5,
                                     MHVScheduleReminderStateEnum.mhvBefore10Minutes() : 10,
                                     MHVScheduleReminderStateEnum.mhvBefore15Minutes() : 15,
                                     MHVScheduleReminderStateEnum.mhvBefore30Minutes() : 30,
                                     MHVScheduleReminderStateEnum.mhvBefore1Hour() : 60,
                                     MHVScheduleReminderStateEnum.mhvBefore2Hours() : 120,
                                     MHVScheduleReminderStateEnum.mhvBefore4Hours() :  240,
                                     MHVScheduleReminderStateEnum.mhvBefore8Hours() :  480]
    
    // MARK: - Initialization & setup

    init(dataSource: ReminderManagerDataSource,
         notificationDelegate: UNUserNotificationCenterDelegate)
    {
        self.dataSource = dataSource
        self.notificationDelegate = notificationDelegate

        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateReminders), name: Constants.TasksChangedNotification, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Start the ReminderManager and request authorization from the user to show reminders
    ///
    /// - Parameter dataSource: Provides data for the notifications
    /// - Parameter notificationDelegate: Handle notification actions
    /// - Parameter completion: Completion called when the authorization state is known
    public func requestAuthorization(completion: @escaping (_ authorized: Bool) -> Void)
    {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        { (authorized, error) in
            
            print("Notifications Authorized: \(authorized)")
            
            self.isAuthorized = authorized
            
            self.notificationCenter.delegate = self.notificationDelegate
            
            if authorized
            {
                self.notificationCenter.setNotificationCategories(self.dataSource.notificationCategories())
                
                // Authorized, update reminders
                self.updateReminders()
            }
            
            completion(authorized)
        }
    }
    
    /// This should be called as part of the sign out process.
    public func removeAllNotifications()
    {
        self.notificationCenter.removeAllDeliveredNotifications()
        self.notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// Show an error notification, schedule a one-time notification 1 second in the future
    public func showErrorNotification(title: String, message: String)
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default()
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest.init(identifier: "Error",
                                                 content: content,
                                                 trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        { (error: Error?) in
            
            if error != nil
            {
                print("Error adding notification: \(error!.localizedDescription)")
            }
        }
    }
    
    // MARK: - HealthVault

    /// Get the list of current Action Plan tasks from the data source and update the scheduled reminders
    public func updateReminders()
    {
        if !isAuthorized
        {
            return
        }
        
        // Limit to not update reminders if an update is already in progress
        objc_sync_enter(isUpdatingRemindersLock)
        if (self.isUpdatingReminders)
        {
            objc_sync_exit(isUpdatingRemindersLock)
            return
        }
        self.isUpdatingReminders = true
        objc_sync_exit(isUpdatingRemindersLock)
        
        dataSource.tasksForReminders()
            {
                (tasks, error) in
                
                if error != nil
                {
                    // If error, don't change the current reminders & done
                    objc_sync_enter(self.isUpdatingRemindersLock)
                    self.isUpdatingReminders = false
                    objc_sync_exit(self.isUpdatingRemindersLock)
                }
                else if tasks == nil || tasks?.count == 0
                {
                    // No errors, but tasks is nil or empty, remove all reminders & done
                    self.removeAllNotifications()
                    
                    objc_sync_enter(self.isUpdatingRemindersLock)
                    self.isUpdatingReminders = false
                    objc_sync_exit(self.isUpdatingRemindersLock)
                }
                else
                {
                    self.notificationCenter.removeAllDeliveredNotifications()
                    
                    self.notificationCenter.getPendingNotificationRequests
                        {
                            (notifications: [UNNotificationRequest]) in
                            
                            print("\(notifications.count) current notifications")
                            
                            self.updateNotifications(notifications: notifications, tasks: tasks!)
                            {
                                objc_sync_enter(self.isUpdatingRemindersLock)
                                self.isUpdatingReminders = false
                                objc_sync_exit(self.isUpdatingRemindersLock)
                            }
                    }
                }
        }
    }
    
    // Match existing notifications with task reminders to add/remove notifications
    private func updateNotifications(notifications: [UNNotificationRequest], tasks: [MHVActionPlanTaskInstance]?, completion: @escaping () -> Void)
    {
        // Updating can occur on a background queue
        DispatchQueue.global().async
            {
                // Add new reminders and remove obsolete reminders, but leaves any active reminders in place.
                // This lets any reminders show if the updates are happening at a reminder's time.
                
                // 1. Make mapping of current reminders.
                //    For each reminder, check if its identifier is in the notification map.
                //    If it is, then the reminder is current and can be removed from the mapping.
                //    If it is not, then the reminder is added
                //
                //    At the end, any leftover reminders in the mapping are obsolete and are deleted
                var notificationMap = [String: UNNotificationRequest]()
                
                notifications.forEach({ (notificationRequest) in
                    notificationMap[notificationRequest.identifier] = notificationRequest
                })
                
                var addNotifications = [UNNotificationRequest]()
                
                // 2. Loop through tasks -> schedules -> scheduledDays
                //    Iterate through each task
                tasks!.forEach({ (task) in
                    
                    guard let schedules = task.schedules,
                          let taskIdentifier = task.identifier else
                    {
                        return
                    }
                    
                    // Iterate through each schedule on the task
                    schedules.forEach({ (schedule) in
                        
                        if schedule.reminderState == MHVScheduleReminderStateEnum.mhvOff() ||
                           schedule.reminderState == MHVScheduleReminderStateEnum.mhvUnknown()
                        {
                            return
                        }
                        
                        guard let scheduledDays = schedule.scheduledDays,
                              let scheduledTime = schedule.scheduledTime else
                        {
                            return
                        }
                        
                        // Iterate through each scheduledDay on the schedule
                        scheduledDays.forEach({ (dayEnum) in
                            
                            // Build an identifier for the combination of taskId, time, dayEnum, and reminderState
                            let taskScheduleId = ".\(taskIdentifier)--\(dayEnum.stringValue)--\(scheduledTime.toString())--\(schedule.reminderState.stringValue)"
                            
                            if notificationMap[taskScheduleId] != nil
                            {
                                // Already scheduled this task's reminder, don't need to change it.
                                // Remove from map to determine leftover obsolete reminders at the end
                                notificationMap[taskScheduleId] = nil
                            }
                            else
                            {
                                if let content = self.dataSource.notificationContent(task: task, schedule: schedule, dayEnum: dayEnum)
                                {
                                    // Not found, build notification request for the day/time combination
                                    var components = DateComponents()
                                    components.weekday = self.dayOfWeekMap[dayEnum]
                                    components.hour = Int(scheduledTime.hour)
                                    components.minute = Int(scheduledTime.minute)
                                    
                                    components = self.offsetDateComponentsForReminder(components: components, reminderState: schedule.reminderState)
                                    
                                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                                
                                    addNotifications.append(UNNotificationRequest.init(identifier: taskScheduleId,
                                                                                       content: content,
                                                                                       trigger: trigger))
                                }
                            }
                        })
                    })
                })
                
                // 3. Add new notifications
                print("\(addNotifications.count) notifications to be added")
                addNotifications.forEach({ (notificationRequest) in
                    
                    self.notificationCenter.add(notificationRequest)
                    { (error: Error?) in
                        
                        if error != nil
                        {
                            print("Error adding notification: \(error!.localizedDescription)")
                        }
                    }
                })
                
                // 4. Remove any old obsolete notifications (tasks that were deleted, etc)
                print("\(notificationMap.keys.count) notifications to be removed")
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(notificationMap.keys))

                // Done, perform completion handler
                completion()
        }
    }
    
    // Offset a date component by the reminderState to get the adjusted reminder time
    private func offsetDateComponentsForReminder(components: DateComponents, reminderState: MHVScheduleReminderStateEnum) -> DateComponents
    {
        var components = components
        
        if components.hour == nil || components.minute == nil
        {
            return components
        }
        
        guard let offsetMinutes = reminderOffsetMap[reminderState] else
        {
            return components
        }
        
        var baseDateComponents = DateComponents()
        
        // May 2016 has Sunday the 1st (to match components.weekday where Sunday = 1) and was not near daylight savings time
        baseDateComponents.year = 2016
        baseDateComponents.month = 5
        baseDateComponents.day = components.weekday ?? 1
        baseDateComponents.hour = components.hour
        baseDateComponents.minute = components.minute
        
        guard let baseDate = Calendar.current.date(from: baseDateComponents) else
        {
            return components
        }
        
        // Adjust base date by the reminder offset
        let offsetDate = baseDate.addingTimeInterval(TimeInterval(offsetMinutes * -60))
        
        // Return components, only include .weekday if it as in the initial components
        if components.weekday != nil
        {
            return Calendar.current.dateComponents([.hour, .minute, .weekday], from: offsetDate)
        }
        else
        {
            return Calendar.current.dateComponents([.hour, .minute], from: offsetDate)
        }
    }
}