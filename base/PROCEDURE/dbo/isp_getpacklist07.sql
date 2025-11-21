SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_GetPackList07                                           */
/* Creation Date: 19-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: r_dw_print_packlist_07                                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 13-JUN-2018 CSCHONG    1.0 WMS-5233 - Add new field (CS01)           */
/* 15-Dec-2018  TLTING01  1.1   Missing nolock                          */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackList07]
            @c_LoadKey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   CREATE TABLE #TMP_BRAND
   (  OrderKey          NVARCHAR(10)   NULL
   ,  Brand             NVARCHAR(60)   NULL
   ,  DistinctBrand     INT  NULL
   )

   CREATE TABLE #TMP_SNCINFO
   (  OrderKey          NVARCHAR(10)   NULL
   ,  OrderLineNumber   NVARCHAR(5)    NULL
   ,  Style             NVARCHAR(20)   NULL
   ,  Color             NVARCHAR(10)   NULL
   ,  Descr             NVARCHAR(60)   NULL
   ,  Busr6             NVARCHAR(30)   NULL
   ,  Price             FLOAT          NULL
   ,  OrderPrice        FLOAT          NULL
   )

   INSERT INTO #TMP_BRAND
   (  OrderKey
   ,  Brand
   ,  DistinctBrand
   )
   SELECT OrderKey  = ORDERDETAIL.OrderKey
         ,ItemClass    = ISNULL(MIN(RTRIM(CL.Description)),'')
         ,DistinctBrand= COUNT(DISTINCT ISNULL(RTRIM(CL.Description),''))
   FROM ORDERDETAIL WITH (NOLOCK)
   JOIN SKU           WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                    AND(ORDERDETAIL.Sku = SKU.Sku)
   LEFT JOIN CODELKUP CL   WITH (NOLOCK) ON (CL.ListName = 'ItemClass')
                                         AND(CL.Code = SKU.ItemClass)
   WHERE ORDERDETAIL.Loadkey = @c_LoadKey
   GROUP BY ORDERDETAIL.Orderkey

   UPDATE #TMP_BRAND
      SET Brand = CASE WHEN #TMP_BRAND.DistinctBrand > 1 THEN 'Mixed Brand' ELSE #TMP_BRAND.Brand END

   INSERT INTO #TMP_SNCINFO
   (     Orderkey
   ,     OrderLineNumber
   ,     Style
   ,     Color
   ,     Descr
   ,     Busr6
   ,     Price
   ,     OrderPrice
   )
   SELECT Orderkey
   ,      MIN(OrderLineNumber)
   ,      ISNULL(RTRIM(SKU.Style),'')
   ,      ISNULL(RTRIM(SKU.Color),'')
   ,      ''
   ,      ''
   ,      0.00
   ,      0.00
   FROM ORDERDETAIL WITH (NOLOCK)
   JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                  AND(ORDERDETAIL.Sku = SKU.Sku)
   WHERE LoadKey = @c_Loadkey
   GROUP BY Orderkey
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')

   UPDATE #TMP_SNCINFO
      SET  Descr = SKU.Descr
          ,Busr6 = ISNULL(RTRIM(SKU.Busr6),'')
          ,Price      = CASE WHEN ISNULL(ORDERDETAIL.UnitPrice,0) = 0
                             THEN ISNULL(SKU.Price,0)
                             ELSE ISNULL(ORDERDETAIL.UnitPrice,0)
                             END
          ,OrderPrice = CASE WHEN ISNULL(ORDERDETAIL.ExtendedPrice,0) = 0
                             THEN ISNULL(SKU.StdOrderCost,0)
                             ELSE ISNULL(ORDERDETAIL.ExtendedPrice,0)
                             END
   FROM #TMP_SNCINFO
   JOIN ORDERDETAIL (NOLOCK) ON (#TMP_SNCINFO.Orderkey = ORDERDETAIL.Orderkey)
                    AND(#TMP_SNCINFO.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                          AND(ORDERDETAIL.Sku = SKU.Sku)


   SELECT CustomerGroupName = ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,Brand             = #TMP_BRAND.Brand
         ,ORDERS.Orderkey
         ,C_Company         = ISNULL(RTRIM(ORDERS.C_Company),'')
         ,C_Address1        = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,ORDERS.Deliverydate
         ,ExternOrderkey    = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,PickSlipNo        = ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,Buyer             = ISNULL(RTRIM(CSG.SUSR1),'')
         ,ORDERDETAIL.Storerkey
         --,ORDERDETAIL.Sku
         ,Descr        = ISNULL(MAX(RTRIM(#TMP_SNCINFO.Descr)),'')
         ,Style        = ISNULL(RTRIM(SKU.Style),'')
         ,Color        = ISNULL(RTRIM(SKU.Color),'')
         ,StyleColor   = ISNULL(RTRIM(SKU.Style),'') + '-'
                       + ISNULL(RTRIM(SKU.Color),'')
         ,BUSR6        = ISNULL(MAX(#TMP_SNCINFO.Busr6),'')
         ,Qty          = ISNULL(SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),0)
         ,Price        = ISNULL(MAX(#TMP_SNCINFO.Price),0.00)
         ,OrderPrice   = ISNULL(MAX(#TMP_SNCINFO.OrderPrice),0.00)
			,loadkey      = ORDERS.LoadKey                              --(CS01)
   FROM ORDERS        WITH (NOLOCK)
   JOIN ORDERDETAIL   WITH (NOLOCK) ON (ORDERS.Orderkey  = ORDERDETAIL.Orderkey)
   JOIN PICKHEADER    WITH (NOLOCK) ON (ORDERS.Orderkey  = PICKHEADER.Orderkey)
   JOIN STORER        WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN STORER CSG    WITH (NOLOCK) ON (ORDERS.Consigneekey = CSG.Storerkey)
   JOIN SKU           WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                    AND(ORDERDETAIL.Sku = SKU.Sku)
   JOIN #TMP_BRAND         ON (ORDERDETAIL.Orderkey = #TMP_BRAND.Orderkey)
   LEFT JOIN #TMP_SNCINFO  ON (#TMP_SNCINFO.Orderkey   = ORDERDETAIL.Orderkey)
                           AND(#TMP_SNCINFO.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   WHERE ORDERS.Loadkey = @c_LoadKey
   GROUP BY ISNULL(RTRIM(STORER.CustomerGroupName),'')
         ,  #TMP_BRAND.Brand
         ,  ORDERS.Orderkey
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,  ORDERS.Deliverydate
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,  ISNULL(RTRIM(CSG.SUSR1),'')
         ,  ORDERDETAIL.Storerkey
         --,  ORDERDETAIL.Sku
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
         ,  ORDERS.LoadKey                    --CS01
         --,  ISNULL(SKU.Price,0)
         --,  ISNULL(ORDERDETAIL.UnitPrice,0)
         --,  ISNULL(SKU.StdOrderCost,0)
         --,  ISNULL(ORDERDETAIL.ExtendedPrice,0)
QUIT_SP:

END -- procedure

GO