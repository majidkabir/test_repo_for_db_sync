SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_GetValidQtyPacked                                  */
/* Creation Date: 20-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By: nep_n_cst_packcarton_ecom                                 */
/*          : ue_sku_rule                                               */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-SEP-2016 Wan01    1.1   Performance Tune                          */
/* 20-OCT-2016 Wan03    1.2   Fixed invalid qty if no packdetail        */
/* 06-OCT-2017 Wan04    1.3   Performance Tune                          */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_GetValidQtyPacked] 
            @c_PickSlipNo     NVARCHAR(10)
         ,  @c_TaskBatchNo    NVARCHAR(10)  
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_Sku            NVARCHAR(20)
         ,  @n_Qty            INT = 1
         ,  @c_UserID         NVARCHAR(30)
         ,  @c_ComputerName   NVARCHAR(30)
         ,  @b_ValidQtyPacked INT         OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   
   DECLARE  
           @n_StartTCnt    INT
         , @n_Continue     INT 

         , @n_QtyPacked    INT
         , @n_SkuQtyPacked INT
         , @n_SkuQtyOrder  INT
         , @c_Orderkey     NVARCHAR(10)

         , @c_PTD_Status   NVARCHAR(10)   --(Wan02)
         , @c_PTD_ORderkey NVARCHAR(10)   --(Wan02)

         , @c_OrderMode    NVARCHAR(10)   --(Wan02)

         , @b_FirstSkuScan INT            --(Wan03)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @b_ValidQtyPacked = 1

   SET @c_PickSlipNo = ISNULL(RTRIM(@c_PickSlipNo),'')


   SET @n_QtyPacked = 0
   SET @c_Orderkey = ''
  --(Wan03) - START
   SET @b_FirstSkuScan = 0            

   -- Blank pickslip #. Scan First Sku for a taskbatchno, 
   IF @c_PickSlipNo = '' 
   BEGIN
      SET @b_FirstSkuScan = 1          
   END
   ELSE  -- With PickSlip # 
   BEGIN
      SET @b_FirstSkuScan = 1  
             
      SELECT @b_FirstSkuScan = 0
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo 

      -- With PickSlip # 
      SELECT @c_Orderkey = Orderkey
      FROM PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo= @c_PickSlipNo

      IF @c_Orderkey <> ''
      BEGIN
         SET @b_FirstSkuScan = 0
      END 
   END

   IF @b_FirstSkuScan = 1              
   --(Wan03) - END
   BEGIN
      SET @n_QtyPacked = @n_Qty

      SET @b_ValidQtyPacked = 0

      SELECT TOP 1 @b_ValidQtyPacked = 1
      FROM PACKTASKDETAIL PTD WITH (NOLOCK)
      WHERE PTD.TaskBatchNo = @c_TaskBatchNo
      AND   PTD.Storerkey   = @c_Storerkey
      AND   PTD.Sku = @c_Sku
      AND   PTD.QtyAllocated >= @n_QtyPacked
      AND   PTD.Status = '0'

      GOTO QUIT_SP
   END

   --(Wan03) - START
   -- With PickSlip # 
   --SELECT @c_Orderkey = Orderkey
   --FROM PACKHEADER WITH (NOLOCK)
   --WHERE PickSlipNo= @c_PickSlipNo
   --(Wan03) - END

   SELECT @n_QtyPacked = ISNULL(SUM(Qty),0)
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE PickSlipNo= @c_PickSlipNo
   AND   Storerkey = @c_Storerkey
   AND   Sku = @c_Sku

   SET @n_QtyPacked = @n_QtyPacked + @n_Qty

   -- With Orderkey and with pickslip #
   IF @c_Orderkey <> ''
   BEGIN
      SELECT TOP 1 @b_ValidQtyPacked = 0
      FROM PACKTASKDETAIL PTD WITH (NOLOCK)
      WHERE PTD.Orderkey = @c_Orderkey
      AND   PTD.Storerkey = @c_Storerkey
      AND   PTD.Sku = @c_Sku
      AND   PTD.QtyAllocated < @n_QtyPacked

      GOTO QUIT_SP
   END
 
   -- Blank Orderkey with pickslip # for single packtask
   SET @c_OrderMode = ''
   SELECT TOP 1 @c_OrderMode = OrderMode 
   FROM PACKTASK WITH (NOLOCK)
   WHERE TaskBatchNo = @c_TaskBatchNo

   IF  LEFT(@c_OrderMode,1) = 's' 
   BEGIN
      SET @b_ValidQtyPacked = 0

      SELECT TOP 1 @b_ValidQtyPacked = 1
      FROM PACKTASKDETAIL PTD WITH (NOLOCK)
      WHERE PTD.TaskBatchNo = @c_TaskBatchNo
      AND   PTD.Storerkey   = @c_Storerkey
      AND   PTD.Sku = @c_Sku
      AND   PTD.QtyAllocated >= @n_QtyPacked
      AND   PTD.Status = '0'

      GOTO QUIT_SP
   END
   
   -- Blank Orderkey with pickslip # for multi packtask
   --(Wan04) - START
   SET @b_ValidQtyPacked = 0
   IF EXISTS (
               SELECT 1
               FROM PACKTASKDETAIL  PTD WITH (NOLOCK) 
               WHERE PTD.TaskBatchNo = @c_TaskBatchNo
               AND   PTD.Status < '3'
               AND   ( dbo.fnc_ECOM_GetPackOrderStatus (@c_TaskBatchNo, @c_PickSlipNo, Orderkey) = '1') 
               AND   PTD.Storerkey = @c_Storerkey
               AND   PTD.Sku = @c_Sku
               AND   PTD.QtyAllocated >= @n_QtyPacked
             )
   BEGIN
      SET @b_ValidQtyPacked = 1
   END 
   /*
   DECLARE CUR_PTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PTD_Status = dbo.fnc_ECOM_GetPackOrderStatus (@c_TaskBatchNo, @c_PickSlipNo, Orderkey)
         ,Orderkey
   FROM PACKTASKDETAIL  PTD WITH (NOLOCK) 
   WHERE TaskBatchNo = @c_TaskBatchNo
   AND   Status < '3'
   ORDER BY PTD_Status DESC

   OPEN CUR_PTD
   
   FETCH NEXT FROM CUR_PTD INTO @c_PTD_Status
                              , @c_PTD_ORderkey 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @b_ValidQtyPacked = 0

      IF @c_PTD_Status = '1'
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM PACKTASKDETAIL WITH (NOLOCK)
                     WHERE Orderkey = @c_PTD_ORderkey
                     AND   Storerkey = @c_Storerkey
                     AND   Sku = @c_Sku
                     AND   QtyAllocated >= @n_QtyPacked
                     )
         BEGIN
            SET @b_ValidQtyPacked = 1
            BREAK
         END
      END

      IF @c_PTD_Status = '0'
      BEGIN
         SET @b_ValidQtyPacked = 0
         BREAK
      END
      
      NEXT_REC:
      FETCH NEXT FROM CUR_PTD INTO @c_PTD_Status
                                 , @c_PTD_ORderkey  
   END 
   CLOSE CUR_PTD
   DEALLOCATE CUR_PTD 
   */
   --(Wan04) - END
QUIT_SP:

END -- procedure

GO