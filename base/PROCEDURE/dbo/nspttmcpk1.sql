SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspTTMCPK1                                         */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose: TM Cluster Pick strategy                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Author    Ver  Purposes                                  */  
/* 2020-06-20  James     1.0  WMS-12055 Created                         */  
/* 2022-01-13  James     1.1  WMS-18699 Add sort by wavekey (james01)   */
/************************************************************************/  
CREATE   PROC [dbo].[nspTTMCPK1]  
    @c_UserID        NVARCHAR(18)  
   ,@c_AreaKey01     NVARCHAR(10)  
   ,@c_AreaKey02     NVARCHAR(10)  
   ,@c_AreaKey03     NVARCHAR(10)  
   ,@c_AreaKey04     NVARCHAR(10)  
   ,@c_AreaKey05     NVARCHAR(10)  
   ,@c_LastLOC       NVARCHAR(10)  
   ,@n_err           INT            OUTPUT  
   ,@c_errmsg        NVARCHAR(250)  OUTPUT  
   ,@c_FromLOC       NVARCHAR(10)   OUTPUT  
   ,@c_TaskDetailKey NVARCHAR(10)   OUTPUT  
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
      ,@c_LastLOCAisle  NVARCHAR(10)  
      ,@cFoundTask    NVARCHAR( 1)  
      ,@b_SkipTheTask INT  
        
   DECLARE   
       @c_StorerKey NVARCHAR(15)  
      ,@c_SKU       NVARCHAR(20)  
      ,@c_FromID    NVARCHAR(18)  
      ,@c_ToLOC     NVARCHAR(10)  
      ,@c_ToID      NVARCHAR(18)  
      ,@c_LOT       NVARCHAR(10)  
      ,@n_QTY       INT  
      ,@c_TaskType  NVARCHAR( 10)  
      ,@c_LOCCategory NVARCHAR( 10)  
      ,@c_LOCAisle  NVARCHAR( 10)  
      ,@c_Facility  NVARCHAR( 5)  
      ,@cTransitLOC NVARCHAR( 10)  
      ,@cUserKeyOverRide NVARCHAR(18)  
      ,@cFacility   NVARCHAR(5)  
      ,@cDeviceID   NVARCHAR(20)
      ,@cTaskKey    NVARCHAR(10)
      ,@cGroupKey   NVARCHAR(10)
      
    SELECT   
       @b_debug = 0  
      ,@n_starttcnt = @@TRANCOUNT  
      ,@n_continue = 1  
      ,@b_success = 0  
      ,@n_err = 0  
      ,@c_errmsg = ''  
      ,@c_TaskDetailkey = ''  
      ,@c_LastLOCAisle = ''  
              
   -- Handling transaction  
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN nspTTMCPK1 -- For rollback or commit only our own transaction  
        
   SET @c_TaskDetailKey = ''  
  
   IF @c_AreaKey01 <> '' AND @c_AreaKey01 <> 'ALL'  
      DECLARE Cursor_CPKTaskCandidates CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TaskDetailkey, DeviceID
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutawayZone = LOC.PutAwayZone)  
         WHERE AreaDetail.AreaKey = @c_AreaKey01  
            AND TaskDetail.TaskType = 'CPK'  
            AND TaskDetail.Status = '0'
            AND DeviceID <> ''  
            AND TaskDetail.UserKeyOverRide = @c_userid  
            AND NOT EXISTS( SELECT 1  
               FROM TaskDetail T1 WITH (NOLOCK)  
               WHERE TaskDetail.GroupKey <> ''   
                  AND T1.GroupKey = TaskDetail.GroupKey   
                  AND T1.Status < '9'  
                  AND T1.UserKey NOT IN (@c_userid, ''))  
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
          WHERE PermissionType = TaskDetail.TASKTYPE  
                 AND tmu.UserKey = @c_UserID  
                 AND tmu.AreaKey = @c_AreaKey01  
                 AND tmu.Permission = '1')  
         ORDER BY 
             TaskDetail.WaveKey
            ,TaskDetail.Priority
            ,LOC.LogicalLocation  
            ,LOC.LOC  
            ,TaskDetail.TaskDetailKey  
   ELSE  
   BEGIN  
      -- Get facility  
      SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()  
        
      DECLARE Cursor_CPKTaskCandidates CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TaskDetailkey, DeviceID
         FROM dbo.TaskDetail WITH (NOLOCK)  
            JOIN dbo.LOC WITH (NOLOCK) ON (TaskDetail.FromLOC = LOC.LOC)  
            JOIN dbo.LoadPlan WITH (NOLOCK) ON (LoadPlan.LoadKey = TaskDetail.LoadKey)  
            JOIN dbo.Booking_Out WITH (NOLOCK) ON (Loadplan.BookingNo = Booking_Out.BookingNo)  
         WHERE dbo.TaskDetail.TaskType = 'CPK'  
            AND TaskDetail.Status = '0'
            AND DeviceID <> ''  
            AND TaskDetail.UserKeyOverRide = @c_userid  
            AND LOC.Facility = @cFacility  
            AND NOT EXISTS( SELECT 1  
               FROM TaskDetail T1 WITH (NOLOCK)  
               WHERE TaskDetail.GroupKey <> ''   
                  AND T1.GroupKey = TaskDetail.GroupKey   
                  AND T1.Status < '9'  
                  AND T1.UserKey NOT IN (@c_userid, ''))  
            AND EXISTS( SELECT 1   
               FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
               WHERE PermissionType = TaskDetail.TASKTYPE  
                 AND tmu.UserKey = @c_UserID  
                 AND tmu.Permission = '1')  
         ORDER BY  
             TaskDetail.WaveKey
            ,TaskDetail.Priority
            ,LOC.LogicalLocation  
            ,LOC.LOC  
            ,TaskDetail.TaskDetailKey  
   END  
  
   -- Get a task  
   OPEN Cursor_CPKTaskCandidates  
   FETCH NEXT FROM Cursor_CPKTaskCandidates INTO @c_TaskDetailKey, @cDeviceID  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Get task info  
      SELECT  
         @c_TaskType  = TaskType,   
         @c_StorerKey = StorerKey,   
         @c_SKU       = SKU,  
         @c_LOT       = LOT,  
         @n_QTY       = QTY,   
         @c_FromLOC   = FromLOC,  
         @c_FromID    = FromID,  
         @c_ToLOC     = ToLOC,  
         @c_ToID      = ToID,   
         @cGroupKey   = GroupKey  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE TaskDetailKey = @c_TaskDetailKey  
  
      -- Check skip task  
      SET @b_success = 0  
      SET @b_SkipTheTask = 0  
      EXECUTE nspCheckSkipTasks  
           @c_UserID  
         , @c_TaskDetailKey  
         , @c_TaskType  
         , ''  
         , ''  
         , ''  
         , ''  
         , ''  
         , ''  
         , @b_SkipTheTask  OUTPUT  
         , @b_Success      OUTPUT  
         , @n_err          OUTPUT  
         , @c_errmsg       OUTPUT  
      IF @b_success <> 1  
         GOTO Fail  
      IF @b_SkipTheTask = 1  
      BEGIN  
         FETCH NEXT FROM Cursor_CPKTaskCandidates INTO @c_TaskDetailKey, @cDeviceID  
         CONTINUE  
      END  
  
      -- Check equipment  
      SET @b_success = 0  
      EXECUTE nspCheckEquipmentProfile  
           @c_UserID=@c_UserID  
         , @c_TaskDetailKey= @c_TaskDetailKey  
         , @c_StorerKey    = @c_StorerKey  
         , @c_SKU          = @c_SKU  
         , @c_LOT         = @c_LOT  
         , @c_FromLOC      = @c_FromLOC  
         , @c_FromID       = @c_FromID  
         , @c_ToLOC        = @c_ToLOC  
         , @c_toID         = ''--@c_toid  
         , @n_QTY          = @n_QTY  
         , @b_Success      = @b_success OUTPUT  
         , @n_err          = @n_err     OUTPUT  
         , @c_errmsg       = @c_errmsg  OUTPUT  
      IF @b_success = 0  
      BEGIN  
         FETCH NEXT FROM Cursor_CPKTaskCandidates INTO @c_TaskDetailKey, @cDeviceID  
         CONTINUE  
      END  
  
      -- Update task as in-progress  
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @c_TaskDetailKey AND Status = '3' AND UserKey = @c_UserID)  
      BEGIN  
         DECLARE @cur CURSOR 
         SET @cur = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT TaskDetailKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Storerkey = @c_StorerKey
         AND   TaskType = 'CPK'
         AND   [Status] = '0'
         AND   DeviceID = @cDeviceID
         AND   UserKeyOverRide = @c_UserID
         AND   GroupKey = @cGroupKey      -- Only get task(s) from 1 cart 
         OPEN @cur
         FETCH NEXT FROM @cur INTO @cTaskKey
         WHILE @@FETCH_STATUS = 0
         BEGIN 
            UPDATE TaskDetail SET  
                Status     = '3'  
               ,UserKey    = @c_UserID  
               ,ReasonKey  = ''  
               ,StartTime  = CURRENT_TIMESTAMP  
               ,EditDate   = CURRENT_TIMESTAMP  
               ,EditWho    = @c_UserID  
               ,TrafficCop = NULL  
            WHERE TaskDetailKey = @cTaskKey  

            IF @@ERROR <> 0 OR @@ROWCOUNT = 0  
            BEGIN  
               SET @n_Err = 90701  
               SET @c_ErrMsg = '90701 UPDTaskDtlFail'  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM @cur INTO @cTaskKey
         END
      END  
      
      SET @c_FromLOC = @cDeviceID   -- To display on 1st screen on main stored proc
      SET @cFoundTask = 'Y'  
      BREAK -- Task assiged sucessfully, Quit Now  
   END  
     
   -- Exit if no task  
   IF @cFoundTask <> 'Y'   
   BEGIN  
      SET @c_TaskDetailKey = ''  --@c_TaskDetailKey still contain last record value if @@FETCH_STATUS <> 0 exit while loop  
      GOTO Quit  
   END  
  
   COMMIT TRAN nspTTMCPK1 -- Only commit change made here  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN nspTTMCPK1 -- Only rollback change made here  
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO