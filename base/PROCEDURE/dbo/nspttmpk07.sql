SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Stored Procedure: nspTTMPK07                                         */          
/* Creation Date:                                                       */          
/* Copyright: LF                                                        */          
/* Written by:                                                          */          
/*                                                                      */          
/* Purpose:                                                             */          
/*                                                                      */          
/* Called By:                                                           */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author        Purposes                                  */          
/* 08-Apr-2016  ChewKP  1.1   Created SOS#358813                        */    
/* 07-Oct-2016  ChewKP  1.2   Performance Tuning (ChewKP01)             */ 
/* 05-May-2020  TLTING01 1.3  Missing nolock                            */
/************************************************************************/          
CREATE PROC    [dbo].[nspTTMPK07]          
               @c_UserID           NVARCHAR(18)          
,              @c_AreaKey01        NVARCHAR(10)          
,              @c_AreaKey02        NVARCHAR(10)          
,              @c_AreaKey03        NVARCHAR(10)          
,              @c_AreaKey04        NVARCHAR(10)          
,              @c_AreaKey05        NVARCHAR(10)          
,              @c_LastLoc          NVARCHAR(10)          
AS          
BEGIN          
    SET NOCOUNT ON           
    --SET ANSI_NULLS OFF        
    SET QUOTED_IDENTIFIER OFF           
    SET CONCAT_NULL_YIELDS_NULL OFF      
   
              
    DECLARE @b_debug INT          
    SELECT @b_debug = 0          
    DECLARE @n_continue   INT          
           ,@n_starttcnt  INT -- Holds the current transaction count          
           ,@n_cnt        INT -- Holds @@ROWCOUNT after certain operations          
           ,@n_err2       INT -- For Additional Error Detection          
           ,@b_Success    INT          
           ,@n_err        INT          
           ,@c_errmsg     NVARCHAR(250)          
              
    SELECT @n_starttcnt = @@TRANCOUNT          
          ,@n_continue = 1          
          ,@b_success = 0          
          ,@n_err = 0          
          ,@c_errmsg = ''          
          ,@n_err2 = 0          
              
    DECLARE @c_LastSKU         NVARCHAR(20)          
           ,@c_LastTaskType    NVARCHAR(10)          
           ,@c_LastConsignee   NVARCHAR(15)          
           ,@c_LastAisle       NVARCHAR(10)          
           ,@c_LogicalLoc      NVARCHAR(10)          
           ,@c_lot             NVARCHAR(10)          
           ,@c_UOM             NVARCHAR(10)          
              
            
    DECLARE @b_gotarow         INT          
           ,@b_RowCheckPass    INT          
           ,@b_EvaluationType  INT          
           ,@b_DoEval01_only   INT          
          
    SELECT @b_gotarow = 0          
          ,@b_RowCheckPass = 0          
          ,@b_DoEval01_only = 0          
              
    DECLARE @c_TaskDetailkey              NVARCHAR(10)          
           ,@c_CaseID                     NVARCHAR(10)          
           ,@c_OrderKey                   NVARCHAR(10)   
           ,@c_OrderLineNumber            NVARCHAR(5)          
           ,@c_WaveKey                    NVARCHAR(10)          
           ,@c_StorerKey                  NVARCHAR(15)          
           ,@c_sku                        NVARCHAR(20)          
           ,@c_loc                        NVARCHAR(10)          
           ,@c_id                         NVARCHAR(18)          
           ,@c_UserKeyOverride            NVARCHAR(18)           
           ,@c_Message01                  NVARCHAR(20)          
           ,@c_Message02                  NVARCHAR(20)          
           ,@c_Message03                  NVARCHAR(20)          
           ,@c_PickMethod                 NVARCHAR(10)          
           ,@c_NextOrderKey               NVARCHAR(10)          
           ,@c_TaskType                   NVARCHAR(10)          
           ,@c_PutawayZone                NVARCHAR(10)          
           ,@c_PickZone                   NVARCHAR(10)        
           --,@c_LocAisle                   NVARCHAR(10)        
           ,@cLoadKey                     NVARCHAR(10)      
           ,@nTaskCount                   INT
           ,@cLocAisle                    NVARCHAR(10)
              
              
    DECLARE @n_temptable_qty              INT          
           ,@c_UOMText                    NVARCHAR(10)          
           ,@b_SkipTheTask                INT          
              
    DECLARE @b_Cursor_Eval01_Open         INT          
           ,@b_Cursor_Eval02_Open         INT          
           ,@b_Cursor_Eval03_Open         INT          
           ,@b_Cursor_Eval04_Open         INT          
           ,@b_Cursor_Eval05_Open         INT          
           ,@b_Cursor_Eval06_Open         INT          
           ,@b_Cursor_Eval07_Open         INT          
           ,@b_Cursor_EvalBatchPick_Open  INT          
           ,@b_TempTableCreated           INT          
              
    DECLARE @c_LastWaveKey                NVARCHAR(10)          
           ,@c_SourceType                 NVARCHAR(15)          
           ,@c_DropID                     NVARCHAR(18)           
           ,@c_PrevToteFullFlag           NVARCHAR(1)            
           ,@c_Consigneekey               NVARCHAR(20)           
           ,@c_SKUBUSR5                   NVARCHAR(30)         
           ,@c_OrderUserDefine03          NVARCHAR(20)       
           ,@cUpdTaskDetailKey            NVARCHAR(10) 
              
    SELECT @b_Cursor_Eval01_Open = 0          
          ,@b_Cursor_Eval02_Open = 0          
          ,@b_Cursor_Eval03_Open = 0          
          ,@b_Cursor_Eval04_Open = 0          
          ,@b_Cursor_Eval05_Open = 0          
          ,@b_Cursor_Eval06_Open = 0          
          ,@b_Cursor_Eval07_Open = 0          
          ,@b_Cursor_EvalBatchPick_Open = 0          
          ,@b_TempTableCreated = 0          
              
    BEGIN TRAN           
              
    DECLARE @c_Priority NVARCHAR(10)          
  
    
    IF @n_continue=1 OR @n_continue=2          
    BEGIN          
        SELECT TOP 1         
               @c_LastWaveKey   = TA.WaveKey,         
               @c_LastSKU       = TA.Sku,        
               @c_LastConsignee = TA.Message03,         
               @c_LastTaskType  = TA.TaskType,         
               @c_LastAisle     = LOC.LocAisle        
        FROM  TASKDETAIL TA WITH (NOLOCK)         
        JOIN  LOC WITH (NOLOCK) ON LOC.LOC = TA.FromLoc            
        WHERE TA.Tasktype IN ('SPK','PK') -- (ChewKP01)    
          AND TA.Status = '9'          
          AND TA.UserKey = @c_UserID          
          AND NOT EXISTS(          
                 SELECT 1          
                 FROM   TaskManagerSkipTasks(NOLOCK)          
                 WHERE  TaskManagerSkipTasks.Taskdetailkey = TA.TaskDetailkey          
             )          
        ORDER BY TA.EditDate DESC           
                 
        IF @b_debug=1          
        BEGIN          
            SELECT 'Wavekey' = @c_LastWaveKey          
        END          
    END          
                 
    STARTPROCESSING:          
              
    IF @n_continue=1 OR @n_continue=2          
    BEGIN          
      IF @b_debug=1          
        BEGIN          
            SELECT 'start processing'          
        END          
                  
        UPDATE TaskDetail          
        SET    STATUS = '0'          
              ,USERKEY = ''          
              ,REASONKEY = ''          
              ,EditDate = GetDate()     
              ,EditWho  = sUSER_sNAME()           
              ,TrafficCop = NULL                              
        WHERE USERKEY = @c_UserID          
          AND STATUS = '3'         
          AND Tasktype IN ('SPK', 'PK') -- (ChewKP01)    
                  
        SELECT @n_err = @@ERROR          
              ,@n_cnt = @@ROWCOUNT          
                  
        IF @n_err<>0          
        BEGIN          
            SELECT @n_continue = 3          
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                  ,@n_err = 81201 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                   ': Update to TaskDetail table failed. (nspTTMPK07)'+' ( '+          
                   ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '          
        END          
                  
        IF @b_debug=1          
        BEGIN          
            SELECT 'Records where the userkey is equal to '          
                   ,@c_UserID,' status is in process '          
                      
            SELECT *          
            FROM   TaskDetail     (NOLOCK) -- tlting01     
            WHERE  USERKEY = @c_UserID          
                   AND STATUS='3'           
        END          
    END          
    
   IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (0, 1) -- 0=empty, 1=record
      CLOSE CURSOR_PKTASKCANDIDATES
   IF CURSOR_STATUS( 'global', 'CURSOR_PKTASKCANDIDATES') IN (-1)   -- -1=cursor is closed
      DEALLOCATE CURSOR_PKTASKCANDIDATES
   
   
              
   WHILE (1=1) AND (@n_continue=1 OR @n_continue=2)          
   BEGIN          
      IF @b_debug=1          
      BEGIN          
         SELECT 'Start Evaluating'          
      END          
               
      IF (@n_continue=1 OR @n_continue=2)          
      BEGIN           
          IF @b_debug=1          
          BEGIN          
              SELECT 'DECLARE Cursor_Eval01'          
          END          
          DECLARECURSOR_EVAL01:          
                          
          SELECT @b_Cursor_Eval01_Open = 0          
          --IF ISNULL(RTRIM(@c_AreaKey01) ,'')<>''          
          BEGIN          
            
  
             DECLARE Cursor_Eval01 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
             SELECT TD.TaskDetailkey          
             FROM TaskDetail TD WITH (NOLOCK)          
             JOIN LOC WITH (NOLOCK) ON  TD.FromLoc = Loc.Loc          
             JOIN AREADETAIL AD WITH (NOLOCK) ON  AD.Putawayzone = Loc.PutAwayZone           
             JOIN dbo.PickDetail PD with (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)      -- tlting01    
             JOIN dbo.OrderDetail OD  with (NOLOCK)  --tlting01
                  ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)          
             JOIN dbo.Orders O  with (NOLOCK) ON (OD.OrderKey = O.OrderKey AND TD.WaveKey = O.UserDefine09)   --tlting01       
             WHERE AD.AreaKey = CASE WHEN ISNULL(RTRIM(@c_AreaKey01), '') = '' THEN AD.AreaKey ELSE @c_AreaKey01 END         
                   AND TD.TASKTYPE IN ( 'PK', 'SPK' )    
                   AND TD.USERKEY = ''          
                   AND TD.STATUS = '0'          
                   --AND ISNULL( TD.Message03, '') <> ''  -- (ChewKP01)     
                   AND PD.Status = '0'          
                   AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)          
                              WHERE PermissionType = TD.TASKTYPE          
                                AND tmu.UserKey = @c_UserID            
                                AND tmu.AreaKey = @c_AreaKey01            
                                AND tmu.Permission = '1')           
             ORDER BY          
                   TD.Priority           
                  ,CASE                  
                        WHEN TD.Wavekey=@c_LastWaveKey THEN ''          
                        ELSE TD.Wavekey           
                   END        
                 ,LOC.LocAisle 
                 ,LOC.LogicalLocation          
                 ,LOC.LOC     
                 ,TD.LOT      
                 ,TD.SKU              
                                                         
          END          
        
          SELECT @n_err = @@ERROR          
                ,@n_cnt = @@ROWCOUNT          
                    
          IF @n_err=16915          
          BEGIN          
             CLOSE Cursor_Eval01          
             DEALLOCATE Cursor_Eval01          
             GOTO DECLARECURSOR_EVAL01          
          END                                  
          OPEN Cursor_Eval01          
          SELECT @n_err = @@ERROR          
                ,@n_cnt = @@ROWCOUNT          
                          
          IF @n_err=16905          
          BEGIN          
             CLOSE Cursor_Eval01          
             DEALLOCATE Cursor_Eval01          
             GOTO DECLARECURSOR_EVAL01          
          END          
                          
          IF @n_err<>0          
          BEGIN          
              SELECT @n_continue = 3          
              SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                    ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
              SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                     ': Could not Open Cursor_Eval02. (nspTTMPK07)'+' ( '           
                    +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)           
                    +' ) '          
          END          
          ELSE          
          BEGIN          
             SELECT @b_Cursor_Eval01_Open = 1          
          END          
        
          IF @n_continue=1 OR @n_continue=2          
          BEGIN          
             WHILE (1=1)          
             BEGIN          
                FETCH NEXT FROM Cursor_Eval01 INTO @c_TaskDetailkey          
                IF @@FETCH_STATUS<>0          
              BEGIN          
                   BREAK          
                END          
                          
                SELECT @c_TaskDetailkey          = TD.TaskDetailkey          
                      ,@c_CaseID                 = TD.CaseID          
                      ,@c_OrderKey               = TD.OrderKey          
                      ,@c_OrderLineNumber        = TD.OrderLineNumber          
                      ,@c_WaveKey                = TD.WaveKey          
                      ,@c_StorerKey              = TD.StorerKey          
                      ,@c_sku                    = TD.SKU          
                      ,@c_loc                    = TD.FromLoc          
                      ,@c_LogicalLoc             = TD.LogicalFromLoc          
                      ,@c_id                     = TD.FromID          
                      ,@c_lot                    = TD.lot          
                      ,@c_uom                    = TD.uom          
                      ,@c_UserKeyOverride        = TD.UserKeyOverride          
                      ,@c_PickMethod             = TD.PickMethod          
                      ,@c_WaveKey                = TD.WaveKey          
                      ,@c_TaskType               = TD.TaskType          
                      ,@c_DropID                 = ISNULL(RTRIM(TD.DropID), '')         
                      ,@c_PrevToteFullFlag       = CASE WHEN ISNULL(RTRIM(Message03), '') = 'PREVFULL' THEN 'Y' ELSE 'N' END          
                      ,@c_Consigneekey           = TD.Message03          
                      ,@c_PickZone               = LOC.PickZone         
                      ,@cLoadKey                 = TD.LoadKey       
                      ,@cLocAisle                = Loc.LocAisle
                FROM   TaskDetail TD WITH (NOLOCK)          
                INNER JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = TD.SKU AND SKU.StorerKey = TD.StorerKey         
                INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc           
                WHERE  TD.TaskDetailKEY = @c_TaskDetailkey          
                      
                
                      
        
                SELECT @b_EvaluationType = 1          
                SELECT @b_RowCheckPass = 0          
                GOTO CHECKROW          
                       
                EVALUATIONTYPERETURN_01:          
                IF @b_RowCheckPass=1          
                BEGIN          
                   SELECT @b_gotarow = 1          
                   GOTO DISPATCH          
                END          
             END -- WHILE (1=1)          
          END          
       END          
       BREAK          
       CHECKROW:          
       SET ROWCOUNT 0          
       IF @b_debug=1          
       BEGIN          
          SELECT 'evaluationtype' ,@b_EvaluationType          
                ,'TaskDetailkey=' ,@c_TaskDetailkey          
                ,'CaseID=' ,@c_CaseID          
                ,'OrderKey=' ,@c_OrderKey          
                ,'OrderLineNumber=' ,@c_OrderLineNumber          
                ,'WaveKey=' ,@c_WaveKey          
                ,'storer=' ,@c_StorerKey          
                ,'sku=' ,@c_sku          
                ,'loc=' ,@c_loc          
                ,'logicalloc=' ,@c_LogicalLoc          
                ,'id=' ,@c_id          
                ,'lot=' ,@c_lot          
                ,'uom=' ,@c_uom          
                ,'UserKeyOverride=' ,@c_UserKeyOverride          
       END          
           
       -- (ChewKP01)    
       IF @b_RowCheckPass=0     
       BEGIN    
         IF @c_TaskType = 'SPK'    
         BEGIN    
            
            IF ISNULL(@c_Consigneekey,'')  = ''     
            BEGIN    
               GOTO EVALUATIONDONE    
            END    
         ENd    
       END    
        
       IF @b_RowCheckPass=0          
       BEGIN          
          IF @b_debug=1          
          BEGIN          
             SELECT 'Row candidate check #1 - area authorization...'          
          END          
                      
          IF ISNULL(RTRIM(@c_AreaKey01) ,'')=''          
          BEGIN          
             IF NOT EXISTS(          
                    SELECT 1          
                    FROM  TaskManagerUserDetail WITH (NOLOCK)          
                    JOIN  AreaDetail WITH (NOLOCK) ON TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey           
                    JOIN  Loc WITH (NOLOCK) ON AreaDetail.Putawayzone = Loc.PutAwayZone           
                    WHERE TaskManagerUserDetail.UserKey = @c_UserID          
                      AND TaskManagerUserDetail.PermissionType = @c_TaskType          
                      AND TaskManagerUserDetail.Permission = '1'          
                      AND Loc.Loc = @c_loc)          
             BEGIN          
                GOTO EVALUATIONDONE          
             END          
          END          
          ELSE          
          BEGIN          
             IF NOT EXISTS(          
             SELECT 1          
                    FROM   AreaDetail WITH (NOLOCK)          
                    JOIN Loc WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone          
                    WHERE AreaDetail.AreaKey = @c_AreaKey01          
                      AND Loc.Loc = @c_loc)          
          BEGIN          
                GOTO EVALUATIONDONE          
             END          
          END          
       END          
          
        ---- Check the Multi, Double, ...SHONG05          
        IF @b_RowCheckPass=0          
        BEGIN          
            -- PickMethod SINGLES Shouldn't have any           
            IF @c_PickMethod='SINGLES'           
            BEGIN          
               IF EXISTS(SELECT 1          
                         FROM   TaskDetail td WITH (NOLOCK)          
                         INNER JOIN Loc Loc WITH (NOLOCK) ON Loc.Loc = td.FromLoc
                         WHERE  td.Storerkey = @c_StorerKey          
                            AND td.Sku = @c_SKU
                            AND td.TaskType = 'PK'          
                            AND td.FromLoc = @c_LOC          
                            AND td.PickMethod = 'SINGLES'          
                            AND td.UserKey <> @c_UserID          
                            AND td.Status = '3'          
                            AND td.WaveKey = @c_WaveKey        
                            AND Loc.LocAisle = @cLocAisle  
               )          
                BEGIN          
                    GOTO EVALUATIONDONE          
                END          
            END          
            ELSE          
            IF @c_PickMethod IN ('DOUBLES','MULTIS')          
            BEGIN          
               IF EXISTS(SELECT 1          
               FROM   TaskDetail td WITH (NOLOCK)          
               WHERE  Storerkey = @c_StorerKey          
                 AND TaskType = 'PK'          
                 AND PickMethod IN ('DOUBLES','MULTIS')          
                 AND UserKey <> @c_UserID          
                 AND [Status] = '3'          
                 AND OrderKey = @c_OrderKey)          
                BEGIN          
                  GOTO EVALUATIONDONE          
                END                                                                         
            END -- Multi          
            ELSE          
            IF @c_PickMethod='STOTE'           
            BEGIN          
               IF EXISTS( SELECT 1          
                        FROM   TaskDetail td WITH (NOLOCK)            
                        JOIN   SKU SKU WITH (NOLOCK) ON SKU.SKU = td.SKU AND SKU.StorerKey = td.StorerKey         
                        JOIN   ORDERS O WITH (NOLOCK) ON O.OrderKey = td.OrderKey         
                        JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc          
                        JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone                 
                        WHERE TD.Storerkey = @c_StorerKey          
                         AND TD.TaskType = 'SPK'            
                         AND TD.PickMethod = 'STOTE'          
                         AND TD.UserKey <> @c_UserID          
                         AND TD.[Status] = '3'          
                         AND TD.Message03 = @c_Consigneekey           
                         AND O.UserDefine09 = @c_WaveKey           
                         AND AD.AreaKey =           
                            CASE WHEN ISNULL(RTRIM(@c_AreaKey01), '') = '' THEN AD.AreaKey ELSE @c_AreaKey01 END         
                         AND LOC.PickZone = @c_PickZone        
                         AND SKU.Sku = @c_sku )         
                BEGIN          
                   GOTO EVALUATIONDONE          
                END          
            END        
            ELSE          
            IF @c_PickMethod='PP'           
            BEGIN          
               IF EXISTS( SELECT 1          
                        FROM   TaskDetail td WITH (NOLOCK)            
                        JOIN   SKU SKU WITH (NOLOCK) ON SKU.SKU = td.SKU AND SKU.StorerKey = td.StorerKey         
                        JOIN   ORDERS O WITH (NOLOCK) ON O.OrderKey = td.OrderKey         
                        JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc          
                        JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone                 
                        WHERE TD.Storerkey = @c_StorerKey          
                         AND TD.TaskType = 'SPK'            
                         AND TD.PickMethod = 'PP'          
                         AND TD.UserKey = @c_UserID          
                         AND TD.[Status] = '3'          
                         AND TD.Message03 = @c_Consigneekey           
                         AND O.UserDefine09 = @c_WaveKey           
                         AND AD.AreaKey =           
                            CASE WHEN ISNULL(RTRIM(@c_AreaKey01), '') = '' THEN AD.AreaKey ELSE @c_AreaKey01 END    )     
                         --AND LOC.PickZone = @c_PickZone)
                         --AND LOC.LocAisle = @cLocAisle)         
                BEGIN     
                   GOTO EVALUATIONDONE          
                END          
            END                  
                              
        END                   
        -- SHONG05      
                          
        IF @b_RowCheckPass=0          
        BEGIN          
            IF @b_debug=1          
            BEGIN          
                SELECT           
                       'Row candidate check #2 - Make sure record is not assigned to another user'          
                          
                SELECT @c_UserKeyOverride          
                      ,@c_UserID          
            END          
                      
            IF NOT (@c_UserKeyOverride='' OR @c_UserKeyOverride=@c_UserID)          
            BEGIN          
                GOTO EVALUATIONDONE          
            END          
        END          
                  
        IF @b_RowCheckPass=0          
        BEGIN          
            SELECT @b_success = 0          
                  ,@b_SkipTheTask = 0          
        
        
           EXECUTE nspCheckSkipTasks          
            @c_UserID          
            , @c_TaskDetailkey          
            , @c_TaskType          
            , @c_TaskDetailkey -- 'BatchPick' --@c_CaseID          
            , ''          
            , ''          
            , ''          
            , ''          
            , ''          
            , @b_SkipTheTask OUTPUT          
            , @b_Success OUTPUT          
            , @n_err OUTPUT          
            , @c_errmsg OUTPUT          
            IF @b_success<>1          
            BEGIN          
                SELECT @n_continue = 3          
            END          
        
            IF @b_SkipTheTask=1          
            BEGIN          
                GOTO EVALUATIONDONE          
            END          
        END          
                  
        IF @b_RowCheckPass=0          
        BEGIN          
            SELECT @b_success = 0          
            EXECUTE nspCheckEquipmentProfile          
              @c_UserID=@c_UserID          
            , @c_TaskDetailkey=''          
            , @c_StorerKey=@c_StorerKey          
            , @c_sku=@c_sku          
            , @c_lot=@c_lot          
            , @c_FromLoc=@c_loc          
            , @c_FromID=@c_id          
            , @c_toLoc=@c_loc          
            , @c_toID=@c_id          
            , @n_qty=0          
            , @b_Success=@b_success OUTPUT          
            , @n_err=@n_err OUTPUT          
            , @c_errmsg=@c_errmsg OUTPUT          
            IF @b_success=0          
            BEGIN          
                GOTO EVALUATIONDONE          
            END          
        END          
        
        SELECT @b_RowCheckPass = 1          
        IF @b_debug=1          
        BEGIN          
            SELECT 'Row check passed'          
        END          
                
        EVALUATIONDONE:          
                  
        IF @b_EvaluationType=1          
        BEGIN          
          GOTO EVALUATIONTYPERETURN_01          
        END          
                     
        DISPATCH:          
                   
        IF @n_continue=1 OR @n_continue=2          
        BEGIN          
            IF @c_PickMethod='SINGLES'           
            BEGIN          
 
                UPDATE TaskDetail       
                SET    STATUS = '3'      
                      ,[UserKey] = @c_UserID      
                      ,[ReasonKey] = ''    
                      ,[EditDate] = GetDate()             
                      ,[EditWho]  = sUSER_sNAME()     
                      ,[TrafficCop] = NULL            
                WHERE  Storerkey = @c_StorerKey      
                  AND Sku = @c_sku      
                  AND TaskType = 'PK'      
                  AND FromLoc = @c_loc      
                  AND PickMethod = 'SINGLES'      
                  AND UserKey = ''      
                  AND [Status] = '0'      
                  AND WaveKey = @c_WaveKey  
       
                SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT          
                IF @n_err<>0          
                BEGIN          
                    SELECT @n_continue = 3          
                    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                          ,@n_err = 81205 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                          + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '          
                          
                   SET RowCount 0       
                END    
                
                SET RowCount 0      
            END          
                      
            IF @c_PickMethod='MULTIS'          
            BEGIN            
              IF @c_DropID <> '' AND @c_PrevToteFullFlag = 'N'          
              BEGIN          
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''          
                      ,[EditDate] = GetDate()                 
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL                
                WHERE  Storerkey = @c_StorerKey          
                   AND TaskType = 'PK'          
                   AND PickMethod = 'MULTIS'          
                   AND UserKey = ''          
                   AND [Status] = '0'          
                   AND DropID = @c_DropID          
                   AND OrderKey = @c_OrderKey          
                             
              END          
              ELSE IF @c_DropID <> '' AND @c_PrevToteFullFlag = 'Y'          
              BEGIN          
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''          
                      ,[EditDate] = GetDate()                 
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL                
                WHERE  Storerkey = @c_StorerKey          
                  AND TaskType = 'PK'          
                  AND PickMethod = 'MULTIS'          
                  AND UserKey = ''          
                  AND [Status] = '0'          
                  AND DropID = @c_DropID          
                  AND OrderKey = @c_OrderKey          
              END          
              ELSE          
              BEGIN          
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''          
                      ,[EditDate] = GetDate()                 
                    ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL                
                WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'MULTIS'          
                        AND UserKey = ''          
                       AND [Status] = '0'          
                       AND OrderKey = @c_OrderKey          
               END          
                          
                SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT          
                          
                IF @n_err<>0          
                BEGIN          
                    SELECT @n_continue = 3          
                    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                          ,@n_err = 81206 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                           ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                          +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)           
                          +' ) '          
                END          
            END          
                      
            IF @c_PickMethod='STOTE'           
            BEGIN          
              --IF @c_PrevToteFullFlag = 'N'          
              BEGIN          
                UPDATE TaskDetail           
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''        
                      ,[EditDate] = GetDate()             
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL                  
                FROM   TaskDetail           
                JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TASKDETAIL.FromLoc          
                JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone                 
                JOIN   SKU SKU WITH (NOLOCK) ON SKU.SKU = TASKDETAIL.SKU AND SKU.StorerKey = TASKDETAIL.StorerKey          
                WHERE  TASKDETAIL.Storerkey = @c_StorerKey          
                 AND TaskDetail.Sku = @c_sku                         
                 AND TASKDETAIL.TaskType = 'SPK'            
                 AND TASKDETAIL.PickMethod = 'STOTE'         
                 AND TASKDETAIL.UserKey = ''          
                 AND TASKDETAIL.[Status] = '0'             
                 AND TASKDETAIL.Message03 = @c_Consigneekey         
                 AND TASKDETAIL.WaveKey = @c_WaveKey           
                 AND AD.AreaKey = CASE WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')='' THEN AD.AreaKey ELSE @c_AreaKey01 END           
                 AND TASKDETAIL.LoadKey = @cLoadKey      
                 AND LOC.PickZone = @c_PickZone          
              END          
                          
              SELECT @n_err = @@ERROR          
                    ,@n_cnt = @@ROWCOUNT          
                          
              IF @n_err<>0          
              BEGIN          
                 SELECT @n_continue = 3          
                 SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                       ,@n_err = 81207 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                 SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                        ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                       +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '          
              END          
            END -- @c_PickMethod='STOTE'            
        
            IF @c_PickMethod='PP'           
            BEGIN          
               

              --IF @c_PrevToteFullFlag = 'N'          
              BEGIN          
                SELECT @nTaskCount = Long
                FROM dbo.CodeLkup WITH (NOLOCK)
                WHERE ListName = 'TTMPK'
                AND Code = 'PP'
                
                 --SET RowCount 0 
                DECLARE CUR_UPDATE_TD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT TOP (@nTaskCount) TaskDetail.TaskDetailKey  
                FROM   TaskDetail  with (NOLOCK) --tlting01          
                JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TASKDETAIL.FromLoc          
                JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone                 
                JOIN   SKU SKU WITH (NOLOCK) ON SKU.SKU = TASKDETAIL.SKU AND SKU.StorerKey = TASKDETAIL.StorerKey         
                WHERE  TASKDETAIL.Storerkey = @c_StorerKey          
                 AND TASKDETAIL.TaskType = 'SPK'            
                 AND TASKDETAIL.PickMethod = 'PP'         
                 AND TASKDETAIL.UserKey = ''          
                 AND TASKDETAIL.[Status] = '0'             
                 AND TASKDETAIL.Message03 = @c_Consigneekey         
                 AND TASKDETAIL.WaveKey = @c_WaveKey           
                 AND AD.AreaKey = CASE WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')='' THEN AD.AreaKey ELSE @c_AreaKey01 END        
                 AND TASKDETAIL.LoadKey = @cLoadKey     
                 
                OPEN CUR_UPDATE_TD 
                FETCH NEXT FROM CUR_UPDATE_TD INTO @cUpdTaskDetailKey              
                WHILE @@FETCH_STATUS <> -1
                BEGIN
                     UPDATE dbo.TaskDetail WITH (ROWLOCK) 
                     SET Status = '3' 
                         ,[UserKey] = @c_UserID        
                         ,[ReasonKey] = ''        
                         ,[EditDate] = GetDate()             
                         ,[EditWho]  = sUSER_sNAME()         
                         ,[TrafficCop] = NULL        
                     WHERE TaskDetailKey = @cUpdTaskDetailKey
                     
                                          
                     FETCH NEXT FROM CUR_UPDATE_TD INTO @cUpdTaskDetailKey    
                END
                CLOSE CUR_UPDATE_TD
                DEALLOCATE CUR_UPDATE_TD   
                       
              END          
                          
              SELECT @n_err = @@ERROR          
                    ,@n_cnt = @@ROWCOUNT          
                          
              IF @n_err<>0          
              BEGIN          
                 SELECT @n_continue = 3          
                 SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                       ,@n_err = 81208 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                 SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                        ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                       +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '          
              END          
            END -- @c_PickMethod='PP'        
                                  
            IF @c_PickMethod='DOUBLES'          
            BEGIN          
                       
              IF @c_DropID <> '' AND @c_PrevToteFullFlag = 'N'          
              BEGIN          
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''        
                      ,[EditDate] = GetDate()                 
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL                
                WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'DOUBLES'          
                       AND UserKey = ''          
                       AND [Status] = '0'          
                       AND DropID = @c_DropID          
              END          
              ELSE IF @c_DropID <> '' AND @c_PrevToteFullFlag = 'Y'          
              BEGIN          
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''          
                      ,[EditDate] = GetDate()                 
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL        
                WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'DOUBLES'          
                       AND UserKey = ''          
                       AND [Status] = '0'          
                       AND DropID = @c_DropID          
                       --AND OrderKey = @c_OrderKey (Shong03)          
              END          
              ELSE          
              BEGIN         
                UPDATE TaskDetail          
                SET    STATUS = '3'          
                      ,[UserKey] = @c_UserID        
                      ,[ReasonKey] = ''          
                      ,[EditDate] = GetDate()                 
                      ,[EditWho]  = sUSER_sNAME()         
                      ,[TrafficCop] = NULL         
                WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'DOUBLES'          
                       AND UserKey = ''          
                       AND [Status] = '0'          
                       AND OrderKey = @c_OrderKey          
               END          
                          
                SELECT @n_err = @@ERROR          
                      ,@n_cnt = @@ROWCOUNT          
                          
                IF @n_err<>0          
                BEGIN          
                    SELECT @n_continue = 3          
                    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err) ,@n_err = 81209 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                           ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                          +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '          
                END          
                          
                          
                IF ISNULL(@c_DropID,'') = ''          
                BEGIN          
                   -- Get Next Order#, For double we process 2 orders per tote          
                   SET @c_NextOrderKey = ''          
                   -- Take from same location 1st          
                   SELECT TOP 1           
                          @c_NextOrderKey = ISNULL(OrderKey ,'')          
                   FROM   TaskDetail td(NOLOCK)          
                   WHERE  td.Storerkey = @c_StorerKey          
                          AND td.TaskType = 'PK'          
                          AND td.FromLoc = @c_loc          
                          AND td.PickMethod = 'DOUBLES'          
                          AND td.UserKey = ''          
                          AND td.[Status] = '0'          
                          AND td.OrderKey<>@c_OrderKey          
                          AND td.DropID = '' -- (ChewKP03)          
                          AND WaveKey = @c_WaveKey          
                             
                   IF ISNULL(RTRIM(@c_NextOrderKey) ,'')=''          
                   BEGIN          
                       -- Consider Same Zone 1st (Shong01)          
                       SET    @c_PutawayZone = ''          
                       SELECT @c_PutawayZone = ISNULL(PUTAWAYZONE,'')            
                       FROM   LOC WITH (NOLOCK)          
                       WHERE  LOC = @c_LOC           
          
                       SELECT TOP 1           
                              @c_NextOrderKey = ISNULL(OrderKey ,'')          
                              FROM   TaskDetail td(NOLOCK)          
                              JOIN LOC(NOLOCK)          
                                   ON  LOC.Loc = td.FromLoc          
                       WHERE  td.Storerkey = @c_StorerKey          
                              AND td.TaskType = 'PK'          
                              AND td.FromLoc<>@c_loc          
                              AND td.PickMethod = 'DOUBLES'          
                              AND td.UserKey = ''          
                              AND td.[Status] = '0'          
                       AND td.OrderKey<>@c_OrderKey          
                              AND WaveKey = @c_WaveKey          
                              AND td.DropID = '' -- (ChewKP03)          
                       ORDER BY          
                              CASE WHEN LOC.PutawayZone = @c_PutawayZone THEN 1 ELSE 2 END,          
                              LOC.LogicalLocation          
                   END          
                             
                   IF ISNULL(RTRIM(@c_NextOrderKey) ,'')<>''          
                   BEGIN          
                                 
                       UPDATE TaskDetail          
                       SET    STATUS = '3'          
                             ,[UserKey] = @c_UserID        
                             ,[ReasonKey] = ''        
                             ,[EditDate] = GetDate()                 
                             ,[EditWho]  = sUSER_sNAME()         
                             ,[TrafficCop] = NULL          
                       WHERE  Storerkey = @c_StorerKey          
                              AND TaskType = 'PK'          
                              AND PickMethod = 'DOUBLES'          
                              AND UserKey = ''          
                              AND [Status] = '0'          
                              AND OrderKey = @c_NextOrderKey          
                              AND WaveKey = @c_WaveKey          
                                 
                       SELECT @n_err = @@ERROR          
                             ,@n_cnt = @@ROWCOUNT          
                                 
                       IF @n_err<>0          
                       BEGIN          
                           SELECT @n_continue = 3          
                           SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                                 ,@n_err = 81210 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                                  ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                                 +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)           
                                 +' ) '          
                       END          
          
                       SELECT @c_DropID = MAX(DropID)           
                       FROM  TaskDetail WITH (NOLOCK)           
                       WHERE Status = '3'          
                         AND [UserKey] = @c_UserID           
                         AND Storerkey = @c_StorerKey          
                         AND TaskType = 'PK'          
                         AND PickMethod = 'DOUBLES'          
          
                       IF ISNULL(@c_DropID,'') <> ''           
                       BEGIN           
                          UPDATE TaskDetail           
                             SET DropID = @c_DropID         
                                ,[EditDate] = GetDate()                 
                                ,[EditWho]  = sUSER_sNAME()         
                                ,[TrafficCop] = NULL            
                          WHERE Status = '3'          
                          AND [UserKey] = @c_UserID           
                          AND Storerkey = @c_StorerKey          
                          AND TaskType = 'PK'          
                          AND PickMethod = 'DOUBLES'          
                          AND DropID = ''           
                          IF @n_err<>0          
                          BEGIN          
                              SELECT @n_continue = 3          
                              SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                                    ,@n_err = 81211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                              SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                                     ': UPDATE TaskDetail Failed. (nspTTMPK07)'+' ( '           
                                    +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)           
                                    +' ) '          
                          END                                    
                       END           
                   END          
               END -- If @c_DropID = ''          
            END -- DOUBLE          
                    
            -- Check Task Locking Issues           
            -- (Shong02)          
            IF @n_continue = 1 OR @n_continue = 2          
            BEGIN          
               DECLARE @nNumUserFound INT          
                         
               SET @nNumUserFound = 0           
               -- PickMethod SINGLES Shouldn't have any           
               IF @c_PickMethod='SINGLES'           
               BEGIN          
                  SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)          
                  FROM   TaskDetail td WITH (NOLOCK)          
                  WHERE  Storerkey = @c_StorerKey          
                     AND Sku = @c_SKU          
                     AND TaskType = 'PK'          
                     AND FromLoc = @c_LOC          
                     AND PickMethod = 'SINGLES'          
                     AND UserKey <> ''          
                     AND [Status] = '3'          
                     AND WaveKey = @c_WaveKey          
               END          
               ELSE          
               IF @c_PickMethod='DOUBLES'          
               BEGIN          
                  IF ISNULL(RTRIM(@c_NextOrderKey),'') <> ''          
                  BEGIN          
                     SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)          
                     FROM   TaskDetail td WITH (NOLOCK)          
                     WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'DOUBLES'          
                     AND UserKey <> ''          
                       AND [Status] = '3'          
                       AND OrderKey IN (@c_OrderKey,@c_NextOrderKey)          
                  END                         
                  ELSE          
                  BEGIN          
                     SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)          
                     FROM   TaskDetail td WITH (NOLOCK)          
                     WHERE  Storerkey = @c_StorerKey          
                       AND TaskType = 'PK'          
                       AND PickMethod = 'DOUBLES'          
                       AND UserKey <> ''          
                       AND [Status] = '3'          
                       AND OrderKey = @c_OrderKey                                                     
                  END          
               END -- Multi          
               ELSE           
               IF @c_PickMethod='MULTIS'          
               BEGIN          
                  SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)          
                  FROM   TaskDetail td WITH (NOLOCK)          
                  WHERE  Storerkey = @c_StorerKey          
                    AND TaskType = 'PK'          
                    AND PickMethod = 'MULTIS'          
                    AND UserKey <> ''          
                    AND [Status] = '3'          
                    AND OrderKey = @c_OrderKey          
               END             
               ELSE          
               IF @c_PickMethod='PP'           
               BEGIN        
                    SET @nNumUserFound = 1
 
              
               END         
               ELSE          
               IF @c_PickMethod='STOTE'           
               BEGIN          
                  SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)          
                  FROM   TaskDetail td WITH (NOLOCK)            
                  JOIN   SKU SKU WITH (NOLOCK) ON SKU.SKU = td.SKU AND SKU.StorerKey = td.StorerKey          
                  JOIN   LOC WITH (NOLOCK) ON LOC.LOC = TD.FromLoc          
                  JOIN   AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone                 
                   WHERE  TD.Storerkey = @c_StorerKey        
                    AND TD.Sku = @c_sku                             
                    AND TD.TaskType = 'SPK'            
                    AND TD.PickMethod = 'STOTE'         
                    AND TD.UserKey <> ''          
                    AND TD.[Status] = '3'             
                    AND TD.Message03 = @c_Consigneekey         
                    AND TD.WaveKey = @c_WaveKey           
                    AND AD.AreaKey = CASE WHEN ISNULL(RTRIM(@c_AreaKey01) ,'')='' THEN AD.AreaKey ELSE @c_AreaKey01 END        
                    AND TD.LoadKey = @cLoadKey           
                    AND LOC.PickZone = @c_PickZone                            
               END                          
               ELSE         
               BEGIN          
                  SET @nNumUserFound = 1          
               END          
                       
               IF @nNumUserFound <> 1         
               BEGIN          
                  SET @n_continue = 3          
                  SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)          
                        ,@n_err = 81212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.          
                  SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+          
                   ': Lock TaskDetail Failed. (nspTTMPK07)'+' ( '           
                        +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)           
                        +' ) '          
                  GOTO NOTHINGTOSEND                            
               END                             
            END -- Continue =1           
        
            IF @n_continue = 1 OR @n_continue = 2          
            BEGIN          
               
               DECLARE CURSOR_PKTASKCANDIDATES          
               CURSOR FOR          
               SELECT @c_taskdetailkey,@c_caseid,@c_WaveKey,@c_orderlinenumber,          
                      @c_wavekey, @c_storerkey,@c_sku,@c_lot,@c_loc,@c_id,'' as '@c_packkey',          
                      @c_uomtext, @n_temptable_qty, @c_message01, @c_message02, @c_message03          
  
              GOTO DONE                         
            END          
            ELSE          
               GOTO NOTHINGTOSEND                      
        END          
        
 DISPATCHCHECK:          
                  
        DISPATCHEXECUTE:          
     END            
     SET ROWCOUNT 0          
     NOTHINGTOSEND:          
               
     IF @b_debug=1          
     BEGIN          
         SELECT 'Nothing to send...'          
     END          
        
     DECLARE CURSOR_PKTASKCANDIDATES  CURSOR            
     FOR          
         SELECT '' ,'' ,'' ,'' ,'' ,'' ,'' ,''          
               ,'' ,'' ,'' ,'' , 0 ,'' ,'' ,''          
     DONE:          
               
     IF @b_debug=1          
     BEGIN          
         SELECT 'DONE'          
     END          
               
     IF @b_Cursor_Eval01_Open=1          
     BEGIN          
         CLOSE Cursor_Eval01          
         DEALLOCATE Cursor_Eval01          
     END          
               
              
     /* #INCLUDE <SPTMPK01_2.SQL> */          
     IF @n_continue=3 -- Error Occured - Process And Return          
     BEGIN          
         SELECT @b_success = 0          
         IF @@TRANCOUNT>@n_starttcnt          
         BEGIN          
             ROLLBACK TRAN          
         END          
         ELSE          
         BEGIN          
             WHILE @@TRANCOUNT>@n_starttcnt          
             BEGIN          
                 COMMIT TRAN          
             END          
         END          
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMPK07'          
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
         RETURN          
     END          
     ELSE          
     BEGIN          
         SELECT @b_success = 1          
         WHILE @@TRANCOUNT>@n_starttcnt          
         BEGIN          
             COMMIT TRAN          
         END          
         RETURN          
     END          
         
END 

GO