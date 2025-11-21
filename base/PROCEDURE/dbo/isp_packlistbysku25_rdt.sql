SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku25_rdt                                 */
/* Creation Date: 04-APR-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: MINGLE                                                   */
/*                                                                      */
/* Purpose: WMS-19345 - CN Loreal Packing list for activities_NEW       */
/*        :                                                             */
/* Called By: r_dw_packing_list_By_Sku25_rdt                            */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver   Purposes                                 */
/* 04-APR-2022  MINGLE   1.0   Devops Scripts Combine                   */
/* 25-Nov-2022  WLChooi  1.1   WMS-21248 - Group Qty by SKU (WL01)      */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku25_rdt] @c_Loadkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt  INT
         , @n_Continue   INT
         , @n_MaxLineno  INT
         , @n_MaxRec     INT
         , @n_CurrentRec INT
         , @n_Maxrecgrp  INT

   SET @n_StartTCnt = @@TRANCOUNT

   --SET @n_MaxLineno = 10     

   CREATE TABLE #TMP_PICKLISTBYSKU25RDT
   (
      ohudf03        NVARCHAR(20)
    , ORDDate        DATETIME
    , loadkey        NVARCHAR(20)
    , SDescr         NVARCHAR(80)
    , qty            INT
    , SKU            NVARCHAR(20)
    , altSKU         NVARCHAR(20)
    , ttlqty         INT
    , st_notes1      NVARCHAR(4000)
    , st_BAdd3       NVARCHAR(45)
    , st_BAdd4       NVARCHAR(45)
    , OrderCnt       INT
    , Externorderkey NVARCHAR(20)
    , Orderkey       NVARCHAR(20)
   )

   INSERT INTO #TMP_PICKLISTBYSKU25RDT (ohudf03, ORDDate, loadkey, SDescr, qty, SKU, altSKU, ttlqty, st_notes1
                                      , st_BAdd3, st_BAdd4, OrderCnt, Externorderkey, Orderkey)
   SELECT OHUDF03 = ISNULL(RTRIM(OH.UserDefine03), '')
        , ORDDate = CONVERT(VARCHAR, OH.OrderDate, 20)
        --, OH.OrderDate  
        , OH.LoadKey
        , SDescr = ISNULL(RTRIM(SKU.DESCR), '')
        --, SDescr= MAX(ISNULL(RTRIM(sku.descr),''))  
        , Qty = 0   --ISNULL((PD.Qty), 0)   --WL01
        --, SKU = RTRIM(OD.sku)  
        , SKU = MAX(RTRIM(OD.Sku))
        --, AltSKU = SKU.ALTSKU  
        , AltSKU = MAX(SKU.ALTSKU)
        , ttlqty = ISNULL(SUM(PD.Qty), 0)
        , ODNotst_notes1es2 = ISNULL(RTRIM(ST.Notes1), '')
        , st_BAdd3 = ISNULL(RTRIM(ST.B_Address3), '')
        , st_BAdd4 = ISNULL(RTRIM(ST.B_Address4), '')
        , OrderCnt = (  SELECT OrderCnt
                        FROM LoadPlan (NOLOCK)
                        WHERE LoadKey = @c_Loadkey)
        , OH.ExternOrderKey
        , OH.OrderKey
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (   OD.OrderKey = PD.OrderKey
                                       AND OD.OrderLineNumber = PD.OrderLineNumber
                                       AND OD.Sku = PD.Sku)
   JOIN SKU SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.StorerKey) AND (PD.Sku = SKU.Sku)
   LEFT JOIN LoadPlan LP WITH (NOLOCK) ON LP.LoadKey = OH.LoadKey
   --LEFT JOIN dbo.STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.ConsigneeKey AND ST.type='1'  
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey AND ST.type = '1'
   --WHERE PH.PickSlipNo = @c_PickSlipNo  
   WHERE OH.LoadKey = @c_Loadkey
   GROUP BY ISNULL(RTRIM(OH.UserDefine03), '')
          , OH.OrderDate
          , OH.LoadKey
          , ISNULL(RTRIM(SKU.DESCR), '')
          --, ISNULL((PD.Qty), 0)   --WL01
          --,  RTRIM(OD.sku)  
          --,  SKU.ALTSKU  
          , ISNULL(RTRIM(ST.Notes1), '')
          , ISNULL(RTRIM(ST.B_Address3), '')
          , ISNULL(RTRIM(ST.B_Address4), '')
          , OH.ExternOrderKey
          , OH.OrderKey

   --SET @n_Maxrecgrp = 1  
   --SET @n_MaxRec = 1  

   SELECT ohudf03
        , ORDDate
        , loadkey
        , SDescr
        , qty
        , SKU
        , altSKU
        , ttlqty
        , st_notes1
        , st_BAdd3
        , st_BAdd4
        , OrderCnt
        , Externorderkey
        , Orderkey
   FROM #TMP_PICKLISTBYSKU25RDT
   ORDER BY Orderkey
          , SKU

END -- procedure  

GO