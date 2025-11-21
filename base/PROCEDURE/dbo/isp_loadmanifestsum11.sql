SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadManifestSum11                              */
/* Creation Date: 12-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21550 - MY - LECREUSET - Load Manifest Report           */
/*          Copy from nsp_LoadManifestSum01                             */
/*                                                                      */
/* Called By: PB dw: r_dw_dmanifest_sum11 (RCM ReportType 'MANSUM')     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 12-Jan-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadManifestSum11]
(@c_mbolkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_totalorders   INT
         , @n_totalcust     INT
         , @n_totalqty      INT
         , @c_orderkey      NVARCHAR(10)
         , @dc_totalwgt     DECIMAL(10, 5)
         , @c_orderkey2     NVARCHAR(10)
         , @c_prevorder     NVARCHAR(10)
         , @c_pickdetailkey NVARCHAR(18)
         , @c_sku           NVARCHAR(20)
         , @dc_skuwgt       DECIMAL(10, 5)
         , @n_carton        INT
         , @n_totalcarton   INT
         , @n_each          INT
         , @n_totaleach     INT

   SELECT MBOL.MbolKey
        , Vessel = MBOL.Vessel
        , MBOL.CarrierKey
        , MBOLDETAIL.LoadKey
        , MBOLDETAIL.OrderKey
        , MBOLDETAIL.ExternOrderKey
        , MBOLDETAIL.Description
        , MBOLDETAIL.DeliveryDate
        , totalqty = 0
        , totalorders = 0
        , totalcust = 0
        , MBOL.DepartureDate
        , totalwgt = CAST(0.00000 AS DECIMAL(10, 5))
        , totalcarton = 0
        , totaleach = 0
        , MBOLDETAIL.TotalCartons
        , ORDERS.StorerKey
        , MBOL.Carrieragent
        , MBOL.PlaceOfdelivery
        , MBOL.PlaceOfDischarge
        , MBOL.OtherReference
        , MBOL.DRIVERName
        , MBOL.TransMethod
        , MBOL.PlaceOfLoading
        , MBOL.Remarks
        , ISNULL(CL.Short, 'N') AS ShowBarcode
        , CASE WHEN ORDERS.StorerKey = 'IDSMED' THEN ORDERS.OrderGroup
               ELSE MBOLDETAIL.OrderKey END AS ShowOrdGrp
        , ISNULL(CL.Short, 'N') AS RepOrdKeybyOrdGrp
        , CAST(0.00000 AS DECIMAL(10, 5)) AS TotalM3
   INTO #RESULT
   FROM MBOL (NOLOCK)
   INNER JOIN MBOLDETAIL (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey
   INNER JOIN ORDERS (NOLOCK) ON MBOL.MbolKey = ORDERS.MBOLKey AND MBOLDETAIL.OrderKey = ORDERS.OrderKey
   LEFT JOIN CODELKUP CL (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                  AND CL.Storerkey = ORDERS.StorerKey
                                  AND CL.Code = 'ShowBarcode'
                                  AND CL.Long = 'r_dw_dmanifest_sum11'
   LEFT JOIN CODELKUP CL1 (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                   AND CL1.Storerkey = ORDERS.StorerKey
                                   AND CL1.Code = 'RepOrdKeybyOrdGrp'
                                   AND CL1.Long = 'r_dw_dmanifest_sum11'
   WHERE MBOL.MbolKey = @c_mbolkey

   SELECT @n_totalorders = COUNT(*)
        , @n_totalcust = COUNT(DISTINCT Description)
   FROM MBOLDETAIL (NOLOCK)
   WHERE MbolKey = @c_mbolkey

   UPDATE #RESULT
   SET totalorders = @n_totalorders
     , totalcust = @n_totalcust
   WHERE MbolKey = @c_mbolkey

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM #RESULT

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_orderkey

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @n_totalqty = ISNULL(SUM(Qty), 0)
      FROM PICKDETAIL (NOLOCK)
      WHERE OrderKey = @c_orderkey
      UPDATE #RESULT
      SET totalqty = @n_totalqty
      WHERE MbolKey = @c_mbolkey AND OrderKey = @c_orderkey

      FETCH NEXT FROM CUR_LOOP
      INTO @c_orderkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT ORDERS.MBOLKey
        , ORDERS.OrderKey
        , totwgt = ISNULL(SUM(PICKDETAIL.Qty), 0) * SKU.STDGROSSWGT
        , totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty), 0) / PACK.CaseCnt
                       ELSE 0 END
        , totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty), 0) % CAST(PACK.CaseCnt AS INT)
                       ELSE 0 END
        , TotalM3 = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.STDCUBE * ISNULL(SUM(PICKDETAIL.Qty), 0)) / (PACK.CaseCnt)
                         ELSE 0 END
   INTO #TEMPCALC
   FROM PICKDETAIL (NOLOCK)
   JOIN SKU (NOLOCK) ON PICKDETAIL.Sku = SKU.Sku AND PICKDETAIL.Storerkey = SKU.StorerKey
   JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
   JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
   WHERE ORDERS.MBOLKey = @c_mbolkey
   GROUP BY ORDERS.MBOLKey
          , ORDERS.OrderKey
          , PACK.CaseCnt
          , SKU.STDGROSSWGT
          , SKU.STDCUBE

   SELECT MBOLKey
        , OrderKey
        , totwgt = SUM(totwgt)
        , totcs = SUM(totcs)
        , totea = SUM(totea)
        , TotalM3 = SUM(TotalM3)
   INTO #TEMPTOTAL
   FROM #TEMPCALC
   GROUP BY MBOLKey
          , OrderKey

   UPDATE #RESULT
   SET totalwgt = t.totwgt
     , totalcarton = t.totcs
     , totaleach = t.totea
     , TotalM3 = t.TotalM3
   FROM #TEMPTOTAL t
   WHERE #RESULT.MbolKey = t.MBOLKey AND #RESULT.OrderKey = t.OrderKey

   SELECT *
   FROM #RESULT
   ORDER BY LoadKey
          , OrderKey

   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT

   IF OBJECT_ID('tempdb..#TEMPCALC') IS NOT NULL
      DROP TABLE #TEMPCALC

   IF OBJECT_ID('tempdb..#TEMPTOTAL') IS NOT NULL
      DROP TABLE #TEMPTOTAL

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

END

GO