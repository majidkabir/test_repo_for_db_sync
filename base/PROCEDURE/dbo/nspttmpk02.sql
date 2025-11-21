SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMPK02                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
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
/* Date         Author        Purposes                                  */
/* 23-02-2010   Vicky         To sort by PickMethod - FP then PP        */
/*                            (Vicky01)                                 */ 
/* 09-03-2010   ChewKP        Avoid getting same task from the aisle    */
/*                            that another user is occupying (ChewKP01) */
/* 10-03-2010   Vicky         Should filter by Userkey = '' (Vicky02)   */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMPK02]
@c_userid      NVARCHAR(18)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10) -- Used for Last Drop ID
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_LastLoc          NVARCHAR(10)
AS
BEGIN
    --SET NOCOUNT ON 
    --SET QUOTED_IDENTIFIER OFF 
    --SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @b_debug INT
    SELECT @b_debug = 0
    DECLARE @n_continue   INT
           ,@n_starttcnt  INT	-- Holds the current transaction count
           ,@n_cnt        INT	-- Holds @@ROWCOUNT after certain operations
           ,@n_err2       INT	-- For Additional Error Detection
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
           ,@c_lastroute       NVARCHAR(10)
           ,@c_laststop        NVARCHAR(10)
           ,@c_LastDropID      NVARCHAR(18)
           ,@c_LastAisle       NVARCHAR(10)
           ,@c_Area            NVARCHAR(10)
           ,@c_Aisle           NVARCHAR(10) 
    
    DECLARE @b_gotarow         INT
           ,@b_RowCheckPass    INT
           ,@b_EvaluationType  INT
           ,@b_doeval01_only   INT
    
    SELECT @b_gotarow = 0
          ,@b_RowCheckPass = 0
          ,@b_doeval01_only = 0
    
    DECLARE @c_TaskDetailKey              NVARCHAR(10)
           ,@c_CaseID                     NVARCHAR(10)
           ,@c_orderkey                   NVARCHAR(10)
           ,@c_OrderLineNumber            NVARCHAR(5)
           ,@c_WaveKey                    NVARCHAR(10)
           ,@c_storerkey                  NVARCHAR(15)
           ,@c_sku                        NVARCHAR(20)
           ,@c_loc                        NVARCHAR(10)
           ,@c_id                         NVARCHAR(18)
           ,@c_lot                        NVARCHAR(10)
           ,@c_uom                        NVARCHAR(10)
           ,@c_userkeyoverride            NVARCHAR(18)
           ,@c_packkey                    NVARCHAR(15)
           ,@c_logicalloc                 NVARCHAR(18)
           ,@c_route                      NVARCHAR(10)
           ,@c_stop                       NVARCHAR(10)
           ,@c_door                       NVARCHAR(10)
           ,@c_message01                  NVARCHAR(20)
           ,@c_message02                  NVARCHAR(20)
           ,@c_message03                  NVARCHAR(20)
    
    DECLARE @c_palletpickdispatchmethod   NVARCHAR(10)
           ,@c_casepickdispatchmethod     NVARCHAR(10)
           ,@c_piecepickdispatchmethod    NVARCHAR(10)
    
    DECLARE @n_temptable_recordcount      INT
           ,@n_Qty                        INT
           ,@c_loctype                    NVARCHAR(10)
           ,@c_uomtext                    NVARCHAR(10)
           ,@c_tempTaskDetailKey          NVARCHAR(10)
           ,@c_CaseIDtodelete             NVARCHAR(10)
           ,@n_CountCaseIDToDelete        INT
           ,@b_skipthetask                INT
    
    DECLARE @b_CUR_PICK_TASK_open         INT
           ,@b_CURSOR_EVAL02_open         INT
           ,@b_CURSOR_EVAL03_open         INT
           ,@b_CURSOR_EVAL04_open         INT
           ,@b_CURSOR_EVAL05_open         INT
           ,@b_CURSOR_EVAL06_open         INT
           ,@b_CURSOR_EVAL07_open         INT
           ,@b_Cursor_EvalBatchPick_open  INT
           ,@b_temptablecreated           INT
           ,@b_Cursor_PickTaskOpen        INT 
           
    
    DECLARE @c_LastLoadKey                NVARCHAR(10)
           ,@c_LoadKey                    NVARCHAR(10)
           ,@c_sourcetype                 NVARCHAR(15)
           ,@c_pickmethod                 NVARCHAR(10)
    
    SELECT @b_CUR_PICK_TASK_open = 0
          ,@b_CURSOR_EVAL02_open = 0
          ,@b_CURSOR_EVAL03_open = 0
          ,@b_CURSOR_EVAL04_open = 0
          ,@b_CURSOR_EVAL05_open = 0
          ,@b_CURSOR_EVAL06_open = 0
          ,@b_CURSOR_EVAL07_open = 0
          ,@b_Cursor_EvalBatchPick_open = 0
          ,@b_temptablecreated = 0
          
    /* #INCLUDE <SPTMPK01_1.SQL> */
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        CREATE TABLE #temp_dispatchCaseID
        (
            TaskDetailKey  NVARCHAR(10)
           ,CaseID         NVARCHAR(10)
           ,Qty            INT
        )
        SELECT @b_temptablecreated = 1
    END
    
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
      SELECT @c_LastDropID  = LastDropID
            ,@c_LastLoadKey = LastLoadKey
            ,@c_LastWaveKey = Lastwavekey
            ,@c_LastCaseID  = LastCaseIdPicked 
      FROM   TaskManagerUser WITH (NOLOCK)
      WHERE  userkey = @c_userid
    END
		
	 IF @n_continue=1 OR @n_continue=2  
	 BEGIN  
			DECLARE @t_Aisle_InUsed TABLE (LocAIsle NVARCHAR(10), UserKey NVARCHAR(18))
	      
	      IF EXISTS (SELECT 1 FROM TaskManagerUser TMU With (NOLOCK)
	                  INNER JOIN EquipmentProfile EP With (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey) 
	                  WHERE TMU.Userkey = @c_userid 
	                  AND TMU.EquipmentProfileKey = 'VNA' )
	      BEGIN
   			INSERT INTO @t_Aisle_InUsed (LocAisle, UserKey)
   			SELECT L.LocAisle, TD.UserKey
   			FROM TaskDetail TD WITH (NOLOCK) 
   			JOIN LOC L WITH (NOLOCK) ON (TD.FromLOC = L.Loc)
   			JOIN TaskManagerUser TMU WITH (NOLOCK) ON (TD.UserKey = TMU.UserKey)
   			JOIN EquipmentProfile EP WITH (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey)
   			WHERE TMU.EquipmentProfileKey = 'VNA' 
   				AND TD.UserKey <>  @c_userid 
   				AND TD.STatus = '3'
   	   END	
   END     
    

    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        IF ISNULL(RTRIM(@c_LastLoc),'') <> ''
        BEGIN
            SELECT @c_LastAisle = LocAisle 
            FROM   LOC L WITH (NOLOCK)
            WHERE  LOC = @c_LastLoc 
        END
        ELSE
           SET @c_LastAisle = ''
    END
   ELSE
      SET @c_LastAisle = ''
    
    DECLARE @c_Priority NVARCHAR(10)

    STARTPROCESSING:
    
    WHILE (1=1) AND
          (@n_continue=1 OR @n_continue=2)
    BEGIN
        IF @b_debug=1
        BEGIN
            SELECT 'Start Evaluating'
        END

        DECLARECUR_PICK_TASK:        
        -- Get Next Task
        -- Order By:
        -- Same Area with Highest Priority
        -- Same Aisle Highest Priority, then other Aisle
        -- Task Priority 
        -- Same Load with Previous Load have Highest Priority 
        -- Logical Location 
         DECLARE CUR_PICK_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT DISTINCT TaskDetailKey,
                CASE WHEN AreaDetail.AreaKey = @c_areakey01 THEN '' ELSE AreaDetail.AreaKey END AS Area,
                CASE WHEN LOC.LocAisle = @c_LastAisle THEN '' ELSE LOC.LocAisle END AS Aisle,
                TASKDETAIL.Priority, 
                CASE WHEN LOADPLAN.LoadKey = @c_LastLoadKey 
                           AND ISNULL(LOADPLAN.LoadKey,'') <> '' THEN '' ELSE LOADPLAN.LoadKey
                END as LoadKey,  
                LOC.LogicalLocation,
                TASKDETAIL.PickMethod -- (Vicky01)
         FROM   TASKDETAIL WITH (NOLOCK)
         INNER JOIN LOC WITH (NOLOCK) 
                  ON TaskDetail.FromLoc = Loc.Loc                     
         INNER JOIN AREADETAIL WITH (NOLOCK) 
                  ON AreaDetail.Putawayzone = Loc.PutAwayZone              
         INNER JOIN TaskManagerUserDetail WITH (NOLOCK) 
                  ON TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey 
         LEFT OUTER JOIN LOADPLAN WITH (NOLOCK)
                  ON LOADPLAN.LoadKey = TaskDetail.LoadKey    
         WHERE  TaskManagerUserDetail.UserKey = @c_userid AND
                TaskManagerUserDetail.PermissionType = 'PK' AND
                TaskManagerUserDetail.Permission = '1' AND
                TaskDetail.TASKTYPE = 'PK' AND
                TaskDetail.STATUS = '0' AND 
                TaskDetail.Userkey = '' AND -- (Vicky02)
                TaskManagerUserDetail.AreaKey = 
                  CASE WHEN ISNULL(RTRIM(@c_areakey01),'') = '' THEN AreaDetail.AreaKey ELSE @c_areakey01 END  
					 AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01)
                         WHERE AIU.LocAisle = LOC.LocAisle )	
         ORDER BY 
                TASKDETAIL.Priority,
                TASKDETAIL.PickMethod, -- (Vicky01)
                CASE WHEN LOC.LocAisle = @c_LastAisle THEN '' ELSE LOC.LocAisle END,
                CASE WHEN AreaDetail.AreaKey = @c_areakey01 THEN '' ELSE AreaDetail.AreaKey END,
                CASE WHEN LOADPLAN.LoadKey = @c_LastLoadKey 
                           AND ISNULL(LOADPLAN.LoadKey,'') <> '' THEN '' ELSE LOADPLAN.LoadKey
                END,  
                LOC.LogicalLocation
         
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16915
         BEGIN
            CLOSE CUR_PICK_TASK
            DEALLOCATE CUR_PICK_TASK
            GOTO DECLARECUR_PICK_TASK
         END
         OPEN CUR_PICK_TASK
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err = 16905
         BEGIN
            CLOSE CUR_PICK_TASK
            DEALLOCATE CUR_PICK_TASK
            GOTO DECLARECUR_PICK_TASK
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81202   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Could not Open CUR_PICK_TASK. (nspTTMPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END                                     
         ELSE
         BEGIN
            SELECT @b_Cursor_PickTaskOpen = 1
         END
         
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            WHILE (1=1)
            BEGIN
               FETCH NEXT FROM CUR_PICK_TASK INTO @c_taskdetailkey, @c_Area, @c_Aisle, @c_Priority, @c_LoadKey,
                     @c_logicalloc, @c_pickmethod -- (Vicky01)  
                                                   
               IF @@FETCH_STATUS <> 0
               BEGIN
                  BREAK
               END
                                      
               SELECT TOP 1
                     @c_TaskDetailKey = TaskDetailKey
                    ,@c_CaseID = CaseID
                    ,@c_Orderkey = orderkey
                    ,@c_OrderLineNumber = OrderLineNumber
                    ,@c_WaveKey = wavekey
                    ,@c_storerkey = storerkey
                    ,@c_sku = sku
                    ,@c_loc = fromloc
                    ,@c_logicalloc = logicalfromloc
                    ,@c_id = fromid
                    ,@c_lot = lot
                    ,@c_uom = uom
                    ,@c_userkeyoverride = userkeyoverride
                    ,@c_LoadKey = LoadKey
                    ,@n_Qty  = Qty 
              FROM   TASKDETAIL WITH (NOLOCK)
              WHERE  TaskDetailKey = @c_TaskDetailKey
                    
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
        
        BREAK
        CHECKROW:
        SET ROWCOUNT 0
        IF @b_debug=1
        BEGIN
            SELECT 'evaluationtype'
                  ,@b_EvaluationType
                  ,'TaskDetailKey='
                  ,@c_TaskDetailKey
                  ,'CaseID='
                  ,@c_CaseID
                  ,'orderkey='
                  ,@c_orderkey
                  ,'OrderLineNumber='
                  ,@c_OrderLineNumber
                  ,'wavekey='
                  ,@c_WaveKey
                  ,'storer='
                  ,@c_storerkey
                  ,'sku='
                  ,@c_sku
                  ,'loc='
                  ,@c_loc
                  ,'logicalloc='
                  ,@c_logicalloc
                  ,'id='
                  ,@c_id
                  ,'lot='
                  ,@c_lot
                  ,'uom='
                  ,@c_uom
                  ,'userkeyoverride='
                  ,@c_userkeyoverride
        END
        
        IF @b_RowCheckPass=0
        BEGIN
            IF @b_debug=1
            BEGIN
                SELECT 'Row candidate check #1 - area authorization...'
            END
            
            IF ISNULL(RTRIM(@c_areakey01),'') = ''
            BEGIN
                IF NOT EXISTS(
                       SELECT 1
                       FROM   TaskManagerUserDetail WITH (NOLOCK)
                             ,AreaDetail WITH (NOLOCK)
                             ,Loc WITH (NOLOCK)
                       WHERE  TaskManagerUserDetail.UserKey = @c_userid AND
                              TaskManagerUserDetail.PermissionType = 'PK' AND
                              TaskManagerUserDetail.Permission = '1' AND
                              TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey AND
                              AreaDetail.Putawayzone = Loc.PutAwayZone AND
                              Loc.Loc = @c_loc
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
                       INNER JOIN Loc ON Loc.PutawayZone = AreaDetail.PutawayZone 
                       WHERE  AreaDetail.AreaKey = @c_areakey01 AND
                              Loc.Loc = @c_loc
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
                
                SELECT @c_userkeyoverride
                      ,@c_userkeyoverride
                      ,@c_userid
            END
            
            IF NOT (@c_userkeyoverride='' OR @c_userkeyoverride=@c_userid)
            BEGIN
                GOTO EVALUATIONDONE
            END
        END
        
        IF @b_RowCheckPass=0
        BEGIN
            SELECT @b_success = 0
                  ,@b_skipthetask = 0
            
            EXECUTE nspCheckSkipTasks
            @c_userid
            , @c_TaskDetailKey
            , 'PK'
            , @c_TaskDetailKey -- 'BATCHPICK' --@c_CaseID
            , ''
            , ''
            , ''
            , ''
            , ''
            , @b_skipthetask OUTPUT
            , @b_Success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            IF @b_success<>1
            BEGIN
                SELECT @n_continue = 3
            END
            
            IF @b_skipthetask=1
            BEGIN
                GOTO EVALUATIONDONE
            END
        END
        
        IF @b_RowCheckPass=0
        BEGIN
            SELECT @b_success = 0
            EXECUTE nspCheckEquipmentProfile
              @c_userid=@c_userid
            , @c_TaskDetailKey=''
            , @c_storerkey=@c_storerkey
            , @c_sku=@c_sku
            , @c_lot=@c_lot
            , @c_fromLoc=@c_loc
            , @c_fromID=@c_id
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
        
        GOTO EVALUATIONTYPERETURN_01
        
        DISPATCH:
        
        IF @b_debug=1
        BEGIN
            SELECT 'Entering dispatch'
            SELECT '@c_uom' = @c_uom
        END
        
        DISPATCHCHECK:
        
        DISPATCHEXECUTE:
        
        IF @n_continue=1 OR
           @n_continue=2
        BEGIN
            IF @b_debug=1
            BEGIN
                SELECT 'Dispatch Execute...'
            END
            
            IF ISNULL(RTRIM(@c_sku),'') <> '' 
            BEGIN 
               SELECT @c_packkey = PACKKEY
               FROM   SKU(NOLOCK)
               WHERE  STORERKEY = @c_storerkey AND
                      SKU = @c_sku 
            END 
            

           IF ISNULL(RTRIM(@c_OrderKey),'') = '' AND ISNULL(RTRIM(@c_LoadKey),'') <> ''
           BEGIN
              -- Getting the Min(OrderKey) FROM LOAD
              SELECT TOP 1 
                     @c_OrderKey = p.ORDERKEY,
                     @c_OrderLineNumber = p.OrderLineNumber,
                     @c_packkey = CASE WHEN ISNULL(RTRIM(@c_packkey),'') = '' 
                                       THEN p.PackKey ELSE @c_packkey 
                                  END,
                     @c_SKU = CASE WHEN ISNULL(RTRIM(@c_SKU),'') = '' 
                                       THEN p.SKU ELSE @c_SKU 
                                  END              
              FROM   LoadPlanDetail lpd WITH (NOLOCK)
              JOIN   PICKDETAIL p WITH (NOLOCK) ON p.OrderKey = lpd.OrderKey 
              WHERE  lpd.LoadKey = @c_LoadKey 
              AND    p.Loc = @c_LOC 
              AND    p.id = @c_id 
              ORDER BY p.OrderKey, p.OrderLineNumber 
               
           END

            SELECT @c_uomtext = ''
            IF ISNULL(RTRIM(@c_packkey),'') <> ''
            BEGIN
                SELECT @c_uomtext = packuom3
                FROM   PACK(NOLOCK)
                WHERE  PACKKEY = @c_packkey
            END
                       
           IF ISNULL(RTRIM(@c_LoadKey),'') = ''
           BEGIN
               DECLARE CURSOR_PKTASKCANDIDATES  CURSOR  
               FOR
                SELECT @c_TaskDetailKey
                      ,@c_CaseID             
                      ,@c_orderkey           
                      ,@c_OrderLineNumber    
                      ,@c_WaveKey            
                      ,@c_storerkey          
                      ,@c_sku                
                      ,@c_lot                
                      ,@c_loc                
                      ,@c_id                 
                      ,@c_packkey            
                      ,@c_uomtext            
                      ,@n_Qty      
                      ,@c_message01          
                      ,@c_message02          
                      ,@c_message03                                                         
           END
           ELSE
           BEGIN
               DECLARE CURSOR_PKTASKCANDIDATES  CURSOR  
               FOR
                   SELECT @c_TaskDetailKey
                         ,@c_CaseID             
                         ,@c_OrderKey            
                         ,@c_OrderLineNumber    
                         ,@c_LoadKey            
                         ,@c_storerkey          
                         ,@c_sku                
                         ,@c_lot                
                         ,@c_loc                
                         ,@c_id                 
                         ,@c_packkey            
                         ,@c_uomtext            
                         ,@n_Qty      
                         ,@c_message01          
                         ,@c_message02          
                         ,@c_message03                                                         
           END
           IF @b_debug=1
           BEGIN
               SELECT 'Updating taskmanageruser'
           END
                 
           IF ISNULL(RTRIM(@c_LoadKey),'') = ''
           BEGIN
               UPDATE TASKMANAGERUSER WITH (ROWLOCK) 
               SET    LastCaseIDPicked = @c_CaseID
                     ,Lastwavekey = @c_WaveKey
                     ,LastLoadKey = @c_LoadKey
                     ,LastLoc = @c_loc
                     ,LastDropID = @c_ID
               WHERE  USERKEY = @c_userid
           END
           
           GOTO DONE
       END
   END -- WHILE 1=1
    
    SET ROWCOUNT 0
    NOTHINGTOSEND:
    
    IF @b_debug=1
    BEGIN
        SELECT 'Nothing to send...'
    END
    
    DECLARE CURSOR_PKTASKCANDIDATES  CURSOR  
    FOR
        SELECT ''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,''
              ,0                     
              ,''
              ,''
              ,''
    DONE:
    
    IF @b_debug=1
    BEGIN
        SELECT 'DONE'
    END
    
    IF @b_CUR_PICK_TASK_open=1
    BEGIN
        CLOSE CUR_PICK_TASK
        DEALLOCATE CUR_PICK_TASK
    END
    
    /* #INCLUDE <SPTMPK01_2.SQL> */
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        SELECT @b_success = 0
        IF @@TRANCOUNT=1 AND
           @@TRANCOUNT>@n_starttcnt
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
        EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMPK02'
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