SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_MB_MANSUM_006                                   */
/* Creation Date: 14-Dec-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: Adarsh                                                   */
/*                                                                      */
/* Purpose: WMS-21319 - Migrate WMS Report To LogiReport                */
/*                                                                      */
/* Called By: RPT_MB_MANSUM_006                                         */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-Dec-2022 WLChooi  1.0   DevOps Combine Script                     */
/* 31-Oct-2023 WLChooi  1.1   UWP-10213 - Global Timezone (GTZ01)       */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_MB_MANSUM_006]
(@c_Mbolkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_totalorders   INT
         , @n_totalcust     INT
         , @n_totalqty      INT
         , @c_orderkey      NVARCHAR(10)
         , @dc_totalwgt     DECIMAL(7, 2)
         , @c_orderkey2     NVARCHAR(10)
         , @c_prevorder     NVARCHAR(10)
         , @c_pickdetailkey NVARCHAR(18)
         , @c_sku           NVARCHAR(20)
         , @dc_skuwgt       DECIMAL(7, 2)
         , @n_carton        INT
         , @n_totalcarton   INT
         , @n_each          INT
         , @n_totaleach     INT
         , @dc_m3           DECIMAL(7, 2)


   DECLARE @c_FacilityAddr  NVARCHAR(255)
         , @c_FacilityPhone NVARCHAR(255)
         , @c_FacilityFax   NVARCHAR(255)
         , @c_Company       NVARCHAR(255)

   SELECT @c_FacilityAddr = CASE WHEN ISNULL(CL.Short, 'N') = 'Y' THEN
      (LTRIM(RTRIM(ISNULL(F.Address1, ''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address2, ''))) + ' '
       + LTRIM(RTRIM(ISNULL(F.Address3, ''))) + ' ' + LTRIM(RTRIM(ISNULL(F.Address4, ''))) + ' '
       + LTRIM(RTRIM(ISNULL(F.Country, ''))))
                                 ELSE
                                    'IDS Logistics Services (M) Sdn Bhd . Lot 23, Jalan Batu Arang, Rawang Integrated Industrial Park, 48000 Rawang, Selangor Darul Ehsan.' END
        , @c_FacilityPhone = CASE WHEN ISNULL(CL.Short, 'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(F.Phone1, '')))
                                  ELSE '603-60925581' END
        , @c_FacilityFax = CASE WHEN ISNULL(CL.Short, 'N') = 'Y' THEN LTRIM(RTRIM(ISNULL(F.Fax1, '')))
                                ELSE '603-60925681' END
        , @c_Company = CASE WHEN ISNULL(CL.Short, 'N') = 'Y' THEN
                               N'LF Logistics Services (M) Sdn Bhd  � A Li & Fung Company'
                            ELSE '' END
   FROM FACILITY F (NOLOCK)
   JOIN MBOL MB (NOLOCK) ON F.Facility = MB.Facility
   JOIN MBOLDETAIL MD (NOLOCK) ON MB.MbolKey = MD.MbolKey
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = MD.OrderKey
   LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                             AND CL.Code = 'ShowFacilityInfo'
                                             AND CL.Storerkey = OH.StorerKey
                                             AND CL.Long = 'RPT_MB_MANSUM_006'
   WHERE MB.MbolKey = @c_Mbolkey

   DECLARE @c_epodweburl      NVARCHAR(120)
         , @c_epodweburlparam NVARCHAR(500)

   SELECT MBOL.MbolKey
        , vessel = CONVERT(NVARCHAR(30), MBOL.Vessel)
        , MBOL.CarrierKey
        , MBOLDETAIL.LoadKey
        , MBOLDETAIL.OrderKey
        , MBOLDETAIL.ExternOrderKey
        , MBOLDETAIL.Description
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, MBOLDETAIL.DeliveryDate) AS DeliveryDate   --GTZ01
        , totalqty = 0
        , totalorders = 0
        , totalcust = 0
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, MBOL.DepartureDate) AS DepartureDate   --GTZ01
        , totalwgt = 99999999.99
        , totalcarton = 0
        , totaleach = 0
        , TotalCartons = ORDERS.ContainerQty
        , MBOL.Carrieragent
        , MBOL.DRIVERName
        , remarks = CONVERT(NVARCHAR(255), MBOL.Remarks)
        , ISNULL(dbo.fnc_RTRIM(CODELKUP.Long), MBOL.TransMethod) TransMethod
        , MBOL.PlaceOfdelivery
        , MBOL.PlaceOfLoading
        , MBOL.PlaceOfDischarge
        , MBOL.OtherReference
        , ORDERS.InvoiceNo
        , ORDERS.Route
        , m3 = 99999999.99
        , STORER.Logo
        , ORDERS.StorerKey
        , @c_epodweburlparam AS epodfullurl
        , @c_FacilityAddr AS FacilityAddr
        , @c_FacilityPhone AS FacilityPhone
        , @c_FacilityFax AS FacilityFax
        , @c_Company AS Company
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   INTO #RESULT
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey
   JOIN ORDERS WITH (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey
   JOIN STORER WITH (NOLOCK) ON ORDERS.StorerKey = STORER.StorerKey
   LEFT OUTER JOIN CODELKUP WITH (NOLOCK) ON CODELKUP.LISTNAME = 'TRANSMETH' AND CODELKUP.Code = MBOL.TransMethod
   WHERE MBOL.MbolKey = @c_Mbolkey

   SELECT @n_totalorders = COUNT(*)
        , @n_totalcust = COUNT(DISTINCT Description)
   FROM MBOLDETAIL WITH (NOLOCK)
   WHERE MbolKey = @c_Mbolkey

   UPDATE #RESULT
   SET totalorders = @n_totalorders
     , totalcust = @n_totalcust
   WHERE MbolKey = @c_Mbolkey

   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM #RESULT
   OPEN cur_1
   FETCH NEXT FROM cur_1
   INTO @c_orderkey
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SELECT @n_totalqty = ISNULL(SUM(Qty), 0)
      FROM PICKDETAIL WITH (NOLOCK)
      WHERE OrderKey = @c_orderkey

      UPDATE #RESULT
      SET totalqty = @n_totalqty
        , epodfullurl = @c_orderkey
      WHERE MbolKey = @c_Mbolkey AND OrderKey = @c_orderkey

      FETCH NEXT FROM cur_1
      INTO @c_orderkey
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT ORDERS.MBOLKey
        , ORDERS.OrderKey
        , totwgt = ISNULL(SUM(PICKDETAIL.Qty), 0) * SKU.STDGROSSWGT
        , totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty), 0) / PACK.CaseCnt
                       ELSE 0 END
        , totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty), 0) % CAST(PACK.CaseCnt AS INT)
                       ELSE 0 END
        , m3 = CASE WHEN PACK.CaseCnt > 0 THEN (SKU.[Cube] * ISNULL(SUM(PICKDETAIL.Qty), 0)) / (PACK.CaseCnt)
                    ELSE 0 END
   INTO #TEMPCALC
   FROM PICKDETAIL WITH (NOLOCK)
   INNER JOIN SKU WITH (NOLOCK) ON PICKDETAIL.Sku = SKU.Sku AND (PICKDETAIL.Storerkey = SKU.StorerKey)
   INNER JOIN PACK WITH (NOLOCK) ON PICKDETAIL.PackKey = PACK.PackKey
   INNER JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey AND ORDERS.MBOLKey = @c_Mbolkey)
   GROUP BY ORDERS.MBOLKey
          , ORDERS.OrderKey
          , PACK.CaseCnt
          , SKU.STDGROSSWGT
          , SKU.[Cube]

   SELECT MBOLKey
        , OrderKey
        , totwgt = SUM(totwgt)
        , totcs = SUM(totcs)
        , totea = SUM(totea)
        , m3 = SUM(m3)
   INTO #TEMPTOTAL
   FROM #TEMPCALC
   GROUP BY MBOLKey
          , OrderKey

   UPDATE #RESULT
   SET totalwgt = T.totwgt
     , totalcarton = T.totcs
     , totaleach = T.totea
     , m3 = T.m3
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
END

GO