SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_GetException                             */
/* Creation Date: 28-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: d_dw_EAutoAlloc_Exception_grid                            */
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
CREATE PROC [dbo].[isp_EAutoAlloc_GetException]
        @c_AllocBatchNoList  NVARCHAR(MAX)           
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
   
   SELECT   AABD.RowRef
         ,  AABD.AllocBatchNo
         ,  AAB.BuildParmCode
         ,  AABD.Orderkey
         ,  CASE WHEN AABD.[Status]  = '1' AND CLK.[Description] IS NULL THEN 'In Progress'                   
                 WHEN AABD.[Status]  = '5' AND CLK.[Description] IS NULL THEN 'Error'
                 WHEN AABD.[Status]  = '6' AND CLK.[Description] IS NULL THEN 'No Stock'
                 WHEN AABD.[Status]  = '8' AND CLK.[Description] IS NULL THEN 'No Tasks'                 
                 WHEN AABD.[Status]  = '9' AND CLK.[Description] IS NULL THEN 'Completed' 
                 WHEN CLK.[Description] IS NULL THEN AABD.[Status] 
                 ELSE CLK.[Description] 
            END AS [Status]             
         ,  selectrow = ''
         ,  selectrowctrl = ''
         ,  rowfocusindicatorcol = '    '
         ,  AABD.TotalSKU
         ,  AABD.SKUAllocated
         ,  NoStockFound = CONVERT(INT, AABD.NoStockFound)
         ,  AllocErrorFound = CONVERT(INT, AABD.AllocErrorFound)              
   FROM AUTOALLOCBATCH       AAB    WITH (NOLOCK) 
   JOIN AUTOALLOCBATCHDETAIL AABD   WITH (NOLOCK) ON (AABD.AllocBatchNo= AAB.AllocBatchNo) 
   LEFT OUTER JOIN CODELKUP AS CLK WITH (NOLOCK) ON CLK.ListName = 'AABDSTATUS' AND CLK.Code = AABD.[Status] 
   JOIN fnc_DelimSplit ('|', @c_AllocBatchNoList) BPC ON (AAB.AllocBatchNo = BPC.ColValue)
   ORDER BY AABD.RowRef

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO