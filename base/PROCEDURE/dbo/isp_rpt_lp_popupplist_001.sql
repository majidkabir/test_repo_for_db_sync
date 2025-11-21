SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_LP_POPUPPLIST_001                               */
/* Creation Date: 05-05-2022                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Amal                                                     */
/*                                                                      */
/* Purpose: WMS-19507 - Migrate WMS report to Logi Report               */
/*        : r_dw_sortlist23 (PH)                                        */
/*          WMS-21880 - Loading Guide Enhancement (Add Columns)         */
/*                                                                      */
/* Called By:  RPT_LP_POPUPPLIST_001                                    */
/*             RPT_LP_POPUPPLIST_001_1                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 05-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 10-Mar-2023  WZPang   1.1  Add Columns                               */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_POPUPPLIST_001]
           @c_Loadkey         NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --SELECT @c_Loadkey AS Loadkey, 'IDS' AS ReportType 
   --UNION ALL 
   --SELECT @c_Loadkey AS Loadkey, 'TCK' AS ReportType 
   --UNION ALL 
   --SELECt @c_Loadkey AS Loadkey, 'SG' AS ReportType
   --SELECT @c_Loadkey AS Loadkey , CL1.LISTNAME AS ReportType
   --FROM CODELKUP (NOLOCK)
   --LEFT JOIN CODELKUP CL1(NOLOCK) ON CL1.LISTNAME = 'ReportCopy'   
   DECLARE @c_Storerkey NVARCHAR(15)

   SELECT @c_Storerkey = ISNULL(RTRIM(Storerkey),'')
   FROM Orders(NOLOCK)
   WHERE LoadKey = @c_Loadkey
   SELECT @c_Loadkey AS Loadkey, Description AS ReportType FROM codelkup(NOLOCK) WHERE LISTNAME = 'ReportCopy' AND Storerkey = @c_Storerkey
   
   

END
GRANT EXECUTE ON [dbo].[isp_RPT_LP_POPUPPLIST_001] TO [NSQL]

GO