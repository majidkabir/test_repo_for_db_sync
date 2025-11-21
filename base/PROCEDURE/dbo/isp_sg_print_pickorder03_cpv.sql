SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_sg_print_pickorder03_cpv                            */
/* Creation Date: 24-Aug-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23507 - SG - CPV - Picking Slip DW update [CR]          */
/*          Convert Query to SP                                         */
/*        :                                                             */
/* Called By: r_sg_print_pickorder03_cpv                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 24-Aug-2023  WLChooi   1.0 DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_sg_print_pickorder03_cpv]
(
   @c_Loadkey  NVARCHAR(10) = ''
 , @c_Orderkey NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT
         , @c_errmsg   NVARCHAR(255)
         , @b_success  INT
         , @n_err      INT

   DECLARE @T_ORD AS TABLE
   (
      Orderkey NVARCHAR(10)
   )

   IF ISNULL(@c_Orderkey, '') <> '' --By Order
   BEGIN
      INSERT INTO @T_ORD (Orderkey)
      SELECT @c_Orderkey
   END
   ELSE IF ISNULL(@c_Loadkey, '') <> '' AND ISNULL(@c_Orderkey, '') = '' --By Load
   BEGIN
      INSERT INTO @T_ORD (Orderkey)
      SELECT OrderKey
      FROM LoadPlanDetail (NOLOCK)
      WHERE LoadKey = @c_Loadkey
   END

   SELECT O.LoadKey
        , O.OrderKey
        , OrderKey_Barcode = '*' + O.OrderKey + '*'
        , O.ExternOrderKey
        , O.InvoiceNo
        , ISNULL(O.DeliveryDate, '19000101') DeliveryDate
        , ISNULL(O.BillToKey, '') AS ConsigneeKey
        , ISNULL(O.C_Company, '') AS Company
        , ISNULL(O.C_Address1, '') AS Addr1
        , ISNULL(O.C_Address2, '') AS Addr2
        , ISNULL(O.C_Address3, '') AS Addr3
        , ISNULL(O.C_Zip, '') AS PostCode
        , ISNULL(O.Route, '') AS Route
        , ISNULL(RM.Descr, '') Route_Desc
        , O.Door AS TrfRoom
        , CONVERT(NVARCHAR(200), ISNULL(O.Notes, '')) Notes1
        , CONVERT(NVARCHAR(200), ISNULL(O.Notes2, '')) Notes2
        , '' CarrierKey
        , '' AS VehicleNo
        , OD.Sku
        , ISNULL(S.DESCR, '') SkuDesc
        , S.SUSR3
        , SUM(OD.OriginalQty / P.CaseCnt) AS OrderQty
        , OD.UOM
        , OD.PackKey
        , Location = ISNULL(INV.Loc, '')
        , FamilyGroup = S.BUSR10
        , Box = S.BUSR5
        , Powers = S.Style
        , CYC = S.Size
        , Axis = S.Measurement
        , Type = (CASE O.Type
                       WHEN 'E' THEN 'EXCHANGE'
                       WHEN '0' THEN 'STD ORDER' END)
   FROM dbo.V_ORDERS O WITH (NOLOCK)
   INNER JOIN dbo.V_ORDERDETAIL OD WITH (NOLOCK) ON (OD.StorerKey = O.StorerKey AND OD.OrderKey = O.OrderKey)
   INNER JOIN dbo.V_SKU S WITH (NOLOCK) ON (S.StorerKey = OD.StorerKey AND S.Sku = OD.Sku)
   INNER JOIN dbo.V_PACK P WITH (NOLOCK) ON (P.PackKey = S.PACKKey)
   LEFT OUTER JOIN dbo.V_RouteMaster RM WITH (NOLOCK) ON (RM.Route = O.Route)
   LEFT OUTER JOIN (  SELECT LLID.StorerKey
                           , LLID.Sku
                           , MIN(LLID.Loc) Loc
                      FROM [dbo].[V_Inv_LotByLocByID] LLID WITH (NOLOCK)
                      INNER JOIN dbo.V_LOC L WITH (NOLOCK) ON L.Loc = LLID.Loc
                      WHERE LLID.StorerKey = 'CPV' AND L.HOSTWHCODE = 'FWDPICK'
                      GROUP BY LLID.StorerKey
                             , LLID.Sku) INV ON INV.StorerKey = O.StorerKey AND INV.Sku = OD.Sku
   JOIN @T_ORD T ON T.Orderkey = O.OrderKey
   GROUP BY O.LoadKey
          , O.OrderKey
          , O.ExternOrderKey
          , O.InvoiceNo
          , ISNULL(O.DeliveryDate, '19000101')
          , ISNULL(O.BillToKey, '')
          , ISNULL(O.C_Company, '')
          , ISNULL(O.C_Address1, '')
          , ISNULL(O.C_Address2, '')
          , ISNULL(O.C_Address3, '')
          , ISNULL(O.C_Zip, '')
          , ISNULL(O.Route, '')
          , ISNULL(RM.Descr, '')
          , O.Door
          , CONVERT(NVARCHAR(200), ISNULL(O.Notes, ''))
          , CONVERT(NVARCHAR(200), ISNULL(O.Notes2, ''))
          , OD.Sku
          , ISNULL(S.DESCR, '')
          , S.SUSR3
          , OD.UOM
          , OD.PackKey
          , ISNULL(INV.Loc, '')
          , S.BUSR10
          , S.BUSR5
          , S.Style
          , S.Size
          , S.Measurement
          , O.Type

END

GO