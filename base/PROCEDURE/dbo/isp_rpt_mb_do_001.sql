SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_DO_001                                  */
/* Creation Date: 11-April-2022                                         */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-19850 - Convert to Logi Report - r_dw_delivery_note04   */
/*                                                                      */
/* Called By: RPT_MB_DO_001                                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 05-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 31-Oct-2023  WLChooi  1.1  UWP-10213 - Global Timezone (GTZ01)       */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_MB_DO_001]
(
   @c_mbolkey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Type           NVARCHAR(1)  = N'1'
         , @c_DataWindow     NVARCHAR(60) = N'RPT_TRF_PRNTRFTKT_001'
         , @c_RetVal         NVARCHAR(255)
         , @c_Externorderkey NVARCHAR(20)
         , @n_len            INT          = 0


   SELECT @c_Externorderkey = ISNULL(RTRIM(ExternOrderKey), '')
        , @c_Storerkey = StorerKey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_mbolkey

   EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_Storerkey
                                 , @c_Type = @c_Type
                                 , @c_DataWindow = @c_DataWindow
                                 , @c_RetVal = @c_RetVal OUTPUT

   SET @c_Externorderkey = SUBSTRING(@c_Externorderkey, 8, 10) + SUBSTRING(@c_Externorderkey, 6, 2)

   SELECT ORDERS.ExternOrderKey
        , @c_Externorderkey AS ExternOrderKey2
        , ORDERS.BillToKey
        , ORDERS.B_Company
        , ORDERS.B_Address1
        , ORDERS.B_Address2
        , ORDERS.B_Address3
        , ORDERS.B_Address4
        , ORDERS.B_Zip
        , ORDERS.B_Country
        , ORDERS.ConsigneeKey
        , ORDERS.C_Company
        , ORDERS.C_Address1
        , ORDERS.C_Address2
        , ORDERS.C_Address3
        , ORDERS.C_Address4
        , ORDERS.C_Zip
        , ORDERS.C_Country
        , ORDERS.IntermodalVehicle
        , ORDERS.DeliveryPlace
        , ORDERS.DischargePlace
        , CAST(ORDERS.Notes AS NVARCHAR(250)) AS Notes
        , ORDERS.BuyerPO
        , ORDERS.OrderKey
        , ORDERDETAIL.Sku
        , SKU.DESCR
        , LOTATTRIBUTE.Lottable02
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, LOTATTRIBUTE.Lottable04) AS Lottable04   --GTZ01
        , SUM(PICKDETAIL.Qty) AS QtyPicked
        , CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.PackUOM1
               ELSE PACK.PackUOM3 END AS UOM
        , CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.CaseCnt
               ELSE PACK.Qty END AS PACKQty
        , STORER.Company
        , STORER.Address1
        , STORER.Address2
        , STORER.Address3
        , STORER.Address4
        , STORER.Zip
        , STORER.Country
        , ORDERS.MBOLKey
        , ORDERS.LoadKey
        , ORDERS.PrintFlag
        , STORER.Logo
        , ISNULL(@c_RetVal, '') AS Logo2
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   INTO #TMP_DO
   FROM ORDERS (NOLOCK)
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
   JOIN PICKDETAIL (NOLOCK) ON  (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey)
                            AND (ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
   JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey) AND (SKU.Sku = ORDERDETAIL.Sku)
   JOIN PACK (NOLOCK) ON (SKU.PACKKey = PACK.PackKey)
   JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   WHERE (ORDERS.[Status] >= '5') AND (ORDERS.MBOLKey = @c_mbolkey)
   GROUP BY ORDERS.ExternOrderKey
          , ORDERS.BillToKey
          , ORDERS.B_Company
          , ORDERS.B_Address1
          , ORDERS.B_Address2
          , ORDERS.B_Address3
          , ORDERS.B_Address4
          , ORDERS.B_Zip
          , ORDERS.B_Country
          , ORDERS.B_Phone1
          , ORDERS.ConsigneeKey
          , ORDERS.C_Company
          , ORDERS.C_Address1
          , ORDERS.C_Address2
          , ORDERS.C_Address3
          , ORDERS.C_Address4
          , ORDERS.C_Zip
          , ORDERS.C_Country
          , ORDERS.C_Phone1
          , ORDERS.IntermodalVehicle
          , ORDERS.DeliveryPlace
          , ORDERS.DischargePlace
          , CAST(ORDERS.Notes AS NVARCHAR(250))
          , ORDERS.BuyerPO
          , ORDERS.OrderKey
          , ORDERDETAIL.Sku
          , SKU.DESCR
          , LOTATTRIBUTE.Lottable02
          , LOTATTRIBUTE.Lottable04
          , CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.PackUOM1
                 ELSE PACK.PackUOM3 END
          , CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.CaseCnt
                 ELSE PACK.Qty END
          , STORER.Company
          , STORER.Address1
          , STORER.Address2
          , STORER.Address3
          , STORER.Address4
          , STORER.Zip
          , STORER.Country
          , ORDERS.MBOLKey
          , ORDERS.LoadKey
          , ORDERS.PrintFlag
          , STORER.Logo
          , ORDERS.StorerKey   --GTZ01
          , ORDERS.Facility   --GTZ01

   IF ISNULL(@c_PreGenRptData, '') = 'Y'
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET PrintFlag = 'Y'
        , EditDate = GETDATE()
        , TrafficCop = NULL
      WHERE MBOLKey = @c_mbolkey
   END
   ELSE
   BEGIN
      SELECT *
      FROM #TMP_DO
   END
END

GO