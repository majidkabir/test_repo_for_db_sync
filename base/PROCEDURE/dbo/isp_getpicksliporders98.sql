SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders98                              */
/* Creation Date: 19-SEP-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: WLCHOOI                                                   */
/*                                                                       */
/* Purpose: WMS-10618 - CN Nike Direct ship to NFS via OOCL-DIG          */
/*                                                                       */
/* Called By: r_dw_print_pickorder98                                     */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders98] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_errmsg        = ''

   SELECT   PD.OrderKey
          , O.IntermodalVehicle
          , O.[Type]
          , O.ExternOrderKey
          , O.LoadKey
          , PH.PickHeaderKey
          , CASE ISNULL(o.UserDefine10, '') WHEN '' THEN CONVERT(NVARCHAR(10), DeliveryDate, 120) 
                                                    ELSE o.UserDefine10 END AS '计划发货时间'
          , O.UserDefine01
          , O.ConsigneeKey
          , O.C_State
          , O.C_City
          , O.C_Zip
          , O.C_Address1
          , O.C_Address2
          , O.C_Address3
          , O.C_Address4
          , O.C_Company
          , O.ExternPOKey
          , O.UserDefine05
          , O.[Stop]
          , PD.OrderLineNumber
          , PD.Sku
          , S.ALTSKU
          , ISNULL(ODF.Note1, N'') AS Note1
          , SUM(PD.Qty) AS Quantity
   FROM     PICKDETAIL AS PD WITH (NOLOCK) 
   JOIN     ORDERS AS O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
   JOIN     PickHeader AS PH WITH (NOLOCK) ON O.LoadKey = PH.ExternOrderKey
   JOIN     SKU AS s WITH (NOLOCK) ON s.Sku = PD.Sku AND s.StorerKey = PD.Storerkey
   JOIN     LOC AS L WITH (NOLOCK) ON PD.LOC = L.LOC 
   LEFT OUTER JOIN (SELECT DISTINCT ODF2.StorerKey, ODF2.ParentSKU, ODF2.Orderkey, ODF2.OrderLineNumber, SUBSTRING
                                         ((SELECT   ', ' + ODF1.Note1
                                           FROM      CNWMS.dbo.OrderDetailRef ODF1(NOLOCK)
                                           WHERE   ODF1.StorerKey = ODF2.StorerKey AND ODF1.ParentSKU = ODF2.ParentSKU AND 
                                                           ODF1.Orderkey = ODF2.Orderkey AND 
                                                           ODF1.OrderLineNumber = ODF2.OrderLineNumber
                                           ORDER BY ODF1.Rowref FOR XML PATH('')), 2, 1000) AS Note1
                    FROM OrderDetailRef ODF2(NOLOCK)) AS ODF ON PD.StorerKey = ODF.Storerkey AND 
                    PD.OrderKey = ODF.Orderkey AND PD.OrderLineNumber = ODF.OrderLineNumber AND PD.Sku = ODF.ParentSKU
   WHERE   (O.LoadKey = @c_loadKey AND L.PickZone = 'OOCL')
   GROUP BY PD.OrderKey
          , O.IntermodalVehicle
          , O.[Type]
          , O.ExternOrderKey
          , O.LoadKey
          , PH.PickHeaderKey
          , CASE ISNULL(o.UserDefine10, '') WHEN '' THEN CONVERT(NVARCHAR(10), DeliveryDate, 120) ELSE o.UserDefine10 END
          , O.UserDefine01
          , O.ConsigneeKey
          , O.C_State
          , O.C_City
          , O.C_Zip
          , O.C_Address1 
          , O.C_Address2
          , O.C_Address3
          , O.C_Address4
          , O.C_Company
          , O.ExternPOKey
          , O.UserDefine05
          , O.[Stop]
          , PD.OrderLineNumber
          , PD.Sku
          , s.ALTSKU
          , ODF.Note1
   ORDER BY O.Loadkey, PD.Orderkey, PD.OrderLineNumber

END

GO