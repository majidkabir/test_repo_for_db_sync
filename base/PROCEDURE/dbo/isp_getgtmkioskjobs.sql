SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetGTMKioskJobs                                */
/* Creation Date: 26-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Get GTMJob                                                  */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: event                                                     */
/*          : w_gtm_kiosk.ue_perform_job                                */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 20-NOV-2015  YTwan   1.1   Call Alert Supervisor after call PA (Wan01)*/
/* 10-DEC-2015  WAN02   1.21  SSCC SKU Not Allow Reverse Pick           */
/* 21-DEC-2015  WAN03   1.22  Project Merlion - GTM Kiosk Enhancement   */ 
/* 26-FEB-2016  WAN04   1.3   Get status '5' job if B pallet had been   */
/*                            released & move out but C released  fail  */
/* 04-JAN-2018  Wan05   1.4   WMS-7286-PRHK - GTM Picking For COPACK Sku*/
/* 05-APR-2021  Wan06   1.5   WMS-16593-SG-ASRS-GTM Picking Enhancement */
/*                            CPI                                       */
/************************************************************************/
CREATE PROC [dbo].[isp_GetGTMKioskJobs]
            @c_GTMWorkStation NVARCHAR(10) 
         ,  @c_JobKey         NVARCHAR(10)   OUTPUT
         ,  @c_TaskDetailKey  NVARCHAR(10)   OUTPUT
         ,  @c_ID             NVARCHAR(18)   OUTPUT
         ,  @c_PickToID       NVARCHAR(18)   OUTPUT
         ,  @c_PanelLUOClass  NVARCHAR(60)   OUTPUT
         ,  @c_PanelMUOClass  NVARCHAR(60)   OUTPUT
         ,  @c_PanelRUOClass  NVARCHAR(60)   OUTPUT
         ,  @b_Scheduler      INT = 0        OUTPUT
         ,  @b_Success        INT = 0        OUTPUT 
         ,  @n_err            INT = 0        OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
         ,  @b_debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 

         , @c_InProcJobKey          NVARCHAR(10)
         , @c_InProcTaskDetailKey   NVARCHAR(10)
         , @c_InProcTaskType        NVARCHAR(10)
         , @c_InProcPickMethod      NVARCHAR(10)
         , @c_InProcLogicalPickFrom NVARCHAR(10)
         , @c_InProcLogicalPickto   NVARCHAR(10)

         , @c_TaskType              NVARCHAR(10)
         , @c_PickMethod            NVARCHAR(10)
         , @c_JobStatus             NVARCHAR(10)
         , @c_NewStatus             NVARCHAR(10)
         , @b_Active                INT

         , @c_PickToIDLoc           NVARCHAR(10)
         , @c_FinalIDInB            NVARCHAR(18)
         , @c_FinalIDLoc            NVARCHAR(10)    

         , @c_LogicalPickFrom       NVARCHAR(10)
         , @c_LogicalPickTo         NVARCHAR(10)
         , @c_LogicalMoveFrom       NVARCHAR(10)
         , @c_LogicalMoveTo         NVARCHAR(10)

         , @c_MoveFromloc           NVARCHAR(10)
         , @c_MoveToloc             NVARCHAR(10)

         , @n_IDQty                 FLOAT
         , @n_PickToQty             FLOAT
         , @n_NoOfSku               INT

         , @c_MessageName           NVARCHAR(15)
         , @c_MessageType           NVARCHAR(10)

         ,@c_Sku                    NVARCHAR(20) = ''                                                       --(Wan05)
         ,@c_COPackSku              NVARCHAR(20) = ''                                                       --(Wan05)
         ,@n_NoOfCOSku              INT          = 0                                                        --(Wan05)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_err       = 0
   SET @c_errmsg    = ''

   SET @c_TaskDetailKey = ''
   SET @c_ID            = ''
   SET @c_PanelLUOClass = ''
   SET @c_PanelMUOClass = ''
   SET @c_PanelRUOClass = ''
   SET @c_InProcTaskType= ''

   SET @b_Scheduler = 1
   SET @b_Active    = 0
   SET @c_NewStatus = ''

   SET @c_InProcTaskDetailKey = ''
 

   -- Initialize StatusMsg if it is 1 and JobStatus < '3' 
   SET @c_JobKey   = ''
   SELECT TOP 1 @c_JobKey = TaskDetailKey
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskType = 'GTMJOB'
   AND Status < '3'
   AND UserPosition = @c_GTMWorkStation
   AND StatusMsg = '1'
   AND EXISTS ( SELECT 1
                FROM ID  WITH (NOLOCK)
                JOIN LOC WITH (NOLOCK) ON (ID.VirtualLoc = LOC.LOC)
                WHERE ID.ID = TASKDETAIL.FromID
                AND   LOC.LocationGroup = TASKDETAIL.UserPosition
              )
   ORDER BY TaskDetailKey

   IF @c_JobKey <> '' 
   BEGIN
      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET StatusMsg = ''
      ,Trafficcop   = NULL
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
      WHERE TaskDetailKey = @c_JobKey   
   END

   SET @c_JobKey   = ''
   SET @c_PickToID = ''

   SELECT TOP 1 @c_JobKey        = TaskDetailKey
               ,@c_TaskDetailKey = RefTaskkey
               ,@c_Id            = FromID
               ,@c_FinalIDInB    = FinalID
               ,@c_FinalIDLoc    = FinalLoc
               ,@c_PickToID      = ToID
               ,@c_PickMethod    = PickMethod
               ,@c_JobStatus     = Status
               ,@c_LogicalPickFrom= LogicalFromLoc
               ,@c_LogicalPickTo  = LogicalToLoc
               ,@b_Active         = StatusMsg
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskType = 'GTMJOB'
   AND Status < '9'
   AND UserPosition = @c_GTMWorkStation
   AND StatusMsg <> '1'
   AND EXISTS ( SELECT 1
                FROM ID  WITH (NOLOCK)
                JOIN LOC WITH (NOLOCK) ON (ID.VirtualLoc = LOC.LOC)
                --WHERE ID.ID = TASKDETAIL.FromID                                                          -- (Wan04)
                WHERE (ID.ID = TASKDETAIL.FromID OR (ID.ID = TASKDETAIL.ToID AND TASKDETAIL.Status = '5')) -- (Wan04)
                AND   LOC.LocationGroup = TASKDETAIL.UserPosition
              )
   ORDER BY TaskDetailKey

   IF @c_JobKey = ''
   BEGIN
      GOTO QUIT_SP
   END

   -- if a->b asrspk task, get tasktype from taskdetailkey = @c_TaskDetailKey will do
   -- as 1 of the ASRSPK's taskdetail.taskdetailkey = GTMJOB's taskdetail.RefTaskKey
   SET @c_TaskType = '' 
   SELECT @c_TaskType = TaskType
         ,@c_Sku       = Sku                                                                                --(Wan05)                                        
         ,@c_COPackSku = Message02                                                                          --(Wan05)
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailkey = @c_TaskDetailKey

   IF @b_debug = 1
   BEGIN
      SELECT  @c_TaskDetailKey '@c_TaskDetailKey' 
      ,@c_TaskType'@c_TaskType'
      ,@c_Sku '@c_Sku'
      ,@c_COPackSku '@c_COPackSku'
   END 

   SELECT @c_InProcJobKey        = Taskdetailkey
         ,@c_InProcTaskDetailKey = RefTaskKey
         ,@c_InProcPickMethod    = PickMethod
         ,@c_InProcLogicalPickFrom= LogicalFromLoc
         ,@c_InProcLogicalPickTo  = LogicalToLoc
         ,@c_JobStatus            = Status
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskType = 'GTMJOB'
   AND Status >= '3' AND Status < '9'
   AND UserPosition = @c_GTMWorkStation
   AND StatusMsg = '1'
   AND EXISTS ( SELECT 1
                  FROM ID  WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (ID.VirtualLoc = LOC.LOC)
                  WHERE ID.ID = TASKDETAIL.FromID
                  AND   LOC.LocationGroup = TASKDETAIL.UserPosition
              )


   IF @c_InProcTaskDetailKey <> ''
   BEGIN
      SELECT @c_InProcTaskType = TaskType
      FROM TASKDETAIL WITH (NOLOCK)
      WHERE TaskdetailKey = @c_InProcTaskDetailKey

      IF @c_TaskType <> @c_InProcTaskType
      BEGIN
         SET @c_JobStatus = '0'     -- Not to Get PanelClass in QUIT_SP 
      END

      SET @b_Scheduler = 0
      --SET @c_JobKey = @c_InProcJobKey 
      SET @c_PickMethod = @c_InProcPickMethod
      SET @c_LogicalPickFrom = @c_InProcLogicalPickFrom 
      SET @c_LogicalPickTo   = @c_InProcLogicalPickTo
      --GOTO UPD_JOB
      GOTO QUIT_SP
   END

   -------------------------------------------------------------
   -- Validation Check that return error must be code after here
   -------------------------------------------------------------
   -- Check Valid GTMJOB LogicalFromLoc AND LogicalToLoc before start picking
   IF ISNULL(@c_LogicalPickFrom,'') = '' OR ISNULL(@c_LogicalPickTo,'') = ''
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='Invalid LogicalFromLoc or LogicalToLoc in GTMJOB record. jobkey: ' + @c_JobKey + ' (isp_GetGTMKioskJobs)'
      GOTO QUIT_SP
   END

   SET @c_NewStatus = @c_JobStatus

   BEGIN TRAN
   IF @c_JobStatus = '0'  
   BEGIN
      SET @c_PickMethod = 'F'

      SET @c_PickToID = ''
      IF @c_LogicalPickFrom <> @c_LogicalPickTo
      BEGIN
         -- GET Empty Pallet ID from C location
          SET @c_PickToIDLoc = ''
         SELECT @c_PickToID = ID.ID 
               ,@c_PickToIDLoc = ID.Virtualloc
         FROM ID WITH (NOLOCK)
         WHERE EXISTS ( SELECT 1 
                   FROM LOC WITH (NOLOCK)
                   WHERE LOC.Loc = ID.VirtualLoc   
                   AND LOC.LocationGroup = @c_GTMWorkStation 
                   AND LOC.LogicalLocation = 'c'
                  )
         IF @c_PickToID = ''
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT  'QUIT_SP'
            END 
            GOTO QUIT_SP
         END

         IF EXISTS ( SELECT 1
                     FROM LOTxLOCxID WITH (NOLOCK)
                     WHERE ID = @c_PickToID
                     AND Qty > 0
                   ) 
         BEGIN
            -- Exclude empty pick to pallet checking when retrigger job scheduler to 
            -- move inv pallet from a to b after release inv pallet from b as pick to pallet
            -- remain in c pending for next pallet picking for the same order
            IF NOT (@c_TaskType = 'ASRSPK' AND 
               EXISTS (SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
                                WHERE ID = @c_PickToID AND Status = '5'
                                AND   EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK)
                                              WHERE TASKDETAIL.Taskdetailkey = @c_TaskDetailKey
                                              AND PICKDETAIL.Orderkey = TASKDETAIL.Orderkey
                                              )
                        ))
            BEGIN
               SET @c_ErrMsg = ''
    
               SET @c_MessageName  = 'PUTAWAY'
               SET @c_MessageType  = 'SEND'

               IF @b_debug = 0
               BEGIN
                  EXEC isp_TCP_WCS_MsgProcess
                           @c_MessageName  = @c_MessageName
                        ,  @c_MessageType  = @c_MessageType
                        ,  @c_PalletID     = @c_PickToID
                        ,  @c_FromLoc      = @c_PickToIDLoc
                        ,  @c_ToLoc       = ''  
                        ,  @c_Priority    = '5'
                        ,  @c_TaskDetailKey= @c_Taskdetailkey
                        ,  @b_Success      = @b_Success  OUTPUT
                        ,  @n_Err          = @n_Err     OUTPUT
                        ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
                  
               END

               IF  @b_debug = 1 
               BEGIN
                  SELECT @n_Continue , @c_MessageName
                  SELECT @c_PickToIDLoc '@c_PickToIDLoc'
               END

               IF @b_Success <> 1   
               BEGIN  
                  SET @n_continue = 3    
                  SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (isp_GetGTMKioskJobs)' 
                               + '( ' + @c_ErrMsg + ' )'
                  GOTO QUIT_SP
               END

               --(Wan01) - START
               SET @c_ErrMsg = 'Descrepancy Found on pallet: ' + @c_PickToID
               EXEC isp_KioskASRSAlertSupv
                     @c_JobKey    = @c_JobKey
                   , @c_id        = @c_PickToID
                   , @b_hold      = '0'
                   , @b_success   = @b_success    OUTPUT
                   , @n_err       = @n_Err        OUTPUT
                   , @c_errmsg    = @c_ErrMsg     OUTPUT
                  

               IF @b_success <> 1 
               BEGIN
                  SET @n_Continue=3
                  SET @n_err = 62010
                  SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Error executing isp_KioskASRSAlertSupv. (isp_GetGTMKioskJobs)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                  GOTO QUIT_SP
               END
               --(Wan01) - END
               GOTO QUIT_SP 
            END
         END 
         ELSE
         BEGIN -- Check Reverse PICK if c Pallet is empty pallet
            SELECT @n_IDQty = SUM(Qty)
                  ,@n_NoOfSku = COUNT(1)
                  ,@n_NoOfCOSku = COUNT(DISTINCT CASE WHEN SKU = @c_Sku THEN 'COPACKSU'                     --(Wan05)
                                                      WHEN SKU = @c_COPackSku THEN 'COPACKSU'               --(Wan05)
                                                      ELSE SKU                                              --(Wan05)
                                                      END                                                   --(Wan05)
                                       )
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE Id = @c_id
            AND Qty > 0
            GROUP BY LOC
                  ,  ID

            IF @b_debug = 1
            BEGIN
               SELECT @n_NoOfCOSku'@n_NoOfCOSku'
                     ,@c_COPackSku '@c_COPackSku'
                     ,@n_NoOfSku  '@n_NoOfSku'
            END 

            SET @n_PickToQty = 0
            IF @n_NoOfSku = 1 OR (@n_NoOfCOSku = 1 AND @c_COPackSku <> '')                                  --(Wan05)
            BEGIN
               IF @c_TaskType = 'ASRSPK'  
               BEGIN
                  IF EXISTS ( SELECT 1 
                              FROM PICKDETAIL WITH (NOLOCK)
                              JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                                     AND(PICKDETAIL.Sku = SKU.Sku)
                              WHERE PICKDETAIL.ID = @c_ID
                              AND PICKDETAIL.Status < '5' 
                              AND ISNULL(SKU.SUSR4,'') <> 'SSCC'
                              GROUP BY PICKDETAIL.ID
                             -- HAVING COUNT(DISTINCT PICKDETAIL.Orderkey) <= 1                             --(Wan06)
                            )
                  BEGIN
                     SET @n_PickToQty = 0
                     SELECT @n_PickToQty = SUM(Qty)
                     FROM PICKDETAIL WITH (NOLOCK)
                     WHERE TaskDetailKey = @c_TaskDetailKey
                     AND Id = @c_ID
                  END
               END  

               IF @c_TaskType = 'ASRSTRF' 
               BEGIN
                  IF EXISTS ( SELECT 1 
                              FROM TRANSFERDETAIL WITH (NOLOCK)
                              WHERE FromID = @c_ID
                              AND Status < '9'
                              GROUP BY FromID
                              HAVING COUNT(DISTINCT TransferKey) <= 1
                            )
                  BEGIN
                     SELECT @n_PickToQty = SUM(FromQty)
                     FROM TRANSFERDETAIL WITH (NOLOCK)
                     JOIN TASKDETAIL WITH (NOLOCK) ON (TRANSFERDETAIL.TransferKey = TASKDETAIL.SourceKey)
                     WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey
                     AND TRANSFERDETAIL.FromID = @c_ID
                  END
               END

               IF ((@n_PickToQty / @n_IDQty) * 100.00) > 50  AND @n_IDQty >= @n_PickToQty -- Include 100% picking
               BEGIN
                  SET @c_PickMethod = 'R'    -- Reverse
               END 
            END
         END
      END

      IF @b_debug = 1
      BEGIN
         SELECT @c_PickMethod'@c_PickMethod'
               , @c_TaskType '@c_TaskType'
               ,@c_LogicalPickFrom '@c_LogicalPickFrom'
               ,@c_LogicalPickTo  '@c_LogicalPickTo'
      END 

      SELECT @c_LogicalMoveFrom = LogicalMoveFrom
            ,@c_LogicalMoveTo   = LogicalMoveTo
      FROM V_GTMKioskASRSTask
      WHERE GTMWorkStation = @c_GTMWorkStation
      AND TaskType = @c_TaskType
      AND PickMethod = @c_PickMethod
      AND LogicalPickFrom = @c_LogicalPickFrom
      AND LogicalPickTo   = @c_LogicalPickTo
                                    
      SELECT @c_MoveFromLoc = Loc
      FROM LOC WITH (NOLOCK)
      WHERE LocationGroup = @c_GTMWorkStation
      AND LogicalLocation = @c_LogicalMoveFrom 
                                  
      SELECT @c_MoveToLoc = Loc
      FROM LOC WITH (NOLOCK)
      WHERE LocationGroup = @c_GTMWorkStation
      AND LogicalLocation = @c_LogicalMoveTo
       
      IF @b_debug = 1
      BEGIN
         SELECT @c_GTMWorkStation'@@c_GTMWorkStation'
               ,@c_LogicalMoveFrom '@@c_LogicalMoveFrom'
               ,@c_LogicalMoveTo  '@@c_LogicalMoveTo'
               ,@c_MoveFromLoc '@c_MoveFromLoc'
               ,@c_MoveToLoc '@c_MoveToLoc'
      END 

      SET @c_FinalIDInB = ''
      SELECT @c_FinalIDInB = ID.Id
      FROM ID  WITH (NOLOCK) 
      WHERE VirtualLoc = @c_MoveFromLoc

      IF @c_FinalIDInB NOT IN (@c_ID, @c_PickToID) 
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='Physical Pallet at virtualloc: ' +  @c_MoveFromLoc 
           + ' does not match with GTMJOB Inventory Pallet to Pick To Pallet. Jobkey: ' + @c_Jobkey + ' (isp_GetGTMKioskJobs)'
         GOTO QUIT_SP
      END

      SET @c_FinalIDLoc = @c_MoveToLoc
      
      IF @b_debug = 1
      BEGIN
         select @c_MoveFromLoc '@c_MoveFromLoc', @c_LogicalMoveFrom '@c_LogicalMoveFrom'
         select @c_FinalIDInB '@c_FinalIDInB' , @c_ID '@c_ID'
      END   
         
      -- Send Move
      SET @c_MessageName  = 'MOVE'
      SET @c_MessageType  = 'SEND'

      IF @b_debug = 0
      BEGIN
         EXEC isp_TCP_WCS_MsgProcess
                  @c_MessageName  = @c_MessageName
               ,  @c_MessageType  = @c_MessageType
               ,  @c_PalletID     = @c_FinalIDInB --@c_ID
               ,  @c_FromLoc      = @c_MoveFromLoc
               ,  @c_ToLoc        = @c_MoveToLoc  
               ,  @c_Priority     = '5'
               ,  @c_TaskDetailKey= @c_Taskdetailkey
               ,  @b_Success      = @b_Success  OUTPUT
               ,  @n_Err          = @n_Err      OUTPUT
               ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
      END
      IF @b_Success <> 1   
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (isp_GetGTMKioskJobs)' 
                      + '( ' + @c_ErrMsg + ' )'
         GOTO QUIT_SP
      END 
      SET @c_NewStatus = '1'
   END        

   IF @c_JobStatus = '1'
   BEGIN
       -- Check Expected ID arrive in B Position (FinalIDLoc)
      IF EXISTS ( SELECT 1 FROM ID WITH (NOLOCK)
                  WHERE ID = @c_FinalIDInB
                  AND VirtualLoc = @c_FinalIDLoc
                )
      BEGIN
         SET @c_NewStatus = '2'
      END
   END

   IF @c_JobStatus = '2'
   BEGIN
      SET @c_NewStatus = '3'
   END

   IF @c_JobStatus >= '3' AND @c_JobStatus < '9'
   BEGIN
      SET @b_Scheduler = 0

      IF @c_TaskType = 'ASRSPK' AND @c_PickMethod = 'F' 
      BEGIN
         IF @c_LogicalPickFrom = 'b'
         BEGIN  
            SET @b_Active = 1  
            SET @b_Scheduler = 1
         END
      END
   END

   UPD_JOB:

   --if display pending job in A when perform B C job, only reset statusmsg
   UPDATE TASKDETAIL WITH (ROWLOCK)
   SET Status       = CASE WHEN StatusMsg = '1' THEN Status     ELSE @c_NewStatus  END  
      ,ToID         = CASE WHEN StatusMsg = '1' THEN ToID       ELSE @c_PickToID   END 
      ,FinalID      = CASE WHEN StatusMsg = '1' THEN FinalID    ELSE @c_FinalIDInB END
      ,FinalLoc     = CASE WHEN StatusMsg = '1' THEN FinalLoc   ELSE @c_FinalIDLoc END
      ,PickMethod   = CASE WHEN StatusMsg = '1' THEN PickMethod ELSE @c_PickMethod END
      ,SourceType   = CASE WHEN StatusMsg = '1' THEN SourceType ELSE @c_TaskType   END
      ,StatusMsg    = @b_Active
      ,Trafficcop   = NULL
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
   WHERE TaskDetailKey = @c_JobKey


   IF @@ERROR <> 0   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Fail. (isp_GetGTMKioskJobs)' 
                   + '( ' + @c_ErrMsg + ' )'
      GOTO QUIT_SP
   END 

QUIT_SP:

   -- 1. if there is task in process & current task in ASRSPK task, 
   --    show A Panel else disable A panel
   -- 2. if no task in process and to process, nothing to show
   -- 3. if no task to process, nothing to show
   -- 4. if there is no task in process & current task start in process, 
   --    show task on Panel except Pick forward task (ASRSPK); show its B & C panels only

   IF @n_Continue=1  -- Error Occured - Process And Return
   BEGIN
--      IF (@c_TaskType = 'ASRSPK' AND @c_InProcTaskType = 'ASRSPK' AND @c_InProcPickMethod = 'F' AND
--          @c_InProcLogicalPickFrom = 'b') OR
--          @c_NewStatus = '3' OR ( @c_JobStatus >= '3' AND  @c_JobStatus < '9' )
      IF @c_JobStatus >= '3' AND  @c_JobStatus < '9'
      BEGIN 
         SELECT @c_PanelLUOClass = PanelLUOClass
               ,@c_PanelMUOClass = PanelMUOClass
               ,@c_PanelRUOClass = PanelRUOClass
         FROM V_GTMKioskASRSTask
         WHERE GTMWorkStation = @c_GTMWorkStation
         AND TaskType = @c_TaskType
         AND PickMethod = @c_PickMethod
         AND LogicalPickFrom = @c_LogicalPickFrom
         AND LogicalPickTo   = @c_LogicalPickTo
   
         IF @c_TaskType = 'ASRSPK' AND @c_PickMethod = 'F' AND @c_LogicalPickFrom = 'b'  
         BEGIN 
            IF @c_InProcTaskType = ''  
            BEGIN
               SET @c_PanelLUOClass = CASE WHEN RIGHT(@c_PanelLUOClass,1) = 'a' THEN '' ELSE @c_PanelLUOClass END
               SET @c_PanelRUOClass = CASE WHEN RIGHT(@c_PanelRUOClass,1) = 'a' THEN '' ELSE @c_PanelRUOClass END
            END
            ELSE
            BEGIN
               SET @c_PanelLUOClass = CASE WHEN RIGHT(@c_PanelLUOClass,1) = 'a' THEN @c_PanelLUOClass ELSE '' END
               SET @c_PanelMUOClass = ''
               SET @c_PanelRUOClass = CASE WHEN RIGHT(@c_PanelRUOClass,1) = 'a' THEN @c_PanelRUOClass ELSE '' END
            END 
         END  
      END
   END
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetGTMKioskJobs'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO