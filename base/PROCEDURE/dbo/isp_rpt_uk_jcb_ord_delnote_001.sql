SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: isp_RPT_UK_JCB_ORD_DELNOTE_001                        */
/* Creation Date: 20-JUN-2024                                              */
/* Copyright: Maersk                                                       */
/* Written by: MMA982                                                      */
/*                                                                         */
/* Purpose: WCEET-2232                                                     */
/*                                                                         */
/* Called By: RPT_UK_JCB_ORD_DELNOTE_001                                   */
/*                                                                         */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_UK_JCB_ORD_DELNOTE_001] @c_Orderkey NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_FromStorerkey NVARCHAR(15)
         , @c_Type          NVARCHAR(1)  = N'1'
         , @c_DataWindow    NVARCHAR(60) = N'RPT_ORD_DELNOTE_001'
         , @c_RetVal        NVARCHAR(255)
   EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_FromStorerkey
                                 , @c_Type = @c_Type
                                 , @c_DataWindow = @c_DataWindow
                                 , @c_RetVal = @c_RetVal OUTPUT
    SELECT ORDERS.ConsigneeKey 
        , ORDERS.IntermodalVehicle
		, isnull( rc.UserDefine02, r.UserDefine02) as SupplierID
		, isnull( rc.UserDefine01, r.UserDefine01) as Invoice
		, st.Company as SupplierName
		, ORDERS.C_Company
        , ORDERS.C_Address1
        , ORDERS.C_Address2
        , ORDERS.C_Address3
        , ORDERS.C_Address4
        , ORDERS.Notes
        , STORER.Company
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, ORDERS.AddDate) AS AddDate   --GTZ01
        , ORDERS.ExternOrderKey
        , ORDERS.OrderKey
        , ORDERS.Door
        , ORDERS.Route
        , SKU.DESCR
        , (ORDD.QtyPicked + ORDD.ShippedQty) AS QtyPicked
        , ORDD.Sku
        , ORDERS.DeliveryNote
        , ORDERS.Rdd
        , STORER.Logo
        , ORDD.OrderLineNumber
        , ORDERS.BuyerPO
        , ORDERS.StorerKey
        , SKU.RETAILSKU
        , ISNULL(CL.Short, 'N') AS 'ShowField'
        , ISNULL(f.UserDefine02, 'LF Asia') AS 'FCompany'
        , ISNULL(C.Short, 'N') AS 'ShowBuyerPO'
        , ISNULL(ORDD.UserDefine03, '') AS 'odudf03'
        , ISNULL(CL1.Short, 'N') AS 'ShowBarcode'
        , ISNULL(CL2.Short, 'N') AS 'ShowDeliveryDate'
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, ORDERS.DeliveryDate) AS DeliveryDate   --GTZ01
        , ISNULL(CL3.Short, 'N') AS 'ShowSPRemarks'
        , @c_RetVal AS 'LogoName'
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM ORDERS WITH (NOLOCK)
   JOIN ORDERDETAIL ORDD WITH (NOLOCK) ON (ORDERS.OrderKey = ORDD.OrderKey)
   JOIN SKU WITH (NOLOCK) ON (SKU.Sku = ORDD.Sku) AND (ORDD.StorerKey = SKU.StorerKey)
   JOIN STORER WITH (NOLOCK) ON (SKU.StorerKey = STORER.StorerKey)
   JOIN PICKDETAIL pkd WITH (NOLOCK) on ( ORDERS.StorerKey = pkd.StorerKey) and (ORDERS.OrderKey = pkd.OrderKey) 
   JOIN LOTATTRIBUTE lota WITH (NOLOCK) on pkd.lot = lota.lot and pkd.Storerkey = lota.StorerKey
   LEFT JOIN Receipt rc on rc.StorerKey = lota.StorerKey and rc.ReceiptKey = lota.Lottable02 
   LEFT JOIN GLOARCHIVE.dbo.RECEIPT R ON R.RECEIPTKEY = lota.Lottable02 and R.StorerKey = Lota.StorerKey
   LEFT JOIN STORER st on st.StorerKey = rc.UserDefine02 and st.SUSR1 = rc.StorerKey
   LEFT JOIN CODELKUP AS CL WITH (NOLOCK) ON  CL.LISTNAME = 'REPORTCFG'
                                          AND CL.Long = 'r_dw_delivery_note'
                                          AND CL.Code = 'SHOWFIELD'
                                          AND CL.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS C WITH (NOLOCK) ON  C.LISTNAME = 'REPORTCFG'
                                         AND C.Long = 'r_dw_delivery_note'
                                         AND C.Code = 'SHOWBUYERPO'
                                         AND C.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL1 WITH (NOLOCK) ON  CL1.LISTNAME = 'REPORTCFG'
                                           AND CL1.Long = 'r_dw_delivery_note'
                                           AND CL1.Code = 'ShowBarcode'
                                           AND CL1.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL2 WITH (NOLOCK) ON  CL2.LISTNAME = 'REPORTCFG'
                                           AND CL2.Long = 'r_dw_delivery_note'
                                           AND CL2.Code = 'ShowDeliveryDate'
                                           AND CL2.Storerkey = STORER.StorerKey
   LEFT JOIN CODELKUP AS CL3 WITH (NOLOCK) ON  CL3.LISTNAME = 'REPORTCFG'
                                           AND CL3.Long = 'r_dw_delivery_note'
                                           AND CL3.Code = 'SHOWSPREMARKS'
                                           AND CL3.Storerkey = STORER.StorerKey
   LEFT JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility = STORER.Facility
   WHERE ((ORDERS.OrderKey = @c_Orderkey))
   ORDER BY CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDD.UserDefine03 END DESC
          , CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDD.OrderLineNumber END
          , CASE WHEN ISNULL(C.Short, 'N') = 'Y' THEN ORDD.Sku END ASC
          , CASE WHEN ISNULL(C.Short, 'N') = 'N' THEN ORDD.OrderLineNumber END ASC
          , CASE WHEN ISNULL(C.Short, 'N') = 'N' THEN ORDD.Sku END ASC
END
GO