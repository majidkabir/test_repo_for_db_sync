SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBRTK07                                         */
/* Creation Date:  03-Mar-2018                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-4902 CN-Logitech MBOL release container move task      */
/*           for pack and hold.                                         */
/*           storerconfig: ReleaseCMBOL_MV_SP                           */
/*                                                                      */
/* Input Parameters:  @c_Mbolkey  - (Mbol #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  MBOL RCM Release Move Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[ispMBRTK07]
   @c_MbolKey NVARCHAR(10),
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT,
   @n_Cbolkey bigint = 0   
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_StartTranCnt int
           
   DECLARE @c_Storerkey NVARCHAR(15),
           @c_ToLoc NVARCHAR(10),
           @c_ToLogicalLocation NVARCHAR(18),
           @c_ContainerKey NVARCHAR(10),
           @c_LogicalLocation NVARCHAR(18),
           @c_ID NVARCHAR(18),
           @c_Loc NVARCHAR(10),
           @c_TaskDetailKey NVARCHAR(10),
           @n_Qty INT,
       	 	 @c_PalletKey NVARCHAR(30)
       	 	            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = ''

   IF EXISTS (SELECT 1 FROM TASKDETAIL(NOLOCK) WHERE Sourcekey = @c_Mbolkey AND SourceType = 'ispMBRTK07')
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Task has been released for the MBOL. Not allow to release again. (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP    	  
   END
       
   IF @n_continue IN(1,2)
   BEGIN
   	  --Validation
   	  SET @c_Palletkey = ''   	  
   	  SET @c_Containerkey = ''
      SELECT TOP 1 @c_ContainerKey = C.ContainerKey,
                   @c_PalletKey = CD.Palletkey 
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN ORDERS O (NOLOCK) ON C.Mbolkey = O.Mbolkey
      LEFT JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND CD.Palletkey = PD.ID
      WHERE C.Mbolkey = @c_Mbolkey 
      AND PD.Pickdetailkey IS NULL
      
      IF ISNULL(@c_Palletkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Palletkey ''' + RTRIM(@c_Palletkey) + ''' of Container '''+ RTRIM(@c_Containerkey) +''' is not found at Pickdetail of the MBOL. (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	               	     	 
      
      SET @c_Containerkey = ''
      SELECT TOP 1 @c_Containerkey = C.Containerkey
      FROM CONTAINER C (NOLOCK)
      LEFT JOIN LOC (NOLOCK) ON C.Userdefine01 = LOC.Loc
      WHERE C.Mbolkey = @c_Mbolkey
      AND LOC.Loc IS NULL
      ORDER BY C.Containerkey
         	                   
      IF ISNULL(@c_Containerkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found invalid Staging loc (userdefine01) at Container# '''+ RTRIM(@c_Containerkey) + ''' (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	
      
      --Get container info
      SET @c_ContainerKey = ''
      SELECT TOP 1 @c_ContainerKey = C.Containerkey
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      WHERE C.Mbolkey = @c_Mbolkey 
      
      IF ISNULL(@c_ContainerKey,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Detail not found for the MBOL (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	            
      
      SET @c_PalletKey = ''
      SELECT TOP 1 @c_PalletKey = PD.Id 
      FROM MBOLDETAIL MD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON MD.Mbolkey = O.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey 
      JOIN CONTAINER C (NOLOCK) ON MD.Mbolkey = C.Mbolkey
      LEFT JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey AND PD.Id = CD.Palletkey           
      WHERE MD.Mbolkey = @c_Mbolkey 
      AND CD.Containerkey IS NULL

      IF ISNULL(@c_PalletKey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pallet Id '''+ RTRIM(@c_Palletkey) + ''' of the MBOL not found in Container (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	      
   END  
  
   --Create Move Task
   IF @n_Continue IN(1,2)
   BEGIN      
   	  --retrieve pickdetail of the container
   	  SELECT DISTINCT C.Containerkey, C.UserDefine01 AS ToLoc, PD.Pickdetailkey
   	  INTO #TMP_PICKDETAIL
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN ORDERS O (NOLOCK) ON C.Mbolkey = O.Mbolkey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND CD.Palletkey = PD.ID
      WHERE C.Mbolkey = @c_Mbolkey 
      
      DECLARE CUR_CONTR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Containerkey, PD.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation, SUM(PD.Qty),
                LOC2.Loc, LOC2.LogicalLocation
         FROM #TMP_PICKDETAIL TP (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN LOC LOC2 (NOLOCK) ON TP.ToLoc = LOC2.Loc
         GROUP BY TP.Containerkey, PD.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation, LOC2.Loc, LOC2.LogicalLocation
         ORDER BY TP.Containerkey, PD.Storerkey, LOC.LogicalLocation, PD.Loc, PD.ID
         
      OPEN CUR_CONTR_PALLET  
      
      FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Containerkey, @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty, @c_ToLoc, @c_ToLogicalLocation

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	
         SELECT @b_success = 1  
         EXECUTE   nspg_getkey  
         "TaskDetailKey"  
         , 10  
         , @c_taskdetailkey OUTPUT  
         , @b_success OUTPUT  
         , @n_err OUTPUT  
         , @c_errmsg OUTPUT  
         IF NOT @b_success = 1  
         BEGIN  
            SELECT @n_continue = 3              
         END  
         
         IF @b_success = 1  
         BEGIN      
           INSERT TASKDETAIL  
            (  
              TaskDetailKey  
             ,TaskType  
             ,Storerkey  
             ,Sku  
             ,UOM  
             ,UOMQty  
             ,Qty  
             ,SystemQty
             ,Lot  
             ,FromLoc  
             ,FromID  
             ,ToLoc  
             ,ToID  
             ,SourceType  
             ,SourceKey  
             ,Priority  
             ,SourcePriority  
             ,Status  
             ,LogicalFromLoc  
             ,LogicalToLoc  
             ,PickMethod
             ,DropId
            )  
            VALUES  
            (  
              @c_taskdetailkey  
             ,'MVF' --Tasktype  
             ,@c_Storerkey  
             ,'' --Sku  
             ,'' --UOM,  
             ,0  --UOMQty,  
             ,@n_Qty  --Qty
             ,@n_Qty  --systemqty
             ,'' --Lot   
             ,@c_loc --from loc  
             ,@c_ID -- from id  
             ,@c_toloc --to loc
             ,@c_ID -- to id  
             ,'ispMBRTK07' --Sourcetype  
             ,@c_mbolkey --Sourcekey  
             ,'5' -- Priority  
             ,'9' -- Sourcepriority  
             ,'0' -- Status  
             ,@c_LogicalLocation --Logical from loc  
             ,@c_ToLogicalLocation --Logical to loc  
             ,'FP' --pickmethod
             ,@c_Containerkey --Dropid
            )
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispMBRTK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
         END
   
         FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Containerkey, @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty, @c_ToLoc, @c_ToLogicalLocation
      END
      CLOSE CUR_CONTR_PALLET  
      DEALLOCATE CUR_CONTR_PALLET      
   END                                                   
END

QUIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  ROLLBACK TRAN
 END
 ELSE
 BEGIN
  WHILE @@TRANCOUNT > @n_StartTranCnt
  BEGIN
   COMMIT TRAN
  END
 END
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK07'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO