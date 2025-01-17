public class MaintenanceRequestHelper {
    
    public static void updateWorkOrders(List<Case> updatedWOs, Map<Id,Case> oldCaseMap){
        Set<Id> validWOIds = new Set<Id>(); //set of valid work order IDs 
        
        //going thru updatedWOs and checking if there is closed one AND of type repair/routine maintenance -> throw it into our Set then
        for (Case c: updatedWOs) {
            if (oldCaseMap.get(c.Id).Status != 'Closed' && c.Status == 'Closed') {
                if (c.Type == 'Repair' || c.Type == 'Routine Maintenance') {
                    validWOIds.add(c.Id);
                }
            }
        } 
        
        //If our Set is NOT empty,we calculate times  
        if (!validWOIds.isEmpty()) {
            List<Case> newCases = new List<Case>();
            //i didnt need the sql because i have the updatedWOIds already from the trigger
            Map<Id, Case>closedCaseMap = new Map<Id, Case>(updatedWOs);
        
            Map<Id, Decimal> maintCycleMap = new Map<Id, Decimal>();
            AggregateResult[] results = [SELECT Maintenance_Request__c, MIN(Equipment__r.Maintenance_Cycle__c)cycle
                                         FROM Equipment_Maintenance_Item__c 
                                         WHERE Maintenance_Request__c IN :validWOIds 
                                         GROUP BY Maintenance_Request__c];
            
            List<Equipment_Maintenance_Item__c> itemList = [SELECT Id, Maintenance_Request__c, Equipment__c
                                         FROM Equipment_Maintenance_Item__c 
                                         WHERE Maintenance_Request__c IN :validWOIds];
            
            //put every result into map with Id as key and Decimal as its value
            for (AggregateResult ar : results) {
                maintCycleMap.put((Id) ar.get('Maintenance_Request__c'), (Decimal) ar.get('cycle') );
            }
            
            //Creating new cases here
            for (Id caseId: validWOIds){
                Case cc = closedCaseMap.get(caseId);
                Case nc = new Case (ParentId = cc.Id,
                                    Status = 'New',
                                    Subject = 'Routine Maintenance',
                                    Type = 'Routine Maintenance',
                                    Vehicle__c = cc.Vehicle__c,
                                    Equipment__c = cc.Equipment__c,
                                    Origin = 'Web',  
                                    Date_Reported__c = Date.today());
                
                //calculating the maintenance request due dates
                nc.Date_Due__c = Date.today().addDays((Integer) maintCycleMap.get(cc.Id));
                newCases.add(nc);
            }
            
            insert newCases;
            

            List<Equipment_Maintenance_Item__c> copiedWorkParts = new List<Equipment_Maintenance_Item__c>();
            //cloning work parts here
            for (Case nc: newCases) {
                //going thru closedCaseMap and giving workparts right case ID
                for (Equipment_Maintenance_Item__c workparts: itemList) {
                    if (workparts.Maintenance_Request__c == nc.ParentId){
                       Equipment_Maintenance_Item__c newWorkPart = new Equipment_Maintenance_Item__c();
                       newWorkPart.Maintenance_Request__c = nc.Id;
                       newWorkPart.Equipment__c = workparts.Equipment__c;
                       copiedWorkParts.add(newWorkPart); 
                    }
                }
            }
            insert copiedWorkParts;
        }     
    }
}