SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_GetBatch                                 */
/* Creation Date: 28-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: d_dw_eautoalloc_batch_grid                                */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 18-JUL-2018 Wan01    1.1   Show BatchNo record exists in             */
/*                            AutoAllocBatchdetail                      */
/************************************************************************/
CREATE PROC [dbo].[isp_EAutoAlloc_GetBatch]
           @c_Storerkey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @c_BuildParmCodes   NVARCHAR(MAX)         
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   
   SELECT   aab.AllocBatchNo
         ,  aab.Priority
         ,  aab.TotalOrderCnt    
         ,  AABJ.Job_Pending
         ,  Status = CASE WHEN AAB.[Status]  = '0' AND CLK.[Description] IS NULL THEN 'Normal'                    
                          WHEN AAB.[Status]  = '1' AND CLK.[Description] IS NULL THEN 'In Progress'                   
                          WHEN AAB.[Status]  = '9' AND CLK.[Description] IS NULL THEN 'Completed' 
                          WHEN CLK.[Description] IS NULL THEN AAB.[Status] 
                          ELSE CLK.[Description] 
                     END             
         ,  selectrow = ''
         ,  selectrowctrl = ''
         ,  AABJ.Job_WIP
         ,  AABJ.Job_Error
         ,  AABJ.NoStock
         ,  AABJ.TotalJobs  
         ,  AABD.TotalSKU
         ,  AABD.SKUAllocated
         ,  AABD.NoStockFound
         ,  AABD.AllocErrorFound
         ,  AABD.PendingOrders
         ,  rowfocusindicatorcol = '    '                             
   FROM AUTOALLOCBATCH aab WITH (NOLOCK)
   LEFT OUTER JOIN CODELKUP AS CLK WITH (NOLOCK) ON CLK.ListName = 'AABSTATUS' AND CLK.Code = AAB.[Status] 
   LEFT OUTER JOIN (
   	SELECT AllocBatchNo, 
   	       Job_Pending = SUM(CASE WHEN [Status] = '0' THEN 1 ELSE 0 END), 
   	       Job_WIP     = SUM(CASE WHEN [Status] = '1' THEN 1 ELSE 0 END),
   	       Job_Error   = SUM(CASE WHEN [Status] = '5' THEN 1 ELSE 0 END),
   	       NoStock     = SUM(CASE WHEN [Status] = '6' THEN 1 ELSE 0 END),
   	       TotalJobs   = COUNT(1) 
   	FROM   AUTOALLOCBATCHJOB WITH (NOLOCK)
      GROUP BY AllocBatchNo ) AS AABJ ON (aab.AllocBatchNo = aabj.AllocBatchNo)
   JOIN (                                                                           --(Wan01)
   	SELECT AllocBatchNo, 
   	       COUNT(DISTINCT ORDERDETAIL.SKU) AS TotalSKU, 
   	       SUM(SKUAllocated) AS SKUAllocated,
   	       SUM(CASE WHEN NoStockFound = 1 THEN 1 ELSE 0 END) AS NoStockFound, 
   	       SUM(CASE WHEN AllocErrorFound = 1 THEN 1 ELSE 0 END) AS AllocErrorFound,
   	       SUM( CASE WHEN AutoAllocBatchDetail.[Status] IN ('0','1') THEN 1 ELSE 0 END ) AS PendingOrders   
   	FROM AutoAllocBatchDetail WITH(NOLOCK) 
   	JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.OrderKey = AutoAllocBatchDetail.OrderKey 
   	GROUP BY AllocBatchNo) AS AABD ON (AABD.AllocBatchNo = aab.AllocBatchNo) 
   JOIN fnc_DelimSplit ('|', @c_BuildParmCodes) BPC ON (aab.BuildParmCode = BPC.ColValue) 
   WHERE aab.Storerkey= @c_Storerkey
   AND   aab.Facility = CASE WHEN @c_Facility = '' THEN aab.Facility ELSE @c_Facility END
   ORDER BY aab.AllocBatchNo          

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO