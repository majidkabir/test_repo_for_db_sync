SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPickSlipOrders104Multi_rpt                           */
/* Creation Date: 26-Dec-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-11478 - IKEA Pick Slip Multi Order                     */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 12-Mar-2020  NJOW01    1.0   Fix total qty/sku by batchkey           */
/* 27-Mar-2020  WLChooi   1.1   Add sorting (WL01)                      */
/* 01-Apr-2020  WLChooi   1.2   WMS-12744 - Limit 9 detail lines per    */
/*                              page, modify title logic (WL02)         */
/* 21-Apr-2020  WLChooi   1.3   WMS-12744 - Only show result based on   */
/*                              certain condition (WL03)                */
/* 07-Dec-2021  WLChooi   1.4   DevOps Combine Script                   */
/* 07-Dec-2021  WLChooi   1.4   Fix possible wrong sorting in datawindow*/
/*                              (WL04)                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders104Multi_rpt] 
            @c_loadkey     NVARCHAR(10),
            @c_batchkey    NVARCHAR(10) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1, @c_Zones NVARCHAR(255) = '', @c_GetBatchkey NVARCHAR(10) = ''
   DECLARE @n_MaxLine INT = 9  --WL02
   DECLARE @c_Facility NVARCHAR(15) = '' --WL03

   IF @c_batchkey = NULL SET @c_batchkey = ''

   CREATE TABLE #Temp_Zone(
   BatchKey    NVARCHAR(10),
   Descr       NVARCHAR(255)   )

   --WL02 START
   CREATE TABLE #Temp_Result(
   Loadkey         NVARCHAR(10),
   BatchKey        NVARCHAR(10),
   TotalQty        INT,
   TotalSKU        INT,
   AllZones        NVARCHAR(255),
   [Zone]          NVARCHAR(10),
   Pickheaderkey   NVARCHAR(10),
   Orderkey        NVARCHAR(10),
   Title           NVARCHAR(20) )

   CREATE TABLE #TEMP_ByBatch(
   Batchkey        NVARCHAR(10),
   ShipperKey      NVARCHAR(15) )

   --WL03 START
   SELECT @c_Facility = Facility
   FROM LOADPLAN (NOLOCK)
   WHERE Loadkey = @c_loadkey

   IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'IKEATITLE' AND Code2 = @c_Facility)
   BEGIN
      GOTO QUIT_SP
   END
   --WL03 END

   INSERT INTO #TEMP_ByBatch
   SELECT DISTINCT PD.Pickslipno AS Batchkey, ISNULL(OH.ShipperKey,'')
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = OH.ORDERKEY
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.ORDERKEY = OH.ORDERKEY
   WHERE LPD.Loadkey = @c_loadkey
     AND OH.ECOM_Single_Flag = 'M'
     AND PD.Pickslipno = CASE WHEN @c_batchkey = '' THEN PD.Pickslipno ELSE @c_batchkey END
   --WL02 END

   INSERT INTO #Temp_Zone
   SELECT DISTINCT PD.Pickslipno, ISNULL(LOC.Descr,'')
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
   WHERE LPD.Loadkey = @c_loadkey
   AND PD.Pickslipno = CASE WHEN @c_batchkey = '' THEN PD.Pickslipno ELSE @c_batchkey END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Batchkey
   FROM #Temp_Zone
   ORDER BY BatchKey    --WL01

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetBatchkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Zones = STUFF((SELECT ' + ' + RTRIM(Descr) FROM #Temp_Zone WHERE Batchkey = @c_GetBatchkey ORDER BY Descr FOR XML PATH('')),1,1,'' )
      SELECT @c_Zones = SUBSTRING(@c_Zones,3,LEN(@c_Zones))

      DELETE FROM #Temp_Zone
      WHERE BatchKey = @c_GetBatchkey

      INSERT INTO #Temp_Zone
      SELECT @c_GetBatchkey, @c_Zones

      FETCH NEXT FROM CUR_LOOP INTO @c_GetBatchkey
   END

   INSERT INTO #Temp_Result   --WL02
   SELECT  OH.Loadkey
         , PD.Pickslipno AS Batchkey
         --, SUM(PD.Qty) AS TotalQty
         ,(SELECT SUM(P.Qty) FROM PICKDETAIL P (NOLOCK) WHERE P.Pickslipno = PD.Pickslipno) AS TotalQty  --NJOW01
         --, Count(Distinct(PD.SKU)) AS TotalSKU
         ,(SELECT COUNT(DISTINCT P.Sku) FROM PICKDETAIL P (NOLOCK) WHERE P.Pickslipno = PD.Pickslipno) AS TotalSKU   --NJOW01
         , #Temp_Zone.Descr AS AllZones
         , CASE WHEN #Temp_Zone.Descr = 'T1' THEN '2' ELSE '1' END AS [Zone]
         , PH.Pickheaderkey
         , OH.Orderkey
         , CASE WHEN ISNULL(CL.Long,'') = '' THEN '' ELSE '('+ LTRIM(RTRIM(ISNULL(CL.Long,''))) + ')' END AS Title    --WL02
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = OH.ORDERKEY
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.ORDERKEY = OH.ORDERKEY
   JOIN PICKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
   LEFT JOIN #Temp_Zone ON #Temp_Zone.BatchKey = PD.Pickslipno
   JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey = LPD.Loadkey   --WL02
   CROSS APPLY (SELECT TOP 1 LTRIM(RTRIM(ISNULL(t.Shipperkey,''))) AS Shipperkey FROM #TEMP_ByBatch t WHERE t.Batchkey = PD.Pickslipno) AS t1   --WL02
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'IKEATITLE' AND CL.Code = t1.Shipperkey AND CL.Storerkey = OH.Storerkey AND CL.code2 = LP.Facility   --WL02
   WHERE LPD.Loadkey = @c_loadkey
     AND OH.ECOM_Single_Flag = 'M'
     AND PD.Pickslipno = CASE WHEN @c_batchkey = '' THEN PD.Pickslipno ELSE @c_batchkey END
   GROUP BY OH.Loadkey
          , PD.Pickslipno
          , #Temp_Zone.Descr
          , CASE WHEN #Temp_Zone.Descr = 'T1' THEN '2' ELSE '1' END 
          , PH.Pickheaderkey
          , OH.Orderkey
          , CASE WHEN ISNULL(CL.Long,'') = '' THEN '' ELSE '('+ LTRIM(RTRIM(ISNULL(CL.Long,''))) + ')' END   --WL02
   ORDER BY OH.Loadkey, PD.Pickslipno, PH.Pickheaderkey, OH.Orderkey    --WL01  

   SELECT *, (Row_Number() OVER (PARTITION BY Loadkey, Batchkey ORDER BY Loadkey, Batchkey Asc) - 1) / @n_MaxLine FROM #Temp_Result --WL02
   ORDER BY Loadkey, BatchKey, Pickheaderkey, Orderkey   --WL04
       
QUIT_SP:
   IF OBJECT_ID('tempdb..#Temp_Zone') IS NOT NULL
      DROP TABLE #Temp_Zone

   --WL02
   IF OBJECT_ID('tempdb..#Temp_Result') IS NOT NULL   
      DROP TABLE #Temp_Result
   
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') in (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

END -- procedure

GO