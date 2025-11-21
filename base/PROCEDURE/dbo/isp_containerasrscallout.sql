SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_ContainerASRSCallOut                           */  
/* Creation Date: 09-Aug-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-1880 SG MHAP Build container - ASRS Call out            */  
/*                                                                      */ 
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                   , @n_err                                           */
/*                   , @c_errmsg                                        */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */ 
/* Called By: Container RCM 'ASRS Call Out                              */
/*            Storerconfig: ASRSContainerPltCallOut = '1'               */
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROC [dbo].[isp_ContainerASRSCallOut] 
   @c_Containerkey NVARCHAR(10),
   @c_Palletkeys   NVARCHAR(MAX) = '',
   @b_Success      INT OUTPUT, 
   @n_err          INT OUTPUT, 
   @c_errmsg       NVARCHAR(250) OUTPUT,
   @n_debug        INT = 0 
AS
BEGIN
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @n_continue           INT,
           @n_StartTCnt          INT,
           @c_Palletkey          NVARCHAR(30),
           @n_PalletCnt          INT,
           @c_FinalLoc           NVARCHAR(10),
           @c_Taskdetailkey      NVARCHAR(10),
           @c_ReasonCode         NVARCHAR(30),
           @c_MessageName        NVARCHAR(15),
           @c_MessageType        NVARCHAR(10),
           @c_Storerkey          NVARCHAR(15),
           @c_FromLoc            NVARCHAR(10),
           @c_LogicalFromLoc     NVARCHAR(18),
           @c_ToLoc              NVARCHAR(10),
           @c_LogicalToLoc       NVARCHAR(18),
           @c_StagingPAZone      NVARCHAR(10)                                            
   
   SELECT @n_StartTCnt =  @@TRANCOUNT, @n_continue  = 1, @n_err = 0, @c_Errmsg = '', @b_success = 1, @n_PalletCnt = 0
   
   SET @c_ReasonCode = 'CONTR_CO'
   
   IF @n_continue IN(1,2)
   BEGIN   	   	
   	  DECLARE CUR_CONTAINER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT CONTAINER.Loc, CONTAINERDETAIL.PalletKey
   	     FROM CONTAINER (NOLOCK) 
   	     JOIN CONTAINERDETAIL(NOLOCK) ON CONTAINER.Containerkey = CONTAINERDETAIL.Containerkey
   	     WHERE CONTAINER.Containerkey = @c_Containerkey
   	     AND (CONTAINERDETAIL.Palletkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_Palletkeys)) 
   	          OR ISNULL(@c_Palletkeys,'') = '')
   	     ORDER BY CONTAINERDETAIL.ContainerLineNumber
   	  
   	  OPEN CUR_CONTAINER   
      
      FETCH NEXT FROM CUR_CONTAINER INTO @c_FinalLoc, @c_Palletkey

      IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK)
                    WHERE LocationCategory = 'STAGING' 
                    AND Loc = @c_FinalLoc)
      BEGIN
      	 SET @n_continue = 3
         SET @n_Err = 31100 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Invalid Staging Lane. Please select loc with category ''STAGING'' (isp_ContainerASRSCallOut)'  
      END      	 

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN      	
         SELECT TOP 1 
                 @c_Storerkey = LotxLocxID.Storerkey   
               , @c_FromLoc = LotxLocxID.Loc
               , @c_LogicalFromLoc = ISNULL(LOC.LogicalLocation,'') 
         FROM LotxLocxID WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LotxLocxID.Loc = LOC.Loc)
         WHERE LotxLocxID.ID = @c_Palletkey  
         AND LotxLocxID.Qty > 0  
         
         IF EXISTS ( SELECT 1
                     FROM LOC WITH (NOLOCK)
                     WHERE LOC.Loc = @c_FromLoc
                     AND LOC.LocationCategory <> 'ASRS'
                    )
         BEGIN
      	    SET @n_continue = 3
            SET @n_Err = 31110 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Pallet ID '+ RTRIM(@c_PalletKey) +' Not in ASRS location.  (isp_ContainerASRSCallOut)'  
         END

         SET @c_StagingPAZone = ''
         SELECT @c_StagingPAZone = LOC.Putawayzone 
         FROM LOC WITH (NOLOCK)
         WHERE LOC.Loc = @c_FinalLoc
         
         -- User is allowed to use Inbound Lane for lane assignment when no more Outbound lane available
         -- Therefore, we will default the nearest Outbound point for the inbound lanes.
         IF @c_StagingPAZone Like 'INBOUND%'
         BEGIN 
            SET @c_StagingPAZone = 'OUTBOUND1'
         END
         
         SET @c_ToLoc = ''
         SET @c_LogicalToLoc = ''
         SELECT TOP 1 @c_ToLoc = Loc  
                    , @c_LogicalToLoc = ISNULL(LOC.LogicalLocation,'')
         FROM LOC WITH (NOLOCK)
         WHERE LOC.LocationCategory = 'ASRSOUTST'  
         AND   LOC.PutawayZone = @c_StagingPAZone
         	 	
      	 SET @b_success = 1    
         EXECUTE   nspg_getkey    
            'TaskDetailKey'    
           , 10    
           , @c_TaskdetailKey OUTPUT    
           , @b_success       OUTPUT    
           , @n_err           OUTPUT    
           , @c_errmsg        OUTPUT 

         IF @b_success <> 1    
         BEGIN    
      	    SET @n_continue = 3
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
            ,  @c_Palletkey         -- from id    
            ,  @c_ToLoc             -- To Loc
            ,  ''                   -- to id 
            ,  @c_LogicalfromLoc    -- Logical from loc    
            ,  @c_LogicalToLoc      -- Logical to loc 
            ,  @c_FinalLoc  
            ,  @c_ContainerKey      -- Sourcekey 
            ,  'isp_ContainerASRSCallOut'-- Sourcetype    
            ,  '5'                  -- Priority    
            ,  '0'                  -- Status
            ,  @c_ReasonCode        -- ReasonCode
            ,  'PK'                 -- PickMethod
            )  
         
         SET @n_err = @@ERROR   
         
         IF @n_err <> 0    
         BEGIN  
      	    SET @n_continue = 3
            SET @n_Err = 31120 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +': Insert TASKDETAIL Failed. (isp_ContainerASRSCallOut)' 
         END 
         
         SET @c_MessageName  = 'MOVE'
         SET @c_MessageType  = 'SEND'
         
         IF @n_debug = 0
         BEGIN
            EXEC isp_TCP_WCS_MsgProcess
                     @c_MessageName  = @c_MessageName
                  ,  @c_MessageType  = @c_MessageType
                  ,  @c_PalletID     = @c_Palletkey
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
            SET @n_Err = 31130 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +': Execute isp_TCP_WCS_MsgProcess Failed. (isp_ContainerASRSCallOut)' 
         END             
    	   
    	   SELECT @n_PalletCnt = @n_PalletCnt + 1
      	 
         FETCH NEXT FROM CUR_CONTAINER INTO @c_FinalLoc, @c_Palletkey
      END
      CLOSE CUR_CONTAINER
      DEALLOCATE CUR_CONTAINER   	     	
   END   
     
   QUIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ContainerASRSCallOut'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR 
      RETURN
   END
   ELSE
   BEGIN
      IF @n_PalletCnt > 0 
      BEGIN
         SET @c_errmsg = 'Total ' +CONVERT(NVARCHAR(5), @n_PalletCnt)+ ' Pallet(s) Call Out Message Sent Sucessfully For Container# ' + RTRIM(@c_Containerkey)
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'No Pallet Call Out For Container# ' + RTRIM(@c_Containerkey)
      END

      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO