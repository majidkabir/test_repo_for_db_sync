SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_GetPickSlipOrders104Single_rpt                          */
/* Creation Date: 26-Dec-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-11495 - IKEA Pick Slip Single Order                    */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 21/07/2021   Mingle    1.1   WMS-17541 Add codelkup.long(ML01)       */
/* 15-Aug-2023  WLChooi   1.2   WMS-23378 - Add new logic (WL01)        */
/* 15-Aug-2023  WLChooi   1.2   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPickSlipOrders104Single_rpt]
   @c_Loadkey  NVARCHAR(10)
 , @c_Batchkey NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue    INT           = 1
         , @c_Zones       NVARCHAR(255) = N''
         , @c_GetBatchkey NVARCHAR(10)  = N''

   IF @c_Batchkey = NULL
      SET @c_Batchkey = ''

   CREATE TABLE #Temp_Zone
   (
      BatchKey NVARCHAR(10)
    , Descr    NVARCHAR(255)
   )

   INSERT INTO #Temp_Zone
   SELECT DISTINCT PD.PickSlipNo
                 , ISNULL(LOC.Descr, '')
   FROM LoadPlanDetail LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LOC (NOLOCK) ON LOC.Loc = PD.Loc
   WHERE LPD.LoadKey = @c_Loadkey AND PD.PickSlipNo = CASE WHEN @c_Batchkey = '' THEN PD.PickSlipNo
                                                           ELSE @c_Batchkey END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT BatchKey
   FROM #Temp_Zone

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_GetBatchkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_Zones = STUFF((  SELECT ' + ' + RTRIM(Descr)
                                 FROM #Temp_Zone
                                 WHERE BatchKey = @c_GetBatchkey
                                 ORDER BY Descr
                                 FOR XML PATH(''))
                            , 1
                            , 1
                            , '')
      SELECT @c_Zones = SUBSTRING(@c_Zones, 3, LEN(@c_Zones))

      DELETE FROM #Temp_Zone
      WHERE BatchKey = @c_GetBatchkey

      INSERT INTO #Temp_Zone
      SELECT @c_GetBatchkey
           , @c_Zones

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetBatchkey
   END

   SELECT OH.LoadKey
        , PD.PickSlipNo AS Batchkey
        , COUNT(DISTINCT (PD.Sku)) AS TotalSKU
        , SUM(PD.Qty) AS TotalUnit
        , #Temp_Zone.Descr AS AllZones
        , LOC.PickZone AS PickZone
        , IIF(ISNULL(C1.Long, '') <> '', ISNULL(C1.Long, ''), ISNULL(CL.Long, '')) AS Title --ML01   --WL01
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   --JOIN PICKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
   JOIN LOC (NOLOCK) ON LOC.Loc = PD.Loc
   LEFT JOIN ORDERINFO OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey   --WL01
   LEFT JOIN #Temp_Zone ON #Temp_Zone.BatchKey = PD.PickSlipNo
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'IKEATITLE'
                                  AND CL.Storerkey = OH.StorerKey
                                  AND CL.Code = OH.Shipperkey
   LEFT JOIN CODELKUP C1 (NOLOCK) ON  C1.LISTNAME = 'IKEATITLE'
                                  AND C1.Storerkey = OH.StorerKey
                                  AND C1.Code = OIF.StoreName --ML01                               
   WHERE LPD.LoadKey = @c_Loadkey
   AND   OH.ECOM_SINGLE_Flag = 'S'
   AND   PD.PickSlipNo = CASE WHEN @c_Batchkey = '' THEN PD.PickSlipNo
                              ELSE @c_Batchkey END
   GROUP BY OH.LoadKey
          , PD.PickSlipNo
          , #Temp_Zone.Descr
          , LOC.PickZone
          , ISNULL(CL.Long, '') --ML01

   QUIT_SP:
   IF OBJECT_ID('tempdb..#Temp_Zone') IS NOT NULL
      DROP TABLE #Temp_Zone

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
END -- procedure

GO