SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispAutoClosePickedTMTask]   
AS  
BEGIN  
 SET NOCOUNT ON    
 SET QUOTED_IDENTIFIER OFF    
 SET ANSI_NULLS OFF    
 SET CONCAT_NULL_YIELDS_NULL OFF    
  
 DECLARE @cTaskDetailKey   NVARCHAR(10)  
 SET @cTaskDetailKey = ''
   
 DECLARE CUR_TaskDetailKeyUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
 SELECT TASKDETAIL.TaskDetailKey   
 FROM PICKDETAIL WITH (NOLOCK)    
 JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = PICKDETAIL.TaskDetailKey   
        AND TASKDETAIL.TaskType='PK'   
        AND TASKDETAIL.PickMethod IN ('DOUBLES','MULTIS')   
 WHERE PICKDETAIL.Status >= '5'   
 AND TASKDETAIL.[Status] IN ('0','3')   
 AND PICKDETAIL.EditDate < DATEADD(minute, -10, GETDATE())  
   
 OPEN CUR_TaskDetailKeyUpdate   
   
 FETCH NEXT FROM CUR_TaskDetailKeyUpdate INTO @cTaskDetailKey   
 WHILE @@FETCH_STATUS <> -1  
 BEGIN  
      PRINT '1. Updating TaskDetailKey=' + @cTaskDetailKey  
      UPDATE TASKDETAIL   
         SET [STATUS] = '9', TASKDETAIL.UserKey = 'wms', TASKDETAIL.TrafficCop = NULL    
      FROM TASKDETAIL   
       JOIN   PICKDETAIL  WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = PICKDETAIL.TaskDetailKey   
              AND TASKDETAIL.TaskType='PK'   
              AND TASKDETAIL.PickMethod IN ('DOUBLES','MULTIS')          
      WHERE PICKDETAIL.Status = '5'   
      AND   TASKDETAIL.TaskDetailKey = @cTaskDetailKey   
      AND   TASKDETAIL.[Status] IN ('0','3')   
      
    FETCH NEXT FROM CUR_TaskDetailKeyUpdate INTO @cTaskDetailKey  
 END  
 CLOSE CUR_TaskDetailKeyUpdate  
 DEALLOCATE CUR_TaskDetailKeyUpdate  
   
   
 DECLARE CUR_TaskDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
 SELECT TASKDETAIL.TaskDetailKey   
 FROM   PICKDETAIL (NOLOCK)  
 JOIN   TASKDETAIL WITH (NOLOCK) ON TASKDETAIL.TaskDetailKey = PICKDETAIL.TaskDetailKey   
        AND TASKDETAIL.TaskType='PK'   
        AND TASKDETAIL.PickMethod IN ('PIECE','CASE','SINGLES')   
 WHERE PICKDETAIL.Status >= '5'  
 AND PICKDETAIL.EditDate < DATEADD(minute, -10, GETDATE())   
 AND TASKDETAIL.[Status] IN ('0','3')   
        
OPEN  CUR_TaskDetailKey   
  
FETCH NEXT FROM CUR_TaskDetailKey INTO @cTaskDetailKey   
WHILE @@FETCH_STATUS <> -1  
BEGIN  
    IF NOT EXISTS(SELECT 1 FROM PICKDETAIL p (NOLOCK)   
                  WHERE p.TaskDetailKey = @cTaskDetailKey   
                  AND   P.Status < '5')  
    BEGIN  
       PRINT 'Updating TaskDetailKey=' + @cTaskDetailKey  
         
       UPDATE TASKDETAIL WITH (ROWLOCK)   
          SET [STATUS] = '9', TASKDETAIL.UserKey = 'wms', TASKDETAIL.TrafficCop = NULL  
       WHERE TaskDetailKey = @cTaskDetailKey   
       AND   TASKDETAIL.[Status] IN ('0','3')  
    END           
    FETCH NEXT FROM CUR_TaskDetailKey INTO @cTaskDetailKey   
 END  
 CLOSE CUR_TaskDetailKey  
 DEALLOCATE CUR_TaskDetailKey  
END

GO