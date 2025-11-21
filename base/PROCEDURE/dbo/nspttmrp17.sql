SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/************************************************************************/    
/* Stored Procedure: nspTTMRP17                                         */    
/* Copyright: Maersk                                                    */    
/*                                                                      */    
/* Purpose: TM Replenishment Strategy                                   */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Author    Ver  Purposes                                  */    
/* 13-01-2020  YeeKung   1.0  TTMRP02->TTMRP17 (WMS-11247)              */   
/* 23-08-2023  Ung       1.1  WMS-23369 Add UserKeyOverRide             */
/************************************************************************/    
CREATE   PROC [dbo].[nspTTMRP17]    
    @c_UserID    NVARCHAR(18)    
   ,@c_AreaKey01 NVARCHAR(10)    
   ,@c_AreaKey02 NVARCHAR(10)    
   ,@c_AreaKey03 NVARCHAR(10)    
   ,@c_AreaKey04 NVARCHAR(10)    
   ,@c_AreaKey05 NVARCHAR(10)    
   ,@c_LastLOC   NVARCHAR(10)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE     
       @b_debug      INT    
      ,@n_starttcnt  INT -- Holds the current transaction count    
      ,@n_continue   INT    
      ,@b_Success    INT    
      ,@n_err        INT    
      ,@c_errmsg     NVARCHAR(250)    
      ,@c_TaskDetailkey NVARCHAR(10)    
      ,@c_LastLOCAisle  NVARCHAR(10)    
      ,@c_Storerkey  NVARCHAR(10)  
      ,@c_c_UCCQTY   INT  
      ,@c_QtyAvaiable INT  
      ,@n_endtcnt INT  
          
    SELECT     
       @b_debug = 0    
      ,@n_starttcnt = @@TRANCOUNT    
      ,@n_continue = 1    
      ,@b_success = 0    
      ,@n_err = 0    
      ,@c_errmsg = ''    
      ,@c_TaskDetailkey = ''    
      ,@c_LastLOCAisle = ''    
          
   -- Reset in-progress task, to be refetch, if connection broken    
   UPDATE TaskDetail SET    
      Status = '0'    
   WHERE UserKey = @c_UserID    
      AND Status = '3'    
   IF @@ERROR <> 0    
   BEGIN    
      SET @n_continue = 3    
      SET @n_err = 81201    
      SET @c_errmsg = 'NSQL' + CONVERT( NVARCHAR(5), @n_err) + ': ' +     
                      'Update to TaskDetail table failed. (nspTTMRP17)' +     
                      '(SQLSvr MESSAGE = ' + RTRIM( @c_errmsg) + ' )'    
   END    
    
   -- Close cursor    
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (0, 1) -- 0=empty, 1=record    
      CLOSE Cursor_RPFTaskCandidates    
   IF CURSOR_STATUS( 'global', 'Cursor_RPFTaskCandidates') IN (-1)   -- -1=cursor is closed    
      DEALLOCATE Cursor_RPFTaskCandidates    
    
   -- Get Last LOCAisle    
   SELECT @c_LastLOCAisle = LOCAisle FROM LOC WITH (NOLOCK) WHERE LOC = @c_LastLOC    
    
   IF @c_AreaKey01 <> ''    
      DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor    
         SELECT TaskDetailkey    
         FROM dbo.TaskDetail WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)    
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)    
         WHERE AreaDetail.AreaKey = @c_AreaKey01    
            AND TaskDetail.TaskType IN ('RPF', 'RP1')    
            AND TaskDetail.Status = '0'    
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND EXISTS( SELECT 1     
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)    
               WHERE PermissionType = TaskDetail.TASKTYPE    
                 AND tmu.UserKey = @c_UserID    
                 AND tmu.AreaKey = @c_AreaKey01    
                 AND tmu.Permission = '1')    
         ORDER BY    
             TaskDetail.Priority    
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END    
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END    
            ,LOC.LogicalLocation    
            ,LOC.LOC    
   ELSE    
      DECLARE Cursor_RPFTaskCandidates CURSOR FAST_FORWARD READ_ONLY FOR --Note: global cursor     
         SELECT TaskDetailkey    
         FROM dbo.TaskDetail WITH (NOLOCK)    
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)    
            JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)    
         WHERE dbo.TaskDetail.TaskType IN ('RPF', 'RP1')    
            AND TaskDetail.Status = '0'    
            AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')
            AND EXISTS( SELECT 1     
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)    
               WHERE PermissionType = TaskDetail.TASKTYPE    
                 AND tmu.UserKey = @c_UserID    
                 AND tmu.AreaKey = @c_AreaKey01    
                 AND tmu.Permission = '1')    
         ORDER BY    
             TaskDetail.Priority    
            ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END    
            ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END    
            ,LOC.LogicalLocation    
            ,LOC.LOC    
  
   DECLARE  @c_FromLOC NVARCHAR(20),      
            @c_FromID NVARCHAR(20),      
            @c_FromLot NVARCHAR(20),      
            @c_Pickmethod NVARCHAR(5),      
            @c_LocCount INT      
         
   IF @c_AreaKey01 <> ''       
   BEGIN       
      SELECT TOP 1 @c_Storerkey = TaskDetail.Storerkey, @c_TaskDetailkey=TaskDetail.TaskDetailkey,@c_FromLOC=TaskDetail.FromLOC,      
      @c_Pickmethod=taskdetail.PickMethod, @c_FromLot=TaskDetail.Lot,@c_FromID =TaskDetail.FromID        
      FROM dbo.TaskDetail WITH (NOLOCK)        
         JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)        
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)        
      WHERE AreaDetail.AreaKey = @c_AreaKey01        
      AND TaskDetail.TaskType IN ('RPF')        
      AND TaskDetail.Status = '0'   
      AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')     
      AND EXISTS( SELECT 1         
         FROM TaskManagerUserDetail tmu WITH (NOLOCK)        
         WHERE PermissionType = TaskDetail.TASKTYPE        
            AND tmu.UserKey = @c_UserID        
            AND tmu.AreaKey = @c_AreaKey01        
            AND tmu.Permission = '1')      
      ORDER BY        
         TaskDetail.Priority        
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END        
         ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END        
         ,LOC.LogicalLocation        
         ,LOC.LOC       
   END      
   ELSE      
   BEGIN       
     SELECT TOP 1 @c_Storerkey = TaskDetail.Storerkey , @c_TaskDetailkey=TaskDetail.TaskDetailkey,@c_FromLOC=TaskDetail.FromLOC,      
      @c_Pickmethod=taskdetail.PickMethod, @c_FromLot=TaskDetail.Lot,@c_FromID =TaskDetail.FromID        
      FROM dbo.TaskDetail WITH (NOLOCK)        
         JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)        
         JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)        
      WHERE TaskDetail.TaskType IN ('RPF')        
      AND TaskDetail.Status = '0'   
      AND TaskDetail.UserKeyOverRide IN (@c_UserID, '')     
      AND EXISTS( SELECT 1         
         FROM TaskManagerUserDetail tmu WITH (NOLOCK)        
         WHERE PermissionType = TaskDetail.TASKTYPE        
            AND tmu.UserKey = @c_UserID        
            AND tmu.AreaKey = @c_AreaKey01        
            AND tmu.Permission = '1')        
      ORDER BY        
         TaskDetail.Priority        
         ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END        
         ,CASE WHEN LOC.LOCAisle = @c_LastLOCAisle THEN '0' ELSE '1' END        
         ,LOC.LogicalLocation        
         ,LOC.LOC       
   END    
  
   SELECT  @c_LocCount=COUNT(1)      
   FROM dbo.TaskDetail WITH (NOLOCK)        
      JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)        
      JOIN dbo.AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)        
   WHERE AreaDetail.AreaKey = @c_AreaKey01        
   AND TaskDetail.TaskType IN ('RPF')        
   AND TaskDetail.Status = '0'      
   AND Taskdetail.FromLOC = @c_FromLOC     
   AND TaskDetail.FromID = @c_FromID      
   AND TaskDetail.Lot=@c_FromLot      
   AND EXISTS( SELECT 1         
      FROM TaskManagerUserDetail tmu WITH (NOLOCK)        
      WHERE PermissionType = TaskDetail.TASKTYPE        
         AND tmu.UserKey = @c_UserID        
         AND tmu.AreaKey = @c_AreaKey01        
         AND tmu.Permission = '1')   
  
   DECLARE @c_UCCQTY INT  
     
   SELECT TOP 1 @c_UCCQTY = Qty FROM UCC (NOLOCK)     
   WHERE UCC.Storerkey = @c_Storerkey   
      AND  UCC.Loc = @c_FromLOC    
         AND UCC.Id = @c_FromID   
         AND UCC.Status='1'  
  
   SELECT @c_QtyAvaiable = Case WHEN   
   SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) < ISNULL(@c_UCCQTY,0) AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationHandling = '1'  
   then 0 else SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) END  
      from LotxLocxID LLI(NOLOCk)  
      JOIN LOC (NOLOCK) on lli.loc = loc.loc   
      WHERE Storerkey = @c_Storerkey AND LLI.Loc = @c_FromLOC  AND LLI.Id = @c_FromID  
      AND LLI.Qty > 0 and LocationType NOT IN ('DYNPICKP','DYNPPICK' )  
      group by LOC.LocationType,LOC.LocationHandling  
  
   IF (@c_LocCount)> 1 AND @c_Pickmethod ='FP'      
   BEGIN      
      UPDATE TaskDetail WITH (Rowlock)      
      SET Pickmethod='PP'      
      WHERE  taskdetailkey=@c_TaskDetailkey  
   END      
   ELSE  
   BEGIN            
      IF @c_Pickmethod ='PP' and ISNULL(@c_QtyAvaiable,0) <= 0   
      BEGIN  
         UPDATE TaskDetail WITH (Rowlock)      
         SET Pickmethod='FP'  
         WHERE  taskdetailkey=@c_TaskDetailkey  
      END  
   END   
    
   IF @n_continue = 3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      DECLARE @n_IsRDT INT    
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT    
    
      IF @n_IsRDT = 1    
      BEGIN    
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here    
         -- Instead we commit and raise an error back to parent, let the parent decide    
    
         -- Commit until the level we begin with    
         WHILE @@TRANCOUNT > @n_starttcnt    
            COMMIT TRAN    
    
         -- Raise error with severity = 10, instead of the default severity 16.     
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger    
         RAISERROR (@n_err, 10, 1) WITH SETERROR     
    
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten    
      END    
      ELSE    
      BEGIN    
        IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
        BEGIN    
          ROLLBACK TRAN    
        END    
        ELSE    
        BEGIN    
          WHILE @@TRANCOUNT > @n_starttcnt    
          BEGIN    
             COMMIT TRAN    
          END    
        END    
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMRP17'    
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
        RETURN    
     END    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
END        

GO