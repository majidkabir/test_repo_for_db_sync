SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_PackNHoldCallOut                                        */
/* Creation Date: 08-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Release shipment call out Task;                             */
/*        : SOS#315026 - Project Merlion MBOL Pack and Hold Pallet      */
/*          Selection function                                          */
/* Called By: Release shipment Call Out Task                            */
/*          : w_shipnid_callout.tab_master.ue_releasetasks event        */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PackNHoldCallOut] 
            @c_MBOLKey     NVARCHAR(10)
         ,  @c_ID          NVARCHAR(18) 
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
         ,  @n_debug       INT = 0
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Loadkey         NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_FromLoc         NVARCHAR(10)

         , @c_TaskdetailKey   NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_LogicalFromLoc  NVARCHAR(18)   
         , @c_LogicalToLoc    NVARCHAR(18)
         , @c_FinalLoc        NVARCHAR(10)
         , @c_StagingPAZone   NVARCHAR(10)
 
         , @c_ReasonCode      NVARCHAR(30)
         , @c_MessageName     NVARCHAR(15)
         , @c_MessageType     NVARCHAR(10)

--         , @n_debug           INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   --SET @n_debug    = 0
  
   -- Assume: 1 ID for 1 storer and located in 1 location
   SET @c_Storerkey = ''
   SET @c_FromLoc = ''
   SET @c_LogicalFromLoc = ''
   SELECT  TOP 1 
           @c_Storerkey = LotxLocxID.Storerkey   
         , @c_FromLoc = LotxLocxID.Loc
         , @c_LogicalFromLoc = ISNULL(LogicalLocation,'') 
   FROM LotxLocxID WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (LotxLocxID.Loc = LOC.Loc)
   WHERE LotxLocxID.ID = @c_ID  
   AND Qty > 0  

   IF EXISTS ( SELECT 1
               FROM LOC WITH (NOLOCK)
               WHERE Loc = @c_FromLoc
               AND LocationCategory <> 'ASRS'
              )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ID Not in ASRS location. (isp_InspectionCallOut)' 
      GOTO QUIT
   END

   --Get Loadkey
   SET @c_Loadkey = ''
   SELECT TOP 1 @c_Loadkey = ORDERS.Loadkey
   FROM ORDERS WITH (NOLOCK) 
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)
   WHERE PICKDETAIL.Loc = @c_FromLoc
   AND   PICKDETAIL.ID = @c_ID
   AND   PICKDETAIL.Status < '9'
   AND   PICKDETAIL.ShipFlag <> 'Y'

   SET @c_FinalLoc = ''
   SELECT @c_FinalLoc = Loc
   FROM LOADPLANLANEDETAIL WITH (NOLOCK)
--   WHERE ((MBOLKEy = @c_MBOLKEy AND MBOLKey <> '') OR
   WHERE ((Loadkey = @c_Loadkey AND Loadkey <> ''))
   AND   LocationCategory = 'STAGING' 

   IF @c_FinalLoc = ''
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Destination Lane not found. (isp_InspectionCallOut)' 
      GOTO QUIT
   END

   SET @c_StagingPAZone = ''
   SELECT @c_StagingPAZone = Putawayzone 
   FROM LOC WITH (NOLOCK)
   WHERE  Loc = @c_FinalLoc

   -- User is allowed to use Inbound Lane for lane assignment when no more Outbound lane available
   -- Therefore, we will default the nearest Outbound point for the inbound lanes.
   IF @c_StagingPAZone Like 'INBOUND%'
   BEGIN 
      SET @c_StagingPAZone = 'OUTBOUND1'
   END

   SET @c_ToLoc = ''
   SET @c_LogicalToLoc = ''
   SELECT @c_ToLoc = Loc  
        , @c_LogicalToLoc = ISNULL(LogicalLocation,'')
   FROM LOC WITH (NOLOCK)
   WHERE LocationCategory = 'ASRSOUTST'  
   AND   PutawayZone = @c_StagingPAZone


   IF @n_debug = 1
   BEGIN
      SELECT @c_ToLoc '@c_ToLoc'
   END

   SET @c_ReasonCode = 'MBOL_PNH'

   -- Create Taskdetail
   BEGIN TRAN
   SET @b_success = 1    
   EXECUTE   nspg_getkey    
            'TaskDetailKey'    
           , 10    
           , @c_TaskdetailKey OUTPUT    
           , @b_success       OUTPUT    
           , @n_err           OUTPUT    
           , @c_errmsg        OUTPUT 

   IF NOT @b_success = 1    
   BEGIN    
      SET @n_continue = 3    
      SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (isp_PackNHoldCallOut)' 
      GOTO QUIT  
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
      ,  SourceKey
      ,  SourceType    
      ,  Priority    
      ,  [Status]
      ,  Message01  -- Reasonkey
      ,  PickMethod
      )    
   VALUES    
      (    
         @c_Taskdetailkey    
      ,  'ASRSMV'             -- Tasktype    
      ,  @c_Storerkey         -- Storerkey
      ,  ''                   -- Sku
      ,  ''                   -- UOM,    
      ,  0                    -- UOMQty
      ,  0                    -- SystemQty
      ,  0                    -- systemqty  
      ,  ''                   -- Lot
      ,  @c_Fromloc           -- from loc
      ,  @c_ID                -- from id    
      ,  @c_ToLoc             -- To Loc
      ,  ''                   -- to id 
      ,  @c_LogicalfromLoc    -- Logical from loc    
      ,  @c_LogicalToLoc      -- Logical to loc 
      ,  @c_FinalLoc  
      ,  @c_MBOLKey           -- Sourcekey 
      ,  'isp_PackNHoldCallOut'-- Sourcetype    
      ,  '5'                  -- Priority    
      ,  '0'                  -- Status
      ,  @c_ReasonCode        -- ReasonCode
      ,  'PK'                 -- PickMethod
      )  

   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (isp_PackNHoldCallOut)' 
      GOTO QUIT
   END 
  
   SET @c_MessageName  = 'MOVE'
   SET @c_MessageType  = 'SEND'

   IF @n_debug = 0
   BEGIN
      EXEC isp_TCP_WCS_MsgProcess
               @c_MessageName  = @c_MessageName
            ,  @c_MessageType  = @c_MessageType
            ,  @c_PalletID     = @c_ID
            ,  @c_FromLoc      = @c_FromLoc
            ,  @c_ToLoc	       = @c_ToLoc
            ,  @c_Priority	    = '5'
            ,  @c_TaskDetailKey= @c_Taskdetailkey
            ,  @b_Success      = @b_Success  OUTPUT
            ,  @n_Err          = @n_Err      OUTPUT
            ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
   END

   IF @b_Success <> 1    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (isp_PackNHoldCallOut)' 
                   + '( ' + @c_ErrMsg + ' )'
      GOTO QUIT
   END 
   
QUIT:
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackNHoldCallOut'
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