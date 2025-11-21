SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_KioskASRSReleasePLT                            */
/* Creation Date: 27-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Release All Palllets; Inv Pallet and PickTo Pallet          */
/*        : Move to ASRS or OutBound                                    */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By:                                                           */
/*          : w_gtm_kiosk.ue_releasepallet event                        */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 24-NOV-2015  YTWan   1.0   Fixed Error Log Module name (Wan01)       */
/* 01-DEC-2015  YTWan   1.2   SOS#358101- Project Merlion GTM Empty     */
/*                            Pallet Damaged for Rejection (Wan02)      */
/* 21-DEC-2015  WAN03   1.22  Project Merlion - GTM Kiosk Enhancement   */ 
/* 21-JAN-2016  WAN04   1.3   TRF To Outbound lane (SOS#315609)         */ 
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSReleasePLT] 
            @c_Jobkey         NVARCHAR(18)
         ,  @c_ReleaseID      NVARCHAR(18) 
         ,  @c_JobStatus      NVARCHAR(10) OUTPUT
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
         ,  @b_RejEmptyPLT    INT = 0
         ,  @b_AutoPLTMvStrat INT = 0 
         ,  @b_debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_ProcessTaskkey     NVARCHAR(10)
         , @c_TaskDetailKey      NVARCHAR(10)
         , @c_TaskType           NVARCHAR(10)
         , @c_PickMethod         NVARCHAR(10)
 
         , @c_TaskStatus         NVARCHAR(10)
         , @c_NewTaskDetailKey   NVARCHAR(10)
         , @c_NewTaskType        NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ID                 NVARCHAR(18)
         , @c_PickToID           NVARCHAR(18)
         , @c_MoveID             NVARCHAR(18)
         , @c_Fromloc            NVARCHAR(10)
         , @c_Toloc              NVARCHAR(10)
         , @c_LogicalfromLoc     NVARCHAR(10)
         , @c_LogicalToLoc       NVARCHAR(10)
         , @c_FinalLoc           NVARCHAR(10)
         , @c_Message01          NVARCHAR(20)

         , @c_LocationCategory   NVARCHAR(10)
         , @c_LocationGroupFr    NVARCHAR(10)
         , @c_LocationGroupTo    NVARCHAR(10)
         , @c_PutawayZone        NVARCHAR(10)

         , @c_Orderkey           NVARCHAR(10)
         , @c_Loadkey            NVARCHAR(10)
         , @c_MBOLkey            NVARCHAR(10)

         , @c_MessageName        NVARCHAR(15)
         , @c_MessageType        NVARCHAR(10)

 
         , @b_ReleasePallets     INT
         , @b_GTMLoop            INT

         , @c_MVPickMehtod       NVARCHAR(10)

   DECLARE @b_TraceFlag          INT
   SET @b_TraceFlag = 0

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @b_GTMLoop  = 0

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END 
 
   SET @b_ReleasePallets = 0 

   SELECT @c_TaskDetailKey = RefTaskKey
         ,@c_ID            = FromID
         ,@c_PickToID      = ToID
         ,@c_PickMethod    = PickMethod
         ,@c_Storerkey     = Storerkey
         ,@c_LocationGroupFr = UserPosition
         ,@c_LogicalFromLoc= LogicalFromLoc
         ,@c_LogicalToLoc  = LogicalToLoc
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE Taskdetailkey = @c_Jobkey
   AND   TaskType = 'GTMJOB'

   -- Get the pallet tasktype
   -- if a->b asrspk, one of the taskdetail.taskdetailkey = taskdetail.reftaskkey
   SET @c_Orderkey = ''
   SELECT @c_TaskType = TaskType
         ,@c_TaskStatus = Status
         ,@c_Orderkey   = Orderkey
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskdetailKey = @c_TaskDetailKey

   /*-------------------------------------*/
   /* Determine Pallet to release (Start) */
   /*-------------------------------------*/
   IF ISNULL(@c_ReleaseID,'') = '' 
   BEGIN
      IF @b_AutoPLTMvStrat = 0
      BEGIN
         GOTO MOVEPLT
      END 

      IF @c_LogicalFromLoc <> @c_LogicalToLoc
      BEGIN
         -- ASRSPK (CPP pick) & ASRSTRF
         IF EXISTS(  SELECT 1
                     FROM TASKDETAIL  TD WITH (NOLOCK)
                     WHERE TD.TaskDetailKey = @c_TaskDetailkey
                     AND   TD.RefTaskKey = '' 
                     AND   TD.Status < '9'
                  )
         BEGIN
            IF @c_Orderkey = ''
            BEGIN
               SET @c_LogicalFromLoc = ''       -- Only Release Pick To Pallet
            END
            ELSE 
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM ORDERS WITH (NOLOCK)
                           WHERE Orderkey = @c_Orderkey
                           AND SOStatus = 'CANC'
                         )
               BEGIN
                  SET @c_LogicalToLoc = ''      -- Only Release Inv Pallet
               END

               IF NOT EXISTS (SELECT 1 
                              FROM PICKDETAIL WITH (NOLOCK)          
                              WHERE Orderkey= @c_Orderkey
                              AND  ID       = @c_ID
                              AND  Status   = '0'
                             )
               BEGIN
                  SET @c_LogicalToLoc = ''      -- Only Release Inv Pallet
               END 
            END  
         END
         --- CIP Pick (Conso Inventory Pick) 
         ELSE IF EXISTS(   SELECT 1
                           FROM TASKDETAIL  TD WITH (NOLOCK)
                           LEFT JOIN ORDERS OH WITH (NOLOCK) ON (TD.Orderkey = OH.Orderkey)
                                                             AND(OH.SOStatus = 'CANC')
                           WHERE TD.RefTaskKey = @c_TaskDetailkey
                           AND   TD.Status < '9'
                           AND   OH.Orderkey IS NULL
                        )
         BEGIN
            SET @c_LogicalFromLoc = ''          -- Only Release Pick To Pallet
         END
      END
   END 
   ELSE
   BEGIN
      IF @c_ReleaseID NOT IN (@c_ID, @c_PickToID) 
      BEGIN
         GOTO QUIT_SP
      END
      --(Wan03) - START
      IF EXISTS ( SELECT 1
                  FROM ID WITH (NOLOCK)
                  JOIN LOC WITH (NOLOCK) ON (LOC.Loc = ID.VirtualLoc)
                  WHERE ID.ID = @c_ReleaseID
                  AND LOC.LocationGroup = @c_LocationGroupFr 
                  AND LOC.LogicalLocation = 'b'
                )
      BEGIN
         IF @c_LogicalFromLoc <> 'b'
            SET @c_LogicalFromLoc = ''

         IF @c_LogicalToLoc <> 'b'
            SET @c_LogicalToLoc = ''
      END

      /*
      IF @c_ReleaseID = @c_ID AND @c_LogicalFromLoc = 'b' AND @c_LogicalFromLoc <> @c_LogicalToLoc
      BEGIN
         SET @c_LogicalToLoc = '' -- Only Release Inventory Pallet
      END

      IF @c_ReleaseID = @c_PickToID AND @c_LogicalToLoc = 'b' AND @c_LogicalFromLoc <> @c_LogicalToLoc
      BEGIN
         SET @c_LogicalFromLoc = '' -- Only Release Pick To Pallet
      END
      */
      --(Wan03) - END
   END
   /*-------------------------------------*/
   /* Determine Pallet to release (End)   */
   /*-------------------------------------*/

   /*-------------------------------------*/
   /* Loop to release Pallet      (Start) */
   /*-------------------------------------*/
   MOVEPLT:

   IF ISNULL(@c_LogicalFromLoc,'') <> '' AND ISNULL(@c_LogicalToLoc,'') <> ''
   BEGIN
      SET @b_ReleasePallets = 1
   END
   IF @b_debug = 1 
   BEGIN
      select @c_ID '@c_ID'
            ,@c_PickToID '@c_PickToID'
            ,@c_LogicalFromLoc '@c_LogicalFromLoc'
            ,@c_LogicalToLoc '@c_LogicalToLoc'
            ,@c_pickmethod '@c_pickmethod'
            ,@b_ReleasePallets '@b_ReleasePallets'

      SELECT ID
      FROM ID WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON (ID.VirtualLoc = LOC.Loc)
      WHERE (ID = @c_ID OR (ID = @c_PickToID AND @c_PickToID <> ''))
      AND LOC.LogicalLocation IN (@c_LogicalFromLoc, @c_LogicalToLoc)
      ORDER BY CASE WHEN LOC.LogicalLocation = 'b' THEN 0 ELSE 1 END
   END


   BEGIN TRAN

   DECLARE CUR_MVID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ID
   FROM ID WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (ID.VirtualLoc = LOC.Loc)
   WHERE (ID = @c_ID OR (ID = @c_PickToID AND @c_PickToID <> ''))
   AND LOC.LogicalLocation IN (@c_LogicalFromLoc, @c_LogicalToLoc)
   ORDER BY CASE WHEN LOC.LogicalLocation = 'b' THEN 0 ELSE 1 END

   OPEN CUR_MVID

   FETCH NEXT FROM CUR_MVID INTO  @c_MoveID        
 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Fromloc = ''
      SET @c_Toloc   = ''
      SET @c_Finalloc= ''
      SET @c_LogicalfromLoc = ''
      SET @c_LogicalToLoc   = ''
      SET @c_MVPickMehtod   = ''

      SELECT @c_Fromloc = VirtualLoc
      FROM ID WITH (NOLOCK)
      WHERE ID = @c_MoveID

      SELECT @c_LogicalfromLoc = LogicalLocation
            ,@c_Fromloc = CASE WHEN LocationGroup = @c_LocationGroupFr THEN Loc ELSE '' END
      FROM  LOC WITH (NOLOCK)
      WHERE Loc = @c_Fromloc

      IF @b_debug = 1 
      BEGIN
         select @c_MoveID '@c_MoveID', @c_Fromloc '@c_Fromloc'
      END

      -- MoveID not in GTMStation   
      IF @c_Fromloc = ''
      BEGIN
         GOTO NEXT_MVID
      END

      /*----------------------   <<Determine Move to Loc>>   -------------------*/ 

      /*-----------------------------------------*/
      /* <<START>> DEFAULT To PA to ASRS         */
      /*-----------------------------------------*/  
      SET @c_NewTaskType =  'ASRSPA'
      SET @c_LocationCategory = 'ASRS'
      SET @c_LocationGroupTo  = ''
      /*-----------------------------------------*/
      /* <<END>> DEFAULT To PA to ASRS           */
      /*-----------------------------------------*/ 

      /*-----------------------------------------*/
      /* <<START>> Check if go EPS               */
      /*-----------------------------------------*/  
      IF NOT EXISTS (SELECT 1 
                     FROM LOTxLOCxID WITH (NOLOCK)
                     WHERE LOTxLOCxID.ID = @c_MoveID --AND @c_MoveID = @c_ID
                     AND Qty > 0 
                     )
      BEGIN
         -- Need to putaway to ASRS if empty inv pallet already alert supervisor
         -- Temparary move to EPS, pending flow for alert supervisor -- 22-apr-2015
         -- EMpty pallet cannot do Putaway bcoz WCS msg requires sku and PA zone

         -- Temparary move to EPS, pending flow for alert supervisor -- 22-apr-2015
         -- EMpty pallet cannot do Putaway bcoz WCS msg requires sku and PA zone
            SET @c_NewTaskType = 'ASRSMV'
            SET @c_LocationCategory = 'ASRSGTM'
            SET @c_LocationGroupTo = 'EPS'

            --(Wan02) - START
            IF @b_RejEmptyPLT = 1 
            BEGIN
               SET @c_LocationCategory = 'VAP'
               SET @c_LocationGroupTo = 'REJECT'
            END
            --(Wan02) - END
      END
      /*-----------------------------------------*/
      /* <<END>> Check if go EPS                 */
      /*-----------------------------------------*/ 

      /*---------------------------------------------------*/
      /* <<START>> If Not go EPS Then Check if go GTMLOOP  */
      /*---------------------------------------------------*/ 
      IF @c_LocationCategory = 'ASRS'
      BEGIN
         -- MoveID's Qty > 0
         -- If there are ASRSPK items to pick, send to GTMLOOP else ASRS/Outbound
         IF EXISTS ( SELECT 1
                     FROM GTMTASK WITH (NOLOCK)
                     WHERE Taskdetailkey <> @c_Taskdetailkey
                     AND  PalletID = @c_MoveID
                     AND   Status < '6'
                   )    
         BEGIN
            -- 21-APR-2015 ALL task send to GTMLOOP
               SET @c_NewTaskType = 'ASRSMV' 
               SET @c_LocationCategory = 'ASRSGTM'
               SET @c_LocationGroupTo = 'GTMLOOP' 

               SET @b_GTMLoop  = 1
         END
         ELSE IF EXISTS (  SELECT 1 
                           FROM TASKDETAIL  TD WITH (NOLOCK)
                           LEFT JOIN ORDERS OH WITH (NOLOCK) ON (TD.Orderkey = OH.Orderkey)
                                                             AND(OH.SOStatus = 'CANC')
                           WHERE TD.TaskDetailKey = @c_TaskDetailkey
                           AND   TD.RefTaskKey = '' 
                           AND   TD.FromID = @c_MoveID
                           AND   TD.Status < '9'
                           AND   TD.TaskType <> 'GTMJOB'
                           AND   OH.Orderkey IS NULL
                         )
         BEGIN
            SET @c_NewTaskType = 'ASRSMV' 
            SET @c_LocationCategory = 'ASRSGTM'
            SET @c_LocationGroupTo = 'GTMLOOP' 

            SET @b_GTMLoop  = 1
         END
         ELSE IF EXISTS (  SELECT 1 
                           FROM TASKDETAIL  TD WITH (NOLOCK)
                           LEFT JOIN ORDERS OH WITH (NOLOCK) ON (TD.Orderkey = OH.Orderkey)
                                                             AND(OH.SOStatus = 'CANC')
                           WHERE TD.RefTaskKey = @c_TaskDetailkey
                           AND   TD.FromID     = @c_MoveID
                           AND   TD.Status     < '9'
                           AND   TD.TaskType   <> 'GTMJOB'
                           AND   OH.Orderkey IS NULL
                        )
         BEGIN
            SET @c_NewTaskType = 'ASRSMV' 
            SET @c_LocationCategory = 'ASRSGTM'
            SET @c_LocationGroupTo = 'GTMLOOP' 

            SET @b_GTMLoop  = 1
         END
      END
      /*---------------------------------------------------*/
      /* <<END>> If Not go EPS Then Check if go GTMLOOP    */
      /*---------------------------------------------------*/

      /*-----------------------------------------------------------------------*/
      /* <<START>> If not go EPS and GTMLOOP ThenCheck If go to OUTBOUND Lane  */
      /*-----------------------------------------------------------------------*/
      IF @c_LocationCategory = 'ASRS'
      BEGIN         
         IF @c_TaskType = 'ASRSPK'
         BEGIN
            SET @c_Orderkey = ''

            SELECT TOP 1 @c_Orderkey = Orderkey 
            FROM PICKDETAIL WITH (NOLOCK)
            WHERE ID = @c_MoveID
            AND Status = '5'
            AND ShipFlag <> 'Y'
            AND TaskDetailkey IS NOT NULL 
            AND Taskdetailkey <> ''

            SET @c_LoadKey = ''
            SET @c_MBOLkey = ''
            SELECT @c_LoadKey = Loadkey
                  ,@c_MBOLkey = MBOLkey
            FROM ORDERS WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey

            SET @c_FinalLoc = ''
            SET @c_PutawayZone = ''
            SELECT @c_PutawayZone = LOC.Putawayzone 
                  ,@c_FinalLoc    = LOADPLANLANEDETAIL.Loc 
            FROM LOADPLANLANEDETAIL WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON (LOADPLANLANEDETAIL.Loc = LOC.Loc)
            WHERE (( LOADPLANLANEDETAIL.Loadkey = @c_Loadkey AND LOADPLANLANEDETAIL.Loadkey <> '' ))
            AND   LOADPLANLANEDETAIL.LocationCategory = 'STAGING'
   
            IF @b_debug = 1 
            BEGIN
               select  @c_Orderkey '@c_Orderkey'
                     , @c_LoadKey  '@c_LoadKey'
   						, @c_MBOLkey  '@c_MBOLkey'
                     , @c_PutawayZone '@c_PutawayZone'
                     , @c_FinalLoc '@c_FinalLoc'
            END

            IF EXISTS ( SELECT 1 FROM ORDERS WITH (NOLOCK)
                        WHERE Orderkey = @c_Orderkey
                        AND SpecialHandling = 'H' )
            BEGIN
               SET @c_PutawayZone = ''
            END

            IF @c_PutawayZone <> ''
            BEGIN
               SET @c_NewTaskType = 'ASRSMV' 
               SET @c_LocationGroupTo = '' 
               SET @c_LocationCategory = 'ASRSOUTST'
               SET @c_MVPickMehtod = 'PK'
            END   
         END
      END
      /*-----------------------------------------------------------------------*/
      /* <<END>> If not go EPS and GTMLOOP Then Check If go to OUTBOUND Lane   */
      /*-----------------------------------------------------------------------*/
      --(Wan04) - START
      IF @c_LocationCategory = 'ASRS'
      BEGIN  
         IF @c_TaskType = 'ASRSTRF'
         BEGIN
            SET @c_FinalLoc = ''
            SELECT @c_FinalLoc = TF.UserDefine01
            FROM TASKDETAIL     TD  WITH (NOLOCK) 
            JOIN TRANSFERDETAIL TFD WITH (NOLOCK) ON (TD.sourcekey = TFD.Transferkey)
                                                  AND(TD.FromID = TFD.FromID)
            JOIN TRANSFER       TF  WITH (NOLOCK) ON (TF.Transferkey = TFD.Transferkey)
            WHERE TD.Taskdetailkey = @c_Taskdetailkey
            AND   TFD.ToID = @c_MoveID
            AND   TFD.Status = '9'

            IF @c_FinalLoc <> ''
            BEGIN
               SELECT @c_PutawayZone = PutawayZone
                     ,@c_LocationGroupTo = LocationGroup 
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @c_FinalLoc  

               SET @c_NewTaskType = 'ASRSMV' 
               SET @c_LocationCategory = 'ASRSOUTST'
            END  
         END
      END
      --(Wan04) - END

      IF @c_LocationCategory <> 'ASRS' 
      BEGIN
         /* 2015-08-14: All Staging lanes share same PAZONE with Outbound station, Inbound will not have any lanes.
         -- User is allowed to use Inbound Lane for lane assignment when no more Outbound lane available
         -- Therefore, we will default the nearest Outbound point for the inbound lanes.
         IF @c_PutawayZone Like 'INBOUND%'
         BEGIN 
            SET @c_PutawayZone = 'OUTBOUND1'
         END*/

         SELECT @c_Toloc = Loc
               ,@c_LogicalToLoc = LogicalLocation
         FROM LOC WITH (NOLOCK)
         WHERE LocationCategory = @c_LocationCategory
         AND LocationGroup  = @c_LocationGroupTo--'GTMLOOP'
         AND PutawayZone = CASE WHEN @c_LocationCategory = 'ASRSOUTST' THEN @c_PutawayZone ELSE PutawayZone END

         IF @c_Toloc = ''
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61029  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ToLoc not found for LocationCategory: ' + RTRIM(@c_LocationCategory) +
                         + CASE WHEN @c_LocationGroupTo <> '' THEN ', LocationGroup: ' + RTRIM(@c_LocationGroupTo) ELSE '' END
                         + CASE WHEN @c_LocationCategory = 'ASRSOUTST' THEN ', Putawayzone: ' + RTRIM(@c_PutawayZone) ELSE '' END
                         +'(isp_KioskASRSReleasePLT)'
            GOTO NEXT_MVID 
         END
      END

      /*----------------------   <<Determine Move to Loc>>   -------------------*/

      IF @b_debug = 1 
      BEGIN
         select '1', @c_NewTaskType '@c_NewTaskType', @c_MoveID'@c_MoveID', @c_Fromloc'@c_Fromloc', @c_Toloc '@c_Toloc'
                   , @c_LocationGroupTo'@c_LocationGroupTo', @c_LocationCategory'@c_LocationCategory'
      END

      BEGIN TRAN
      SET @c_ProcessTaskkey = @c_TaskdetailKey  
      IF @c_LocationGroupTo <> 'GTMLOOP' AND @c_LocationGroupTo <> 'EPS'
      BEGIN
         SET @b_success = 1    
         EXECUTE   nspg_getkey    
                  'TaskDetailKey'    
                 , 10    
                 , @c_NewTaskdetailKey OUTPUT    
                 , @b_success          OUTPUT    
                 , @n_err              OUTPUT    
                 , @c_errmsg           OUTPUT 

         IF NOT @b_success = 1    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get Taskdetailkey Failed. (isp_KioskASRSReleasePLT)' 
            GOTO NEXT_MVID  
         END  

         INSERT INTO TASKDETAIL    
            (    
               TaskDetailKey    
            ,  TaskType    
            ,  Storerkey    
            ,  Sku    
            ,  UOM    
            ,  UOMQty    
            ,  Qty    
            ,  SystemQty  
            ,  Lot    
     			,  FromLoc    
            ,  FromID    
            ,  ToLoc    
            ,  ToID 
            ,  LogicalFromLoc    
            ,  LogicalToLoc
            ,  FinalLoc
            ,  SourceType    
            ,  Priority 
            ,  [Status]
            ,  ReasonKey
            ,  StatusMsg 
            ,  PickMethod 
            )    
         VALUES    
            (    
               @c_NewTaskdetailkey    
            ,  @c_NewTaskType       -- Tasktype    
            ,  @c_Storerkey         -- Storerkey
            ,  ''                   -- Sku
            ,  ''                   -- UOM,    
            ,  0                    -- UOMQty
            ,  0                    -- SystemQty
            ,  0                    -- systemqty  
            ,  ''                   -- Lot
            ,  @c_Fromloc           -- from loc
            ,  @c_MoveID            -- from id    
            ,  @c_ToLoc             -- To Loc
            ,  ''                   -- to id 
            ,  @c_LogicalfromLoc    -- Logical from loc    
            ,  @c_LogicalToLoc      -- Logical to loc 
            ,  @c_FinalLoc          -- FinalLoc
            ,  'isp_KioskASRSReleasePLT'        -- Sourcetype    
            ,  '5'                  -- Priority    
            ,  '0'                  -- Status
            ,  ''                   -- ReasonCode
            ,  ''                   -- Remarks
            ,  @c_MVPickMehtod      -- PickMethod
            )  

         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (isp_KioskASRSReleasePLT)' 
            GOTO NEXT_MVID
         END 
         SET @c_ProcessTaskkey = @c_NewTaskdetailkey 
      END
      -- Send Move
      SET @c_MessageName  = CASE WHEN @c_LocationCategory = 'ASRS' THEN 'PUTAWAY' ELSE 'MOVE' END
      SET @c_MessageType  = 'SEND'

      IF @b_debug = 1 
      BEGIN
         select '2', @c_NewTaskType, @c_MoveID, @c_Fromloc, @c_Toloc, @c_LocationGroupTo, @c_LocationCategory
      END

      IF @b_TraceFlag = 1
      BEGIN
         INSERT INTO TraceInfo (TraceName, TimeIn,  Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         VALUES ( 'isp_KioskASRSReleasePLT', GETDATE(), @c_MessageName, @c_MoveID, @c_Fromloc, @c_Toloc, @c_ProcessTaskkey
                , '', '', '', '', '-1-' )
      END

      IF @b_debug = 0
      BEGIN
         EXEC isp_TCP_WCS_MsgProcess
                  @c_MessageName  = @c_MessageName
               ,  @c_MessageType  = @c_MessageType
               ,  @c_PalletID     = @c_MoveID
               ,  @c_FromLoc      = @c_Fromloc
               ,  @c_ToLoc	       = @c_Toloc 
               ,  @c_Priority	    = '5'
               ,  @c_TaskDetailKey= @c_ProcessTaskkey
               ,  @b_Success      = @b_Success  OUTPUT
               ,  @n_Err          = @n_Err      OUTPUT
               ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT


         IF @b_Success <> 1   
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (isp_KioskASRSReleasePLT)' 
                         + '( ' + @c_ErrMsg + ' )'
            GOTO NEXT_MVID
         END
      END
 
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN 
         -- refer to above
         UPDATE ID WITH (ROWLOCK)
         SET PalletFlag2 = ''
           , EditWho = SUSER_NAME()
           , EditDate = GETDATE()
           , Trafficcop = NULL  
         WHERE ID = @c_MoveID 
         AND PalletFlag2 = 'ALERTSUPV'

         SET @n_err = @@ERROR   

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update ID Table Failed. (isp_KioskASRSReleasePLT)' 
            GOTO NEXT_MVID
         END 
      END

      NEXT_MVID:
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN 
            COMMIT TRAN
         END
         WAITFOR DELAY '00:00:01'
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN
         END

         BEGIN TRAN
         UPDATE TASKDETAIL WITH (ROWLOCK)
         SET Status  = '5'
            ,Trafficcop   = NULL
            ,EditWho      = SUSER_NAME()
            ,EditDate     = GETDATE()
         WHERE TaskDetailKey = @c_JobKey
         AND   TaskType      = 'GTMJOB'

         IF @@ERROR <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61055  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Fail. (isp_KioskASRSReleasePLT)' 
                         + '( ' + @c_ErrMsg + ' )'
            ROLLBACK TRAN
         END
         ELSE
         BEGIN 
            COMMIT TRAN
         END
         GOTO QUIT_SP
      END

      FETCH NEXT FROM CUR_MVID INTO  @c_MoveID 
   END
   CLOSE CUR_MVID 
   DEALLOCATE CUR_MVID 
   /*-------------------------------------*/
   /* Loop to release Pallet      (End)   */
   /*-------------------------------------*/
   IF @b_debug = 1 
   BEGIN
      select '4', @c_NewTaskType, @c_MoveID, @c_Fromloc, @c_Toloc, @c_LocationGroupTo, @c_LocationCategory
       ,@b_GTMLoop '@b_GTMLoop'
   END

   /*----------------------   <<Determine GTMJOB Status >>   -------------------*/

   -- DEFAULT JobStatus 
   SET @c_JobStatus = '0'   --Reset JOBKey to '0' and enable timer to process jobstatus = '0' for pick to pallet release
   SET @c_Message01 = ''

   -- IF Release Inv Pallet
   IF EXISTS ( SELECT 1 
               FROM TASKDETAIL WITH (NOLOCK)
               WHERE TaskDetailKey = @c_Jobkey
               AND   TaskType      = 'GTMJOB'
               AND   FromID        = @c_ReleaseID
             )
   BEGIN
      SET @c_JobStatus = '9'
      SET @c_Message01 = 'Release Inv Pallet'
   END

   -- IF Release Both Pallets
   IF @c_JobStatus = '0' AND @b_ReleasePallets = 1 
   BEGIN
      SET @c_JobStatus = '9'
      SET @c_Message01 = 'Release Both Pallets'
   END
   /*----------------------   <<Determine GTMJOB Status >>   -------------------*/

   BEGIN TRAN

   IF @c_JobStatus = '9' AND @b_GTMLoop = 0
   BEGIN
      UPDATE TASKDETAIL WITH (ROWLOCK)
      SET Status       = 'X'
         ,Message01    = @c_Message01
         ,Trafficcop   = NULL
         ,EditWho      = SUSER_NAME()
         ,EditDate     = GETDATE()
      WHERE TaskDetailKey = CASE WHEN RefTaskKey = '' THEN @c_TaskDetailkey ELSE TaskDetailKey END
      AND RefTaskKey = CASE WHEN RefTaskKey = '' THEN RefTaskKey ELSE @c_TaskDetailkey END
      AND TaskType <> 'GTMJOB'
      AND Status   <  '9'

      IF @@ERROR <> 0   
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Fail. (isp_KioskASRSReleasePLT)' 
                      + '( ' + @c_ErrMsg + ' )'
         GOTO QUIT_SP
      END 
   END

   UPDATE TASKDETAIL WITH (ROWLOCK)
   SET Status       = @c_JobStatus
      ,StatusMsg    = '0'
      ,Trafficcop   = NULL
      ,EditWho      = SUSER_NAME()
      ,EditDate     = GETDATE()
   WHERE TaskDetailKey = @c_JobKey
   AND   TaskType      = 'GTMJOB'

   IF @@ERROR <> 0   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Fail. (isp_KioskASRSReleasePLT)' 
					    + '( ' + @c_ErrMsg + ' )'
      GOTO QUIT_SP
   END 

   IF @c_JobStatus = '9'
   BEGIN
      UPDATE GTMTASK WITH (ROWLOCK)
      SET Status = '9'
      FROM GTMTASK    GT
      JOIN TASKDETAIL TD WITH (NOLOCK) ON (GT.TaskDetailKey = TD.TaskDetailKey)
      WHERE TD.TaskDetailKey = CASE WHEN TD.RefTaskKey = '' THEN @c_TaskDetailkey ELSE TD.TaskDetailKey END
      AND TD.RefTaskKey = CASE WHEN TD.RefTaskKey = '' THEN TD.RefTaskKey ELSE @c_TaskDetailkey END
      AND TD.TaskType <> 'GTMJOB'
      AND TD.Status IN ( '9', 'X' )
      AND GT.Status > '6'  

      IF @@ERROR <> 0   
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE GTMTASK Fail. (isp_KioskASRSReleasePLT)' 
                      + '( ' + @c_ErrMsg + ' )'
         GOTO QUIT_SP
      END 
   END 

QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_MVID') in (0 , 1)  
   BEGIN
      CLOSE CUR_MVID
      DEALLOCATE CUR_MVID
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetGTMKioskJobs'   --(Wan01)
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSReleasePLT'     --(Wan01)
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO