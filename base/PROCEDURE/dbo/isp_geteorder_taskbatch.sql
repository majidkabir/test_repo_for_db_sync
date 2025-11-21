SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetEOrder_TaskBatch                                 */
/* Creation Date: 29-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1860 - Backend Alloc And Replenishment                  */
/*        :                                                             */
/* Called By: d_dw_eorder_taskbatch                                     */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 26-OCT-2017 Wan01    1.1   Multiple Loadkey Pass in                  */
/* 08-Apr-2019 NJOW01   1.2   WMS-8705 - add 'No need replen' status if */
/*                            generated  but no replen record           */
/* 26-Oct-2020 Wan02    1.3   Performance tune. Add Index               */
/************************************************************************/
CREATE PROC [dbo].[isp_GetEOrder_TaskBatch]  
           @c_Loadkey   NVARCHAR(1000)	--(Wan01)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt INT
         , @n_Continue  INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   --(Wan01) - START
   CREATE TABLE #TMP_LOAD 
      (
         Loadkey NVARCHAR(10)   PRIMARY KEY
      ) 
   --(Wan01) - END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   --(Wan01) - START
   IF CHARINDEX( '|', @c_Loadkey) > 0              
   BEGIN        
      INSERT INTO #TMP_LOAD (LoadKey)
      SELECT DISTINCT ColValue 
      FROM [dbo].[fnc_DelimSplit]('|', @c_Loadkey)
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_LOAD (LoadKey)
      VALUES(@c_Loadkey) 
   END
   --(Wan01) - END

   SELECT OH.Facility
         ,OH.Storerkey
         ,LPD.Loadkey   
         ,PT.TaskBatchNo
         ,ReplenishmentGroup =ISNULL(MAX(PT.ReplenishmentGroup),'')
         ,ReplenmentStatus =CASE WHEN MIN(RPL.Confirmed) IS NULL AND ISNULL(MAX(PT.ReplenishmentGroup),'') <> '' THEN  'No Need Replen' --NJOW01
                                 WHEN MIN(RPL.Confirmed) IS NULL AND ISNULL(MAX(PT.ReplenishmentGroup),'') = '' THEN  '' --NJOW01
                                 --WHEN MIN(RPL.Confirmed) IS NULL THEN ''
                                 WHEN MIN(RPL.Confirmed) = 'Y' AND MAX(RPL.Confirmed) = 'Y' THEN 'Completed' 
                                 WHEN MIN(RPL.Confirmed) = 'N' AND MAX(RPL.Confirmed) = 'N' THEN 'Generated' 
                                 ELSE 'In Progress'
                                 END
         ,'    ' rowfocusindicatorcol
         , 'N' selectrow
         , 'N' selectrowctrl           
   FROM PACKTASK           PT  WITH (NOLOCK) 
   JOIN LOADPLANDETAIL     LPD WITH (NOLOCK) ON (PT.Orderkey = LPD.Orderkey)
   JOIN ORDERS             OH  WITH (NOLOCK) ON (LPD.Orderkey= OH.Orderkey)
   JOIN #TMP_LOAD          LP  ON (LPD.Loadkey = LP.Loadkey)      --(Wan01)
   LEFT JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (PT.ReplenishmentGroup = RPL.ReplenishmentGroup AND RPL.storerkey = OH.storerkey)   --(Wan02)
   --WHERE LPD.Loadkey = @c_Loadkey                               --(Wan01)
   GROUP BY OH.Facility
         ,  OH.Storerkey
         ,  LPD.Loadkey   
         ,  PT.TaskBatchNo


   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO