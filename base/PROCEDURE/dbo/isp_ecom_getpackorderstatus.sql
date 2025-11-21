SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_GetPackOrderStatus                                 */
/* Creation Date: 20-APR-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 - New ECOM Packing                               */
/*        :                                                             */
/* Called By: d_dw_ecom_packorderstatus                                 */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-SEP-2016 Wan01    1.1   Performance Tune                          */
/* 01-Apr-2020 WLChooi  1.2   Add SKU.Descr (WL01)                      */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_GetPackOrderStatus] 
            @c_TaskBatchNo NVARCHAR(10)
         ,  @c_PickSlipNo  NVARCHAR(10)                       
         ,  @c_Orderkey    NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   IF RTRIM(@c_TaskBatchNo) = '' OR @c_TaskBatchNo IS NULL
   BEGIN
      GOTO QUIT_SP 
   END
   /* (Wan01) - START
   CREATE TABLE #TMP_PACKTASKSUMMARY
      (  TaskBatchNo    NVARCHAR(10)   NOT NULL
      ,  LogicalName    NVARCHAR(10)   NOT NULL
      ,  Orderkey       NVARCHAR(10)   NOT NULL
      ,  Storerkey      NVARCHAR(15)   NOT NULL
      ,  SKu            NVARCHAR(15)   NOT NULL
      ,  QtyAllocated   INT            NOT NULL
      ,  QtyPacked      INT            NOT NULL
      )
 
   IF RTRIM(@c_Orderkey) = '' OR @c_Orderkey IS NULL
   BEGIN
      GOTO RESULT 
   END


   INSERT INTO #TMP_PACKTASKSUMMARY
      (  TaskBatchNo 
      ,  LogicalName    
      ,  Orderkey        
      ,  Storerkey      
      ,  SKu            
      ,  QtyAllocated    
      ,  QtyPacked       
      )

   EXECUTE isp_Ecom_GetPackTaskOrderStatus
               @c_TaskBatchNo = @c_TaskBatchNo 
            ,  @c_PickSlipNo  = @c_PickSlipNo                  
            ,  @c_Orderkey    = @c_Orderkey 

    
   RESULT:
   (Wan01) - END */

   --DECLARE @TMP_PACKD TABLE 
   --(  PickSlipNo     NVARCHAR(10)   NOT NULL
   --,  Storerkey      NVARCHAR(15)   NOT NULL
   --,  Sku            NVARCHAR(20)   NOT NULL
   --,  QtyPacked      INT            NOT NULL
   --)

   --INSERT INTO @TMP_PACKD
   --(  PickSlipNo     
   --,  Storerkey       
   --,  Sku             
   --,  QtyPacked
   --)
   --SELECT PickSlipNo
   --    ,  Storerkey
   --    ,  Sku
   --    ,  ISNULL(SUM(Qty),0)
   --FROM PACKDETAIL WITH (NOLOCK)
   --WHERE PickSlipNo = @c_PickSlipNo
   --GROUP BY  PickSlipNo
   --       ,  Storerkey
   --       ,  Sku
   
   SELECT PTD.Orderkey
         ,PTD.Storerkey
         ,PTD.Sku
         ,PTD.QtyAllocated
         ,QtyPacked = ISNULL(SUM(PD.Qty),0)
         ,Packed = CASE WHEN  PTD.QtyAllocated = ISNULL(SUM(PD.Qty),0) THEN 1 ELSE 0 END  
         ,rowfocusindicatorcol = '    '
         ,S.Descr   --WL01
   FROM PACKTASKDETAIL  PTD WITH (NOLOCK) 
   LEFT JOIN PACKDETAIL PD  WITH (NOLOCK) ON (PTD.PickSlipNo = PD.PickSlipNo) 
                                          AND(PTD.Storerkey = PD.Storerkey)
                                          AND(PTD.Sku = PD.Sku)
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PTD.Storerkey AND S.SKU = PTD.SKU   --WL01
   WHERE PTD.TaskBatchNo = @c_TaskBatchNo
   AND   PTD.Orderkey = @c_Orderkey  
   GROUP  BY PTD.Orderkey
         ,PTD.Storerkey
         ,PTD.Sku
         ,PTD.QtyAllocated
         ,S.Descr   --WL01

QUIT_SP:
  
END -- procedure

GO