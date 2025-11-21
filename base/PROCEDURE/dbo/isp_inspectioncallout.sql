SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_InspectionCallOut                                       */
/* Creation Date: 28-Nov-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Release Inspection Task;                                    */
/*        : SOS#315024 - Project Merlion - Exceed Call Out Inspection   */
/* Called By: Release Inspection Call Out Task                          */
/*          : w_id_callout.tab_callout.ue_releasetasks event            */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 20-Nov-2015  YTWan     1.1 Fixed module name(Wan01)                  */
/* 04-Mar-2016  Wan02     1.2 SOS#363833 - Merlion_Multiple QC task     */
/*                            release for same pallet                   */
/* 27-JUL-2016  Barnett   1.4 FBR - 373411 ASRS Picking Priority (BL01) */
/************************************************************************/
CREATE PROC [dbo].[isp_InspectionCallOut] 
            @c_ID          NVARCHAR(18) 
         ,  @c_Finalloc    NVARCHAR(18) 
         ,  @c_Reasoncode  NVARCHAR(30) 
         ,  @c_Remarks     NVARCHAR(255) 
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15)
         , @c_FromLoc         NVARCHAR(10)

         , @c_TaskdetailKey   NVARCHAR(10)
         , @c_ToLoc           NVARCHAR(10)
         , @c_LogicalFromLoc  NVARCHAR(18)   
         , @c_LogicalToLoc    NVARCHAR(18) 
         
         , @c_MessageName     NVARCHAR(15)
         , @c_MessageType     NVARCHAR(10)

         , @c_PickMethod      NVARCHAR(10)
		 , @c_Priority        NVARCHAR(10)		  --(BL01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_PickMethod = 'QC'
  
   SET @c_Remarks = CASE WHEN @c_Remarks IS NULL THEN '' ELSE @c_Remarks END

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
              ) AND
      EXISTS ( SELECT 1
               FROM LOC WITH (NOLOCK)
               WHERE Loc = @c_FinalLoc
               AND LocationCategory = 'STAGING'
             )
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ID Release to Outbound Not in ASRS location. (isp_InspectionCallOut)' 
      GOTO QUIT
   END

   --(Wan02) - START
   IF EXISTS ( SELECT 1
               FROM TASKDETAIL WITH (NOLOCK)
               WHERE TaskType = 'ASRSQC'
               AND FromID = @c_ID
               AND Status < '9'
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 61006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ID Inspection Task created for this pallet: ' +RTRIM(@c_ID)+ '. (isp_InspectionCallOut)' 
      GOTO QUIT
   END
   --(Wan02) - END

   SET @c_ToLoc = ''
   SET @c_LogicalToLoc = ''

   SELECT @c_ToLoc = CASE WHEN LOC.LocationCategory = 'ASRSINST' THEN 'OUTBOUND1' ELSE LOC.Loc END
         ,@c_LogicalToLoc = ISNULL(LOC.LogicalLocation,'')
   FROM LOC     WITH (NOLOCK)
   JOIN LOC STG WITH (NOLOCK) ON (LOC.PutawayZone = STG.Putawayzone)
   WHERE STG.Loc = @c_FinalLoc
   AND STG.LocationCategory = 'STAGING'
   AND LOC.LocationCategory IN ( 'ASRSINST','ASRSOUTST' )

   IF @c_ToLoc = ''
   BEGIN
      SET @c_ToLoc = ''
      SET @c_LogicalToLoc = ''
      SELECT @c_ToLoc = Loc  
           , @c_LogicalToLoc = ISNULL(LogicalLocation,'')
      FROM LOC WITH (NOLOCK)
      WHERE ( LocationCategory = 'ASRSGTM' And LocationGroup = 'GTMLOOP' )

      SET @c_PickMethod = ''
   END

	--(BL01 BEGIN)
	--If ToLoc is go GTM
	If @c_PickMethod = ''
	BEGIN
			SELECT @c_Priority = Short
			FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = 'ASRSQC'
	END


	IF ISNULL(@c_Priority,'') =''  
	BEGIN
		SELECT @c_Priority = Short
		FROM CodeLKup (NOLOCK) WHERE ListName = 'DTPriority' AND Code = 'DEFAULT'

		IF ISNULL(@c_Priority,'') ='' SET @c_Priority = 5
	END 
	--(BL01 END)


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
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (isp_InspectionCallOut)' 
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
      ,  SourceType    
      ,  Priority    
      ,  [Status]
      ,  Message01 -- ReasonKey
      ,  StatusMsg 
      ,  PickMethod
      )    
   VALUES    
      (    
         @c_Taskdetailkey    
      ,  'ASRSQC'             -- Tasktype    
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
      ,  'isp_InspectionCallOut'         -- Sourcetype    
      ,  @c_Priority          -- Priority    --(BL01)
      ,  '0'                  -- Status
      ,  @c_ReasonCode        -- ReasonCode
      ,  @c_Remarks           -- Remarks
      ,  @c_PickMethod        -- PickMethod
      )  

   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (isp_InspectionCallOut)' 
      GOTO QUIT
   END 

   SET @c_MessageName  = 'MOVE'
   SET @c_MessageType  = 'SEND'
   SET @b_Success = 0

   EXEC isp_TCP_WCS_MsgProcess
            @c_MessageName  = @c_MessageName
         ,  @c_MessageType  = @c_MessageType
         ,  @c_PalletID     = @c_ID
         ,  @c_FromLoc      = @c_FromLoc
         ,  @c_ToLoc	    = @c_ToLoc
         ,  @c_Priority	    = @c_Priority		--(BL01)
         ,  @c_TaskDetailKey= @c_Taskdetailkey
         ,  @b_Success      = @b_Success  OUTPUT
         ,  @n_Err          = @n_Err      OUTPUT
         ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
   
   IF @b_Success <> 1   
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_TCP_WCS_MsgProcess Failed. (isp_InspectionCallOut)' 
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
      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetGTMKioskJobs'   --(Wan01) 
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_InspectionCallOut'   --(Wan01)   
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