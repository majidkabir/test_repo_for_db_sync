SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspTTMPK08                                         */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Only fetch task for PPK                                     */  
/*                                                                      */  
/* Called By: nspTMTM01                                                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 28-Mar-2017  James   1.0   WMS1349-Created                           */ 
/************************************************************************/  
CREATE PROC    [dbo].[nspTTMPK08]  
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
   SET ANSI_NULLS OFF
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
      
   DECLARE @c_executestmt     NVARCHAR(255)  
   DECLARE @c_LastCaseID      NVARCHAR(10)  
        ,@c_LastWaveKey     NVARCHAR(10)  
        ,@c_LastOrderKey    NVARCHAR(10)  
        ,@c_LastRoute       NVARCHAR(10)  
        ,@c_LastStop        NVARCHAR(10)  
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
        ,@c_route                      NVARCHAR(10)  
        ,@c_stop                       NVARCHAR(10)  
        ,@c_door                       NVARCHAR(10)  
        ,@c_Message01                  NVARCHAR(20)  
        ,@c_Message02                  NVARCHAR(20)  
        ,@c_Message03                  NVARCHAR(20)  
        ,@c_PickMethod                 NVARCHAR(10)  
        ,@c_NextOrderKey               NVARCHAR(10)  
        ,@c_TaskType                   NVARCHAR(10)  
        ,@c_PutawayZone                NVARCHAR(10) 
      
   DECLARE @c_PalletPickDispatchMethod NVARCHAR(10)  
        ,@c_CasePickDispatchMethod     NVARCHAR(10)  
        ,@c_PiecePickDispatchMethod    NVARCHAR(10)  

   DECLARE @n_temptable_recordcount    INT  
        ,@n_temptable_qty              INT  
        ,@c_LocType                    NVARCHAR(10)  
        ,@c_uomtext                    NVARCHAR(10)  
        ,@c_tempTaskDetailkey          NVARCHAR(10)  
        ,@c_CaseIDtodelete             NVARCHAR(10)  
        ,@n_countCaseIDtodelete        INT  
        ,@b_SkipTheTask                INT  

   DECLARE @b_Cursor_Eval01_Open       INT  
        ,@b_Cursor_Eval02_Open         INT  
        ,@b_Cursor_Eval03_Open         INT  
        ,@b_Cursor_Eval04_Open         INT  
        ,@b_Cursor_Eval05_Open         INT  
        ,@b_Cursor_Eval06_Open         INT  
        ,@b_Cursor_Eval07_Open         INT  
        ,@b_Cursor_EvalBatchPick_Open  INT  
        ,@b_TempTableCreated           INT  

   DECLARE @c_LastLoadKey              NVARCHAR(10)  
        ,@c_LoadKey                    NVARCHAR(10)  
        ,@c_SourceType                 NVARCHAR(15)  
        ,@c_DropID                     NVARCHAR(18) 
        ,@c_PrevToteFullFlag           NVARCHAR(1)  
        ,@c_Consigneekey               NVARCHAR(20) 
        ,@c_ItemClass                  NVARCHAR(10) -- (james01)
        ,@c_OrderUserDefine03          NVARCHAR(20) 
        ,@c_LastPickMethod             NVARCHAR(10) 

   SELECT @b_Cursor_Eval01_Open = 0  
       ,@b_Cursor_Eval02_Open = 0  
       ,@b_Cursor_Eval03_Open = 0  
       ,@b_Cursor_Eval04_Open = 0  
       ,@b_Cursor_Eval05_Open = 0  
       ,@b_Cursor_Eval06_Open = 0  
       ,@b_Cursor_Eval07_Open = 0  
       ,@b_Cursor_EvalBatchPick_Open = 0  
       ,@b_TempTableCreated = 0  
    /* #INCLUDE <SPTMPK01_1.SQL> */  
      
   BEGIN TRAN   


   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      CREATE TABLE #temp_dispatchCaseID  
      (  
         TaskDetailKey  NVARCHAR(10)  
         ,CaseID        NVARCHAR(10)  
         ,qty           INT  
      )  
      SELECT @b_TempTableCreated = 1  
   END  
      
      
   DECLARE @c_Priority NVARCHAR(10)  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      SELECT TOP 1 @c_LastLoadKey = TA.LoadKey, 
                  @c_LastPickMethod = PickMethod
      FROM   TASKDETAIL TA WITH (NOLOCK)  
      WHERE  TA.Tasktype = 'PPK'  
            AND TA.Status = '9'  
            AND ta.UserKey = @c_UserID  
            AND NOT EXISTS(  
                    SELECT 1  
                    FROM   TaskManagerSkipTasks(NOLOCK)  
                    WHERE  TaskManagerSkipTasks.Taskdetailkey = TA.TaskDetailkey  
                )  
      ORDER BY  
            TA.EditDate DESC   
          
      IF @b_debug=1  
      BEGIN  
         SELECT 'Loadkey' = @c_LastLoadKey  
      END  
   END  
         
   STARTPROCESSING:  
      
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      IF @b_debug=1  
      BEGIN  
         SELECT 'start processing'  
      END  
       
      UPDATE TaskDetail WITH (ROWLOCK) SET 
         STATUS = '0'  
        ,USERKEY = ''  
        ,REASONKEY = ''  
        ,EditDate = GetDate()     
        ,EditWho  = sUSER_sNAME()   
        ,TrafficCop = NULL                      
      WHERE  USERKEY = @c_UserID  
      AND    STATUS = '3' 
      AND    Tasktype = 'PPK'
       
      SELECT @n_err = @@ERROR  
            ,@n_cnt = @@ROWCOUNT  
          
      IF @n_err<>0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
               ,@n_err = 81201 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                ': Update to TaskDetail table failed. (nspTTMPK08)'+' ( '+  
                ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '  
      END  
          
      IF @b_debug=1  
      BEGIN  
         SELECT 'Records where the userkey is equal to '  
                ,@c_UserID,' status is in process '  
           
         SELECT *  
         FROM   TaskDetail  
         WHERE  USERKEY = @c_UserID  
                AND STATUS='3' 
      END  
   END  

   WHILE (1=1) AND (@n_continue=1 OR @n_continue=2)  
   BEGIN  
      IF @b_debug=1  
      BEGIN  
         SELECT 'Start Evaluating'  
      END  

      IF (@n_continue=1 OR @n_continue=2)  
      BEGIN  
         --IF ISNULL(RTRIM(@c_LastLoadKey) ,'')<>''  
         BEGIN  
            IF @b_debug=1  
            BEGIN  
               SELECT 'DECLARE Cursor_Eval01'  
            END  
            DECLARECURSOR_EVAL01:  
                  
            SELECT @b_Cursor_Eval01_Open = 0  
            IF ISNULL(RTRIM(@c_AreaKey01) ,'')<>''  
            BEGIN  
              DECLARE Cursor_Eval01 CURSOR LOCAL FAST_FORWARD READ_ONLY   
              FOR  
                  SELECT TaskDetailkey  
                  FROM   TaskDetail WITH (NOLOCK)  
                  JOIN LOC WITH (NOLOCK) ON  TaskDetail.FromLoc = Loc.Loc  
                  JOIN AREADETAIL WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone   
                  JOIN LOADPLAN WITH (NOLOCK) ON Taskdetail.LoadKey = LOADPLAN.LoadKey                                        
                  LEFT OUTER JOIN (SELECT SR.BoxNumber, AD.AreaKey, MAX(SR.READING_TIME) As Reading_Time     
                                   FROM STATION_RESPONSE SR WITH (NOLOCK)
                                   JOIN CODELKUP c WITH (NOLOCK) ON C.Short = SR.Station 
                                   JOIN AreaDetail ad WITH (NOLOCK) ON AD.PutawayZone = C.Code  
                                   WHERE C.LISTNAME = 'WCSSTATION' 
                                     AND AD.AreaKey = @c_AreaKey01 
                                   GROUP BY SR.BoxNumber, AD.AreaKey) VR 
                        ON VR.AreaKey = AREADETAIL.AreaKey     
                        AND VR.BoxNumber = CASE WHEN ISNUMERIC(ISNULL(TaskDetail.DropID,'X')) = 1     
                                                THEN CAST(TaskDetail.DropID AS BIGINT) ELSE '0'     
                                           END     
                        AND VR.Reading_Time >= TaskDetail.AddDate                                                                              
                  WHERE  AreaDetail.AreaKey = @c_AreaKey01  
                  AND TaskDetail.TASKTYPE = 'PPK'
                         AND TaskDetail.USERKEY = ''  
                         AND TaskDetail.STATUS = '0'  
                         AND Loadplan.Status < '9' 
                         AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
                                    WHERE PermissionType = TaskDetail.TASKTYPE  
                                      AND tmu.UserKey = @c_UserID    
                                      AND tmu.AreaKey = @c_AreaKey01    
                                      AND tmu.Permission = '1')  
                         AND NOT EXISTS(SELECT 1 FROM TaskDetail TD2 WITH (NOLOCK)   
                                        WHERE TD2.OrderKey = TaskDetail.OrderKey  
                                        AND   (TaskDetail.PickMethod LIKE 'MULTIS%' OR TaskDetail.PickMethod LIKE 'DOUBLES%')   
                                        AND   TaskDetail.Status = '3'  
                                        AND   TaskDetail.UserKey <> @c_UserID)  
                  ORDER BY  
                         TaskDetail.Priority   
                        ,CASE WHEN VR.BoxNumber IS NULL THEN 1 ELSE 0 END 
                        ,CASE          
                              WHEN TaskDetail.LOADKEY=@c_LastLoadKey THEN   
                                   ''  
                              ELSE TaskDetail.LoadKey   
                         END -- Last LoadKey always come 1st  
                        ,CASE WHEN ISNULL(TaskDetail.DropID,'') <> '' THEN 2 ELSE 1 END   
                        ,TaskDetail.LogicalFromLoc   
            END  
            ELSE  
            BEGIN  
               DECLARE Cursor_Eval01  CURSOR LOCAL FAST_FORWARD READ_ONLY   
               FOR  
               SELECT TaskDetailkey  
               FROM   TaskDetail WITH (NOLOCK)  
                      JOIN LOC WITH (NOLOCK) ON  TaskDetail.FromLoc = Loc.Loc  
               JOIN AREADETAIL WITH (NOLOCK) ON  AreaDetail.Putawayzone = Loc.PutAwayZone   
               JOIN LOADPLAN WITH (NOLOCK) ON Taskdetail.LoadKey = LOADPLAN.LoadKey   
               LEFT OUTER JOIN (SELECT SR.BoxNumber, AD.AreaKey, MAX(SR.READING_TIME) As Reading_Time     
                                FROM STATION_RESPONSE SR WITH (NOLOCK)
                                JOIN CODELKUP c WITH (NOLOCK) ON C.Short = SR.Station 
                                JOIN AreaDetail ad WITH (NOLOCK) ON AD.PutawayZone = C.Code  
                                WHERE C.LISTNAME = 'WCSSTATION' 
                                GROUP BY SR.BoxNumber, AD.AreaKey) VR 
                     ON VR.AreaKey = AREADETAIL.AreaKey     
                     AND VR.BoxNumber = CASE WHEN ISNUMERIC(ISNULL(TaskDetail.DropID,'X')) = 1     
                                             THEN CAST(TaskDetail.DropID AS BIGINT) ELSE '0'     
                                        END     
                     AND VR.Reading_Time >= TaskDetail.AddDate                                                                              
                     WHERE  TaskDetail.TASKTYPE = 'PPK'
                            AND TaskDetail.USERKEY = ''  
                            AND TaskDetail.STATUS = '0'  
                            AND Loadplan.Status < '9'    
                            AND EXISTS(SELECT 1 FROM TaskManagerUserDetail tmu WITH (NOLOCK)  
                                       WHERE PermissionType = TaskDetail.TASKTYPE  
                                         AND tmu.UserKey = @c_UserID     
                                         AND tmu.Permission = '1')   
                            AND NOT EXISTS(SELECT 1 FROM TaskDetail TD2 WITH (NOLOCK)   
                                           WHERE TD2.OrderKey = TaskDetail.OrderKey  
                                           AND   (TaskDetail.PickMethod LIKE 'MULTIS%' OR TaskDetail.PickMethod LIKE 'DOUBLES%')   
                                           AND   TaskDetail.Status = '3')  
                     ORDER BY  
                            TaskDetail.Priority   
                           ,CASE WHEN VR.BoxNumber IS NULL THEN 1 ELSE 0 END 
                           ,CASE          
                                 WHEN TaskDetail.LOADKEY=@c_LastLoadKey THEN   
                                      ''  
                                 ELSE TaskDetail.LoadKey   
                            END -- Last LoadKey always come 1st  
                           ,CASE WHEN ISNULL(TaskDetail.DropID,'') <> '' THEN 2 ELSE 1 END   
                           ,TaskDetail.LogicalFromLoc   
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
                     ': Could not Open Cursor_Eval02. (nspTTMPK08)'+' ( '   
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
                        ,@c_LoadKey                = TD.LoadKey  
                        ,@c_TaskType               = TD.TaskType  
                        ,@c_DropID                 = ISNULL(RTRIM(TD.DropID), '')  
                        ,@c_PrevToteFullFlag       = CASE WHEN ISNULL(RTRIM(Message03), '') = 'PREVFULL' THEN 'Y' ELSE 'N' END  
                        ,@c_Consigneekey           = TD.Message01   
                        ,@c_ItemClass              = SKU.ItemClass -- (james01)
                  FROM   TaskDetail TD WITH (NOLOCK)  
                  INNER JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = TD.SKU AND SKU.StorerKey = TD.StorerKey 
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
               WHERE  TaskManagerUserDetail.UserKey = @c_UserID  
               AND TaskManagerUserDetail.PermissionType = @c_TaskType  
               AND TaskManagerUserDetail.Permission = '1'  
               AND Loc.Loc = @c_loc  
               )  
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
            WHERE  AreaDetail.AreaKey = @c_AreaKey01  
            AND Loc.Loc = @c_loc  
            )  
         BEGIN  
            GOTO EVALUATIONDONE  
         END  
      END  
   END  
  
   ---- Check the Multi, Double, ...  
   IF @b_RowCheckPass=0  
   BEGIN  
      -- PickMethod SINGLES Shouldn't have any   
      IF @c_PickMethod LIKE 'SINGLES%'   
      BEGIN  
         IF EXISTS(SELECT 1  
            FROM   TaskDetail td WITH (NOLOCK)  
            WHERE  Storerkey = @c_StorerKey  
               AND Sku = @c_SKU  
               AND TaskType = 'PPK'  
               AND FromLoc = @c_LOC  
               AND PickMethod = @c_PickMethod  
               AND UserKey <> @c_UserID  
               AND [Status] = '3'  
               AND LoadKey = @c_LoadKey  
         )  
          BEGIN  
              GOTO EVALUATIONDONE  
          END  
      END  
      ELSE  
      IF @c_PickMethod LIKE 'DOUBLES%'  
      BEGIN  
         IF EXISTS(SELECT 1  
         FROM   TaskDetail td WITH (NOLOCK)  
         WHERE  Storerkey = @c_StorerKey  
           AND TaskType = 'PPK'  
           AND PickMethod = @c_PickMethod  
           AND UserKey <> @c_UserID  
           AND [Status] = '3'  
           AND OrderKey = @c_OrderKey)  
          BEGIN  
              GOTO EVALUATIONDONE  
          END                                                                 
      END -- Multi  
      ELSE  
      IF @c_PickMethod LIKE 'MULTIS%'  
      BEGIN  
         IF EXISTS(SELECT 1  
         FROM   TaskDetail td WITH (NOLOCK)  
         WHERE  Storerkey = @c_StorerKey  
           AND TaskType = 'PPK'  
           AND PickMethod = @c_PickMethod
           AND UserKey <> @c_UserID  
           AND [Status] = '3'  
           AND OrderKey = @c_OrderKey)  
          BEGIN  
              GOTO EVALUATIONDONE  
          END                                                                 
      END -- Multi  
   END           
                  
   IF @b_RowCheckPass=0  
   BEGIN  
      IF @b_debug=1  
      BEGIN  
          SELECT 'Row candidate check #2 - Make sure record is not assigned to another user'  
            
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
         , @c_TaskDetailkey 
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
      IF @c_PickMethod LIKE 'SINGLES%'   
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
            AND TaskType = 'PPK'  
            AND FromLoc = @c_loc  
            AND PickMethod = @c_PickMethod  
            AND UserKey = ''  
            AND [Status] = '0'  
            AND LoadKey = @c_LoadKey  
            
          SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT  
          IF @n_err<>0  
          BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                    ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE TaskDetail Failed. (nspTTMPK08)'+' ( '   
                    + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '  
          END  
      END  
              
      IF @c_PickMethod LIKE 'MULTIS%'  
      BEGIN  
        -- (Vicky01) - Start  
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
             AND TaskType = 'PPK'  
             AND PickMethod = @c_PickMethod  
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
            AND TaskType = 'PPK'  
            AND PickMethod = @c_PickMethod  
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
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
                 AND UserKey = ''  
                 AND [Status] = '0'  
                 AND OrderKey = @c_OrderKey  
         END  
            
          SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT  
            
          IF @n_err<>0  
          BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                    ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                     ': UPDATE TaskDetail Failed. (nspTTMPK08)'+' ( '   
                    +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)   
                    +' ) '  
          END  
      END  
              
      IF @c_PickMethod LIKE 'DOUBLES%'  
      BEGIN  
        -- (Vicky01) - Start  
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
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
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
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
                 AND UserKey = ''  
                 AND [Status] = '0'  
                 AND DropID = @c_DropID  
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
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
                 AND UserKey = ''  
                 AND [Status] = '0'  
                 AND OrderKey = @c_OrderKey  
         END  
            
          SELECT @n_err = @@ERROR  
                ,@n_cnt = @@ROWCOUNT  
            
          IF @n_err<>0  
          BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                    ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
              SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                     ': UPDATE TaskDetail Failed. (nspTTMPK08)'+' ( '   
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
                    AND td.TaskType = 'PPK'  
                    AND td.FromLoc = @c_loc  
                    AND td.PickMethod = @c_PickMethod  
                    AND td.UserKey = ''  
                    AND td.[Status] = '0'  
                    AND td.OrderKey<>@c_OrderKey  
                    AND td.DropID = '' 
                    AND LoadKey = @c_LoadKey  
               
             IF ISNULL(RTRIM(@c_NextOrderKey) ,'')=''  
             BEGIN  
                 -- Consider Same Zone 1st 
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
                        AND td.TaskType = 'PPK'  
                        AND td.FromLoc<>@c_loc  
                        AND td.PickMethod = @c_PickMethod  
                        AND td.UserKey = ''  
                        AND td.[Status] = '0'  
                        AND td.OrderKey<>@c_OrderKey  
                        AND LoadKey = @c_LoadKey  
                        AND td.DropID = '' 
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
                        AND TaskType = 'PPK'  
                        AND PickMethod = @c_PickMethod  
                        AND UserKey = ''  
                        AND [Status] = '0'  
                        AND OrderKey = @c_NextOrderKey  
                        AND LoadKey = @c_LoadKey  
                   
                 SELECT @n_err = @@ERROR  
                       ,@n_cnt = @@ROWCOUNT  
                   
                 IF @n_err<>0  
                 BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                           ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                            ': UPDATE TaskDetail Failed. (nspTTMPK08)'+' ( '   
                           +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)   
                           +' ) '  
                 END  

                 SELECT @c_DropID = MAX(DropID)   
                 FROM  TaskDetail WITH (NOLOCK)   
                 WHERE Status = '3'  
                   AND [UserKey] = @c_UserID   
                   AND Storerkey = @c_StorerKey  
                   AND TaskType = 'PPK'  
                   AND PickMethod = @c_PickMethod  

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
                    AND TaskType = 'PPK'  
                    AND PickMethod = @c_PickMethod  
                    AND DropID = ''   
                    IF @n_err<>0  
                    BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                              ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                               ': UPDATE TaskDetail Failed. (nspTTMPK08)'+' ( '   
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
         IF @c_PickMethod LIKE 'SINGLES%'   
         BEGIN  
            SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)  
            FROM   TaskDetail td WITH (NOLOCK)  
            WHERE  Storerkey = @c_StorerKey  
               AND Sku = @c_SKU  
               AND TaskType = 'PPK'  
               AND FromLoc = @c_LOC  
               AND PickMethod = @c_PickMethod  
               AND UserKey <> ''  
               AND [Status] = '3'  
               AND LoadKey = @c_LoadKey  
         END  
         ELSE  
         IF @c_PickMethod LIKE 'DOUBLES%'  
         BEGIN  
            IF ISNULL(RTRIM(@c_NextOrderKey),'') <> ''  
            BEGIN  
               SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)  
               FROM   TaskDetail td WITH (NOLOCK)  
               WHERE  Storerkey = @c_StorerKey  
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
                 AND UserKey <> ''  
                 AND [Status] = '3'  
                 AND OrderKey IN (@c_OrderKey,@c_NextOrderKey)  
            END                 
            ELSE  
            BEGIN  
               SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)  
               FROM   TaskDetail td WITH (NOLOCK)  
               WHERE  Storerkey = @c_StorerKey  
                 AND TaskType = 'PPK'  
                 AND PickMethod = @c_PickMethod  
                 AND UserKey <> ''  
                 AND [Status] = '3'  
                 AND OrderKey = @c_OrderKey                                             
            END  
         END -- Multi  
         ELSE   
         IF @c_PickMethod LIKE 'MULTIS%'  
         BEGIN  
            SELECT @nNumUserFound = COUNT(DISTINCT td.UserKey)  
            FROM   TaskDetail td WITH (NOLOCK)  
            WHERE  Storerkey = @c_StorerKey  
              AND TaskType = 'PPK'  
              AND PickMethod = @c_PickMethod  
              AND UserKey <> ''  
              AND [Status] = '3'  
              AND OrderKey = @c_OrderKey  
         END     
         IF @nNumUserFound <> 1  
         BEGIN  
            SET @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                  ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
             ': Lock TaskDetail Failed. (nspTTMPK08)'+' ( '   
                  +' SQLSvr MESSAGE='+RTRIM(@c_errmsg)   
                  +' ) '  
            GOTO NOTHINGTOSEND                    
         END                     
      END -- Continue =1   

      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN  
         DECLARE CURSOR_PKTASKCANDIDATES  
         CURSOR FOR  
         SELECT @c_taskdetailkey,@c_caseid,@c_loadkey,@c_orderlinenumber,  
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
    
   IF @b_Cursor_Eval02_Open=1  
   BEGIN  
      CLOSE Cursor_Eval02  
      DEALLOCATE Cursor_Eval02  
   END  
    
   IF @b_Cursor_Eval03_Open=1  
   BEGIN  
      CLOSE Cursor_Eval03  
      DEALLOCATE Cursor_Eval03  
   END  
       
   IF @b_Cursor_Eval04_Open=1  
   BEGIN  
      CLOSE Cursor_Eval04  
      DEALLOCATE Cursor_Eval04  
   END  
    
   IF @b_Cursor_Eval05_Open=1  
   BEGIN  
      CLOSE Cursor_Eval05  
      DEALLOCATE Cursor_Eval05  
   END  
    
   IF @b_Cursor_Eval06_Open=1  
   BEGIN  
      CLOSE Cursor_Eval06  
      DEALLOCATE Cursor_Eval06  
   END  
    
   IF @b_Cursor_Eval07_Open=1  
   BEGIN  
      CLOSE Cursor_Eval07  
      DEALLOCATE Cursor_Eval07  
   END  

   IF @b_TempTableCreated=1  
   BEGIN  
      DROP TABLE #TEMP_DISPATCHCaseID  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMPK08'  
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