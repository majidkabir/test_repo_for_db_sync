SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMRT02                                         */
/* Creation Date: 31-03-2016                                            */
/* Copyright: LF                                                        */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Rev  Author    Purposes                                  */
/* 31-03-2016  1.0  ChewKP    CarterSZ Project                          */
/* 15-11-2019  1.1  Chermaine WMS-11126 Add userkey override (cc01)     */
/************************************************************************/

CREATE PROC [dbo].[nspTTMRT02]
   @c_userid           NVARCHAR(18)
,  @c_areakey01        NVARCHAR(10)
,  @c_areakey02        NVARCHAR(10)
,  @c_areakey03        NVARCHAR(10)
,  @c_areakey04        NVARCHAR(10)
,  @c_areakey05        NVARCHAR(10)
,  @c_lastloc          NVARCHAR(10)
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
      
    DECLARE @c_PalletPickDispatchMethod   NVARCHAR(10)  
           ,@c_CasePickDispatchMethod     NVARCHAR(10)  
           ,@c_PiecePickDispatchMethod    NVARCHAR(10)  
      
    DECLARE @n_temptable_recordcount      INT  
           ,@n_temptable_qty              INT  
           ,@c_LocType                    NVARCHAR(10)  
           ,@c_uomtext                    NVARCHAR(10)  
           ,@c_tempTaskDetailkey          NVARCHAR(10)  
           ,@c_CaseIDtodelete             NVARCHAR(10)  
           ,@n_countCaseIDtodelete        INT  
           ,@b_SkipTheTask                INT  
      
    DECLARE @b_Cursor_Eval01_Open         INT  
           ,@b_Cursor_EvalBatchPick_Open  INT  
           ,@b_TempTableCreated           INT  
      
    DECLARE @c_LastLoadKey                NVARCHAR(10)  
           ,@c_LoadKey                    NVARCHAR(10)  
           ,@c_SourceType                 NVARCHAR(15)  
           ,@c_DropID                     NVARCHAR(18) 
           ,@c_PrevToteFullFlag           NVARCHAR(1)  
           ,@c_Consigneekey               NVARCHAR(20) 
           ,@c_SKUBUSR5                   NVARCHAR(30) 
           ,@c_OrderUserDefine03          NVARCHAR(20) 
      
    SELECT @b_Cursor_Eval01_Open = 0  
          ,@b_Cursor_EvalBatchPick_Open = 0  
          ,@b_TempTableCreated = 0  
    /* #INCLUDE <SPTMPK01_1.SQL> */  
      
    BEGIN TRAN   
    

    IF @n_continue=1  
       OR @n_continue=2  
    BEGIN  
        CREATE TABLE #temp_dispatchCaseID  
        (  
           TaskDetailKey  NVARCHAR(10)  
           ,CaseID        NVARCHAR(10)  
           ,qty           INT  
        )  
        SELECT @b_TempTableCreated = 1  
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
        WHERE  USERKEY = @c_UserID  
               AND STATUS = '3' -- (Vicky02)  
               AND Tasktype IN ('RPT')   
          
        SELECT @n_err = @@ERROR  
              ,@n_cnt = @@ROWCOUNT  
          
        IF @n_err<>0  
        BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                  ,@n_err = 81201 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+  
                   ': Update to TaskDetail table failed. (nspTTMRT02)'+' ( '+  
                   ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '  
        END  
          
        IF @b_debug=1  
        BEGIN  
            SELECT 'Records where the userkey is equal to '  
                   ,@c_UserID,' status is in process '  
              
            SELECT *  
            FROM   TaskDetail  
            WHERE  USERKEY = @c_UserID  
                   AND STATUS='3' -- (Vicky01)  
        END  
    END  
    
       -- Close cursor
   IF CURSOR_STATUS( 'global', 'cursor_RPTTASKCANDIDATES') IN (0, 1) -- 0=empty, 1=record
      CLOSE cursor_RPTTASKCANDIDATES
   IF CURSOR_STATUS( 'global', 'cursor_RPTTASKCANDIDATES') IN (-1)   -- -1=cursor is closed
      DEALLOCATE cursor_RPTTASKCANDIDATES
      
    WHILE (1=1)  
          AND (@n_continue=1 OR @n_continue=2)  
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
                        SELECT TaskDetailKey
                        FROM TaskDetail TaskDetail WITH (NOLOCK)                 
                        JOIN Loc FromLoc WITH (NOLOCK) ON (TaskDetail.FromLoc = FromLoc.Loc)
                        JOIN Loc ToLoc WITH (NOLOCK) ON (TaskDetail.ToLoc = ToLoc.Loc ) 
                        JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = FromLoc.PutAwayZone) 
                        JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey) 
                        WHERE TaskDetail.Status = '0'
                        AND TaskDetail.TaskType = 'RPT'
                        AND TaskDetail.UserKey = ''
                        AND TaskManagerUserDetail.UserKey = @c_userid   --(cc01)
                        AND TaskManagerUserDetail.PermissionType = 'RPT'
                        AND TaskManagerUserDetail.Permission = '1'
                        AND TaskManagerUserDetail.AreaKey = @c_AreaKey01 --AreaDetail.AreaKey
                        --AND AreaDetail.Putawayzone = Loc.PutAwayZone
                        --AND TaskDetail.FromLoc = Loc.Loc
                        ORDER BY Priority 
                        ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END --(cc01)
                        ,ToLoc.LogicalLocation , ToLoc.Loc --TaskDetailKey 
                END  
                ELSE  
                BEGIN  
                    DECLARE Cursor_Eval01  CURSOR LOCAL FAST_FORWARD READ_ONLY   
                    FOR  
                        SELECT TaskDetailKey
                        FROM TaskDetail TaskDetail WITH (NOLOCK)                 
                        JOIN Loc FromLoc WITH (NOLOCK) ON (TaskDetail.FromLoc = FromLoc.Loc)
                        JOIN Loc ToLoc WITH (NOLOCK) ON (TaskDetail.ToLoc = ToLoc.Loc ) 
                        JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = FromLoc.PutAwayZone) 
                        JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey) 
                        WHERE TaskDetail.Status = '0'
                        AND TaskDetail.TaskType = 'RPT'
                        AND TaskDetail.UserKey = ''
                        AND TaskManagerUserDetail.UserKey = @c_userid   --(cc01)
                        AND TaskManagerUserDetail.PermissionType = 'RPT'
                        AND TaskManagerUserDetail.Permission = '1'
                        AND TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey
                        --AND AreaDetail.Putawayzone = Loc.PutAwayZone
                        --AND TaskDetail.FromLoc = Loc.Loc
                        ORDER BY Priority 
                        ,CASE WHEN TaskDetail.UserKeyOverRide = @c_userid THEN '0' ELSE '1' END --(cc01)
                        ,ToLoc.LogicalLocation , ToLoc.Loc --TaskDetailKey 
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
                           ': Could not Open Cursor_Eval02. (nspTTMRT02)'+' ( '   
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
                            
                        FROM   TaskDetail TD WITH (NOLOCK)  
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
            
            
            BEGIN  
                UPDATE TaskDetail   
                SET    STATUS = '3'  
                      ,[UserKey] = @c_UserID  
                      ,[ReasonKey] = ''
                      ,[EditDate] = GetDate()      
                      ,[EditWho]  = sUSER_sNAME() 
                      ,[TrafficCop] = NULL        
                WHERE  Storerkey = @c_StorerKey  
                  AND TaskType = 'RPT'  
                  AND FromLoc  = @c_loc  
                  AND UserKey  = ''  
                  AND [Status] = '0'  
                  AND FromID   = @c_id
                  
                SELECT @n_err = @@ERROR ,@n_cnt = @@ROWCOUNT  
                IF @n_err<>0  
                BEGIN  
                    SELECT @n_continue = 3  
                    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
                          ,@n_err = 81204 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': UPDATE TaskDetail Failed. (nspTTMRT02)'+' ( '   
                          + ' SQLSvr MESSAGE='+RTRIM(@c_errmsg)+' ) '  
                END

                -- Sort By ToLoc.LogicalLocation (Chee01)
                SELECT Top 1 @c_TaskDetailkey          = TD.TaskDetailkey  
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
                FROM TaskDetail TD WITH (NOLOCK)
                JOIN Loc ToLoc WITH (NOLOCK) ON (TD.ToLoc = ToLoc.Loc)
                WHERE TD.Storerkey = @c_StorerKey  
                  AND TD.TaskType  = 'RPT'  
                  AND TD.FromLoc   = @c_loc  
                  AND TD.UserKey   = @c_UserID 
                  AND TD.[Status]  = '3'  
                  AND TD.FromID    = @c_id
                ORDER BY ToLoc.LogicalLocation , TD.ToLoc
            END  
              
            IF @n_continue = 1 OR @n_continue = 2  
            BEGIN  
               DECLARE cursor_RPTTASKCANDIDATES
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

     DECLARE cursor_RPTTASKCANDIDATES  CURSOR    
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMRT02'  
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