SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/***************************************************************************/
/* Stored Procedure: isp_RPT_ORD_DELNOTE_008                               */
/* Creation Date: 13-Oct-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: UWP-9521 - LogiReport - Delivery Note - Add New Fields         */
/*                                                                         */
/* Called By: RPT_ORD_DELNOTE_008                                          */
/*                                                                         */
/* Github Version: 1.1                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 13-Oct-2023  WLChooi 1.0   DevOps Combine Script                        */
/* 20-Oct-2023  WLChooi 1.1   UWP-9867 - Add SealNo (WL01)                 */
/* 09-Sep-2024  XLL1.2        UWP-24051 - Global Timezone(XLL01)           */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_ORD_DELNOTE_008] @c_Orderkey NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_FromStorerkey NVARCHAR(15)
         , @c_Type          NVARCHAR(1)  = N'1'
         , @c_LogiRpt       NVARCHAR(60) = N'RPT_ORD_DELNOTE_008'
         , @c_RetVal        NVARCHAR(255)

   SELECT @c_FromStorerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_FromStorerkey
                                 , @c_Type = @c_Type
                                 , @c_DataWindow = @c_LogiRpt
                                 , @c_RetVal = @c_RetVal OUTPUT

   IF OBJECT_ID('tempdb..#TEMP_ORD') IS NOT NULL
      DROP TABLE #TEMP_ORD

   SELECT ORDERS.C_Company
        , ORDERS.C_Address1
        , ORDERS.C_Address2
        , ORDERS.C_Address3
        , ORDERS.C_Address4
        , ORDERS.Notes
        , STORER.Company
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, orders.Facility, ORDERS.AddDate) AddDate --XLL01
        , ORDERS.ExternOrderKey
        , ORDERS.OrderKey
        , ORDERS.Door
        , ORDERS.[Route]
        , SKU.DESCR
        , (ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) AS QtyPicked
        , ORDERDETAIL.Sku
        , ORDERS.DeliveryNote
        , ORDERS.Rdd
        , STORER.Logo
        , ORDERDETAIL.OrderLineNumber
        , ORDERS.BuyerPO
        , ORDERS.StorerKey
        , SKU.RETAILSKU
        , ISNULL(CL.Short, 'N') AS 'ShowField'
        , ISNULL(f.UserDefine02, 'MAERSK') AS 'FCompany'
        , ISNULL(C.Short, 'N') AS 'ShowBuyerPO'
        , ISNULL(ORDERDETAIL.UserDefine03, '') AS 'odudf03'
        , ISNULL(CL1.Short, 'N') AS 'ShowBarcode'
        , ISNULL(CL2.Short, 'N') AS 'ShowDeliveryDate' 
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, ORDERS.DeliveryDate) DeliveryDate --XLL01
        , ISNULL(CL3.Short, 'N') AS 'ShowSPRemarks'
        , @c_RetVal AS 'LogoName'
        , ISNULL(M.ContainerNo,'') AS ContainerNo
        , ISNULL(SKU.Tariffkey,'') AS Tariffkey
        , ISNULL(SKU.NetWgt,0.00) * (ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) AS SKUNetWgt
        , ISNULL(M.SealNo,'') AS SealNo   --WL01
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, GETDATE()) AS CurrentDateTime --XLL01
   INTO #TEMP_ORD
   FROM ORDERS WITH (NOLOCK)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
   JOIN SKU WITH (NOLOCK) ON (SKU.Sku = ORDERDETAIL.Sku) AND (ORDERDETAIL.StorerKey = SKU.StorerKey)
   JOIN STORER WITH (NOLOCK) ON (SKU.StorerKey = STORER.StorerKey)
   LEFT JOIN CODELKUP AS CL WITH (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                          AND CL.Long = @c_LogiRpt
                                          AND CL.Code = 'SHOWFIELD'
                                          AND CL.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS C WITH (NOLOCK) ON  C.LISTNAME = 'REPORTCFG'
                                         AND C.Long = @c_LogiRpt
                                         AND C.Code = 'SHOWBUYERPO'
                                         AND C.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL1 WITH (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                           AND CL1.Long = @c_LogiRpt
                                           AND CL1.Code = 'ShowBarcode'
                                           AND CL1.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'
                                           AND CL2.Long = @c_LogiRpt
                                           AND CL2.Code = 'ShowDeliveryDate'
                                           AND CL2.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL3 WITH (NOLOCK) ON  CL3.LISTNAME = 'REPORTCFG'
                                           AND CL3.Long = @c_LogiRpt
                                           AND CL3.Code = 'SHOWSPREMARKS'
                                           AND CL3.Storerkey = STORER.StorerKey
   LEFT JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility = STORER.Facility
   LEFT JOIN MBOL AS M WITH (NOLOCK) ON ORDERS.MBOLKey = M.MbolKey
   WHERE ((ORDERS.OrderKey = @c_Orderkey))
   ORDER BY CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDERDETAIL.UserDefine03 END DESC
          , CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDERDETAIL.OrderLineNumber END
          , CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDERDETAIL.Sku END ASC
          , CASE WHEN ISNULL(C.Short, 'N') = 'N' THEN ORDERDETAIL.OrderLineNumber END ASC
          , CASE WHEN ISNULL(C.Short, 'N') = 'N' THEN ORDERDETAIL.Sku END ASC

   SELECT TOR.C_Company
        , TOR.C_Address1
        , TOR.C_Address2
        , TOR.C_Address3
        , TOR.C_Address4
        , TOR.Notes
        , TOR.Company
        , TOR.AddDate
        , TOR.ExternOrderKey
        , TOR.OrderKey
        , TOR.Door
        , TOR.[Route]
        , TOR.DESCR
        , TOR.QtyPicked
        , TOR.Sku
        , TOR.DeliveryNote
        , TOR.Rdd
        , TOR.Logo
        , TOR.OrderLineNumber
        , TOR.BuyerPO
        , TOR.StorerKey
        , TOR.RETAILSKU
        , TOR.ShowField
        , TOR.FCompany
        , TOR.ShowBuyerPO
        , TOR.odudf03
        , TOR.ShowBarcode
        , TOR.ShowDeliveryDate
        , TOR.DeliveryDate
        , TOR.ShowSPRemarks
        , TOR.LogoName
        , TOR.ContainerNo
        , TOR.Tariffkey
        , TOR.SKUNetWgt
        , (SELECT SUM(T1.QtyPicked) FROM #TEMP_ORD T1 WHERE T1.Orderkey = TOR.OrderKey) AS TTLQtyPicked
        , (SELECT SUM(T1.SKUNetWgt) FROM #TEMP_ORD T1 WHERE T1.Orderkey = TOR.OrderKey) AS TTLSKUNetWgt
        , TOR.SealNo   --WL01
        , CurrentDateTime  --XLL01
   FROM #TEMP_ORD TOR
   ORDER BY CASE WHEN ISNULL(ShowBuyerPO, 'N') = 'Y' THEN odudf03 END DESC
          , CASE WHEN ISNULL(ShowBuyerPO, 'N') = 'Y' THEN OrderLineNumber END
          , CASE WHEN ISNULL(ShowBuyerPO, 'N') = 'Y' THEN Sku END ASC
          , CASE WHEN ISNULL(ShowBuyerPO, 'N') = 'N' THEN OrderLineNumber END ASC
          , CASE WHEN ISNULL(ShowBuyerPO, 'N') = 'N' THEN Sku END ASC

   IF OBJECT_ID('tempdb..#TEMP_ORD') IS NOT NULL
      DROP TABLE #TEMP_ORD
END
GO