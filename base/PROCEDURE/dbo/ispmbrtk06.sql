SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispMBRTK06                                         */
/* Creation Date:  09-Mar-2016                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  360341-CN-Carters SZ-MBOL release container move task      */
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
/* Called By:  MBOL RMC Release Move Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/************************************************************************/

CREATE PROC [dbo].[ispMBRTK06]
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
       	 	 @c_CaseId NVARCHAR(20)       	 	 
       	 	            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = ''

   IF EXISTS (SELECT 1 FROM TASKDETAIL(NOLOCK) WHERE Sourcekey = @c_Mbolkey AND SourceType = 'ispMBRTK06')
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Task has been released for the MBOL. Not allow to release again. (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP    	  
   END
   
   IF @n_continue IN(1,2)
   BEGIN
   	  --Validation
   	  SET @c_Containerkey = ''   	  
   	  SET @c_CaseId = ''
      SELECT TOP 1 @c_ContainerKey = C.Containerkey, @c_CaseId = PD.CaseId
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PD.CaseID = PKD.LabelNo
      LEFT JOIN PICKDETAIL PID (NOLOCK) ON PKD.LabelNo = PID.CaseId
      WHERE C.Mbolkey = @c_Mbolkey 
      AND (PKD.LabelNo IS NULL OR PID.CaseID IS NULL)
      
      IF ISNULL(@c_ContainerKey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': CaseId ''' + RTRIM(@c_CaseId) + ''' of Container '''+ RTRIM(@c_Containerkey) +''' is not found at Packdetail or Pickdetail. (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	               	     	  
   	             
   	  --Get staging location
   	  SET @c_ToLoc = ''
      SELECT TOP 1 @c_ToLoc = LLD.Loc, @c_ToLogicalLocation = LOC.LogicalLocation
      FROM LOADPLANLANEDETAIL LLD (NOLOCK)
      JOIN LOC (NOLOCK) ON LLD.Loc = LOC.Loc
      WHERE LLD.Mbolkey = @c_Mbolkey
      AND LLD.LocationCategory = 'STAGING'
      
      IF ISNULL(@c_ToLoc,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Staging lane not yet assigned to the MBOL (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	
      
      --Get container info
      SET @c_ContainerKey = ''
      SELECT TOP 1 @c_ContainerKey = C.Containerkey
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      WHERE C.Mbolkey = @c_Mbolkey 
      
      IF ISNULL(@c_ContainerKey,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Detail not found for the MBOL (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	            
   END  

   --Retrieve reference data
   IF @n_Continue IN(1,2)
   BEGIN
   	  --retrieve pickdetail of the container
   	  SELECT DISTINCT PICKD.Storerkey, PICKD.Orderkey, PICKD.Pickdetailkey, PICKD.Qty AS ContrQty
   	  INTO #TMP_PICKDETAIL
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      JOIN PACKDETAIL PKD (NOLOCK) ON PD.CaseID = PKD.LabelNo
      JOIN PACKHEADER PKH (NOLOCK) ON PKD.PickslipNo = PKH.PickslipNo
      JOIN PICKDETAIL PICKD (NOLOCK) ON PKD.LabelNo = PICKD.CaseID AND PKH.Pickslipno = PICKD.Pickslipno --AND PD.Id = PD.PalletKey
      WHERE C.Mbolkey = @c_Mbolkey 
      
      --retrieve full order qty of the container
      SELECT O.Orderkey, SUM(OD.QtyAllocated + OD.QtyPicked) AS OrderQty
      INTO #TMP_ORDER
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      WHERE O.Orderkey IN (SELECT Orderkey FROM #TMP_PICKDETAIL)
      GROUP BY O.Orderkey
      
      IF EXISTS (SELECT 1
                 FROM #TMP_ORDER 
                 WHERE Orderkey NOT IN (SELECT Orderkey FROM MBOLDETAIL (NOLOCK) WHERE Mbolkey = @c_Mbolkey))
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Move Task Failed. MBOL Is Not Populated Yet. (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         

      IF EXISTS (SELECT 1
                 FROM #TMP_PICKDETAIL TP 
                 JOIN #TMP_ORDER TOR ON TP.Orderkey = TOR.Orderkey
                 GROUP BY TP.Orderkey, TOR.OrderQty
                 HAVING SUM(TP.ContrQty) <> TOR.OrderQty)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Move Task Failed. Container Order Not Split Yet. (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         
   END
   
   --Create Move Task
   IF @n_Continue IN(1,2)
   BEGIN      
      DECLARE CUR_CONTR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation, SUM(TP.ContrQty)
         FROM #TMP_PICKDETAIL TP (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON TP.Pickdetailkey = PD.Pickdetailkey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         GROUP BY TP.Storerkey, PD.Loc, PD.ID, LOC.LogicalLocation
         
      OPEN CUR_CONTR_PALLET  
      
      FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty

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
             ,'ispMBRTK06' --Sourcetype  
             ,@c_mbolkey --Sourcekey  
             ,'5' -- Priority  
             ,'9' -- Sourcepriority  
             ,'0' -- Status  
             ,@c_LogicalLocation --Logical from loc  
             ,@c_ToLogicalLocation --Logical to loc  
             ,'FP' --pickmethod
            )
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispMBRTK06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
         END
   
         FETCH NEXT FROM CUR_CONTR_PALLET INTO @c_Storerkey, @c_Loc, @c_ID, @c_LogicalLocation, @n_Qty
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
 execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK06'
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