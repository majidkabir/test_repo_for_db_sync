SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_GetStatus                                */
/* Creation Date: 28-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: d_dw_eautoalloc_statu_form                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_EAutoAlloc_GetStatus]
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_TotalOrdersALBatch INT
         , @n_TotalOrdersQCMDIP  INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SET @n_TotalOrdersALBatch = 0
   SET @n_TotalOrdersQCMDIP  = 0

   SELECT  @n_TotalOrdersALBatch= COUNT(DISTINCT OH.Orderkey)   
         , @n_TotalOrdersQCMDIP = COUNT(DISTINCT CASE WHEN AABJ.Status ='1' THEN OH.Orderkey ELSE NULL END)  
   FROM AUTOALLOCBATCHDETAIL AABD WITH (NOLOCK)  
   JOIN ORDERS               OH   WITH (NOLOCK) ON (AABD.Orderkey = OH.Orderkey)
   JOIN ORDERDETAIL          OD   WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN AUTOALLOCBATCHJOB    AABJ WITH (NOLOCK) ON (AABD.AllocBatchNo = AABJ.AllocBatchNo)
                                                AND(OH.Facility = AABJ.Facility)
                                                AND(OD.Storerkey= AABJ.Storerkey)
                                                AND(OD.Sku = AABJ.Sku)   
   WHERE AABJ.Status < '6'

   SELECT   TotalOrdersIP = @n_TotalOrdersALBatch - @n_TotalOrdersQCMDIP
         ,  TotalOrdersIP_text = 'Total Allocate In Progress'
         ,  TotalOrdersIP_color= 16711680 -- BLUE(0,0,255) 
         ,  TotalOrdersQCMDIP = @n_TotalOrdersQCMDIP   
         ,  TotalOrdersQCMDIP_text = 'Total QCMD Task In Progress'
         ,  TotalOrdersQCMDIP_color= 255  -- RED(255,0,0) 
   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO