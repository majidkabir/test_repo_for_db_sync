SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispMBRTK08                                         */
/* Creation Date:  11-Jul-2019                                          */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-9690 [CN] Boardriders MBOL Poplulate Order_New RCM     */
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
/* Called By:  MBOL RMC Release Pick Task                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/*2019-08-05   WLChooi  1.1  Fixed Table Linkage (WL01)                 */
/*2023-08-17   KuanYee  1.2  INC2141212 Add-On StorerKey filter (KY01)  */
/************************************************************************/

CREATE   PROC [dbo].[ispMBRTK08]
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
           @c_Orderkey NVARCHAR(10),
           @c_MBOLOrderkey NVARCHAR(10),
           @c_MBOLLoadkey NVARCHAR(10),
           @c_MBOLkeyFromOrder NVARCHAR(10),
           @c_NewOrderkey NVARCHAR(10),
           @c_NewLoadKey NVARCHAR(10),
           @n_ContrQty INT,
           @n_OrderQty INT,
           @c_Route NVARCHAR(10),
           @d_OrderDate DATETIME,
           @d_DeliveryDate DATETIME,
           @n_TotalCube FLOAT,
           @n_TotalGrossWgt FLOAT,
           @c_Facility NVARCHAR(5),
           @c_ExternOrderkey NVARCHAR(30),
           @c_Loadkey NVARCHAR(10),
           @c_LogicalLocation NVARCHAR(18),
           @c_ID NVARCHAR(18),
           @c_Loc NVARCHAR(10),
           @c_TaskDetailKey NVARCHAR(10),
           @n_Qty INT,
           @c_Door NVARCHAR(10),
           @c_Consigneekey NVARCHAR(15),
           @c_Type NVARCHAR(10),
           @c_DeliveryPlace NVARCHAR(30),
           @c_CustomerName NVARCHAR(45),
           @c_PickSlipno NVARCHAR(10),
           @c_OldPickSlipno NVARCHAR(10),
           @c_OrderStatus NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @n_QtyAllocated INT,
           @n_QtyPicked INT,
           @c_NewOrderLineNumber NVARCHAR(5),
           @c_MovefromLabelNo NVARCHAR(20),
           @c_PrevMovefromLabelNo NVARCHAR(20),
           @n_NewCartonNo INT,
           @c_Movefrompickslipno NVARCHAR(10),
           @c_NewLabelLine NVARCHAR(5),
           @n_NewLabelLine INT,
           @c_MoveFromLabelLine NVARCHAR(5),
           @n_MoveFromCartonNo INT,
           @c_CaseId NVARCHAR(20),
           @c_Wavekey NVARCHAR(10),
           @c_Wavedetailkey NVARCHAR(10)        	 	 
       	 	            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = ''

   IF @n_continue IN(1,2)
   BEGIN
      --Validation     	            
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Detail not found for the MBOL (ispMBRTK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END         	            
   END  

   --Retrieve reference data
   IF @n_Continue IN(1,2)
   BEGIN
      --WL01 Start

      --SELECT DISTINCT PICKD.Orderkey, PICKD.Storerkey, PICKD.Pickdetailkey, PICKD.Qty AS ContrQty
      --INTO #TMP_PICKDETAIL
      --FROM CONTAINER C (NOLOCK)
      --JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      --JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      --JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      --JOIN PICKDETAIL PICKD (NOLOCK) ON PD.CaseId = PICKD.DropID
      --WHERE C.Mbolkey = @c_Mbolkey 

      --retrieve pickdetail of the container
      SELECT DISTINCT PICKD.Orderkey, PICKD.Storerkey, PICKD.Pickdetailkey, PICKD.Qty AS ContrQty
      INTO #TMP_PICKDETAIL
      FROM PICKDETAIL PICKD (NOLOCK)
      WHERE PICKD.Orderkey IN (
      SELECT DISTINCT PH.Orderkey
      FROM CONTAINER C (NOLOCK)
      JOIN CONTAINERDETAIL CD (NOLOCK) ON C.ContainerKey = CD.Containerkey
      JOIN PALLET P (NOLOCK) ON CD.Palletkey = P.Palletkey
      JOIN PALLETDETAIL PD (NOLOCK) ON P.Palletkey = PD.Palletkey
      JOIN PACKDETAIL PDET (NOLOCK) ON PD.CaseID = PDET.LabelNo AND PD.STORERKEY = PDET.STORERKEY     --KY01
      JOIN PACKHEADER PH (NOLOCK) ON PH.Pickslipno = PDET.Pickslipno
      WHERE C.Mbolkey = @c_Mbolkey )

      --WL01 End
      
      --retrieve order of the container
      SELECT O.Orderkey, O.Storerkey, SUM(OD.QtyAllocated + OD.QtyPicked) AS OrderQty, 
             O.Facility, O.Loadkey, SUM(Sku.StdCube * (OD.QtyAllocated + OD.QtyPicked)) AS TotalCube,
             SUM(Sku.StdGrossWgt * (OD.QtyAllocated + OD.QtyPicked)) AS TotalGrossWgt, O.Route,
             O.OrderDate, O.DeliveryDate, O.ExternOrderkey, O.Mbolkey, O.Userdefine09 AS Wavekey
      INTO #TMP_ORDER
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey      
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE EXISTS (SELECT 1 FROM #TMP_PICKDETAIL A WHERE A.Orderkey = O.Orderkey )
      GROUP BY O.Orderkey, O.Storerkey, O.Facility, O.Loadkey, O.Route, O.OrderDate, O.DeliveryDate, O.ExternOrderkey, O.Mbolkey, O.Userdefine09     
      
      IF EXISTS (SELECT 1 FROM #TMP_ORDER WHERE ISNULL(Mbolkey,'') <> '' AND Mbolkey <> @c_Mbolkey )                     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Orders Have Been Populated to Other MBOL (ispMBRTK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END

      IF NOT EXISTS (SELECT 1 FROM #TMP_ORDER WHERE ISNULL(Mbolkey,'') = '')                     
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36026   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Container Orders Have Been Populated to MBOL (ispMBRTK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
   END

   --Populate to MBOL
   IF @n_Continue IN(1,2)
   BEGIN
      IF @n_StartTranCnt = 0
         BEGIN TRAN

      --Retrive container orders
      DECLARE CUR_CONTR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT TP.Orderkey, TP.Storerkey, SUM(TP.ContrQty) AS ContrQty, TOR.OrderQty,
             TOR.Facility, TOR.Loadkey, TOR.TotalCube, TOR.TotalGrossWgt, TOR.Route,
             TOR.OrderDate, TOR.DeliveryDate, TOR.ExternOrderkey, TOR.MBOLkey, TOR.Wavekey
      FROM #TMP_PICKDETAIL TP 
      JOIN #TMP_ORDER TOR ON TP.Orderkey = TOR.Orderkey
      GROUP BY TP.Orderkey, TP.Storerkey, TOR.OrderQty, TOR.Facility, TOR.Loadkey, TOR.TotalCube, TOR.TotalGrossWgt, 
               TOR.Route, TOR.OrderDate, TOR.DeliveryDate, TOR.ExternOrderkey, TOR.MBOLKey, TOR.Wavekey
      ORDER BY TOR.Loadkey, TP.Orderkey

      OPEN CUR_CONTR_ORDER  
      
      FETCH NEXT FROM CUR_CONTR_ORDER INTO @c_Orderkey, @c_Storerkey, @n_ContrQty, @n_OrderQty, @c_Facility, @c_Loadkey, @n_TotalCube,
                                           @n_TotalGrossWgt, @c_Route, @d_OrderDate, @d_DeliveryDate, @c_ExternOrderkey, @c_MBOLkeyFromOrder, @c_Wavekey
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)
      BEGIN
         SET @c_MBOLOrderkey = @c_Orderkey
         SET @c_MBOLLoadkey = @c_Loadkey

         --Add order to MBOL
         IF NOT EXISTS (SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE MBOLKey = @c_MBOLKey AND Orderkey = @c_MBOLOrderkey)
         BEGIN
            EXEC isp_InsertMBOLDetail 
                 @c_MBOLKey,
                 @c_Facility,
                 @c_MBOLOrderKey,
                 @c_MBOLLoadKey,
                 @n_TotalGrossWgt,      
                 @n_TotalCube,         
                 @c_ExternOrderKey,   
                 @d_OrderDate,
                 @d_DeliveryDate, 
                 @c_Route, 
                 @b_Success OUTPUT, 
                 @n_err OUTPUT,
                 @c_errmsg OUTPUT         	 	
                   
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36190   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert MBOLDETAIL Error. (ispMBRTK08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP 
            END
         END
                               
         FETCH NEXT FROM CUR_CONTR_ORDER INTO @c_Orderkey, @c_Storerkey, @n_ContrQty, @n_OrderQty, @c_Facility, @c_Loadkey, @n_TotalCube,
                                           @n_TotalGrossWgt, @c_Route, @d_OrderDate, @d_DeliveryDate, @c_ExternOrderkey, @c_MBOLkeyFromOrder, @c_Wavekey
      END
      CLOSE CUR_CONTR_ORDER  
      DEALLOCATE CUR_CONTR_ORDER                                     
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
   execute nsp_logerror @n_err, @c_errmsg, 'ispMBRTK08'
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