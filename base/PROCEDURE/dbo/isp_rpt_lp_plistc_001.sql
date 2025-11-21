SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTC_001                                 */
/* Creation Date: 20-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18807                                                      */
/*                                                                         */
/* Called By: RPT_LP_PLISTC_001                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 24-Jan-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_LP_PLISTC_001]
      @c_LoadKey        NVARCHAR(10)
    , @c_PreGenRptData  NVARCHAR(10)
 AS
 BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_ExprDate DateTime
   SELECT @d_ExprDate = NULL

   SELECT  ORDERS.Storerkey,
           ORDERS.C_Company,
           ORDERS.LabelPrice,
           ORDERS.OrderKey,
           LoadPlan.LoadKey,
           ORDERS.ExternOrderKey,
           LoadPlan.AddDate,
           QtyToPick = SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.QtyAllocated + ORDERDETAIL.ShippedQty),
           ORDERDETAIL.Sku,
           PACK.PackUOM1,
           PACK.CaseCnt,
           PACK.PackUOM3,
           PACK.PackUOM4,
           PACK.Pallet,
           SKU.DESCR,
           ExprDate = @d_ExprDate,
           [Status] = 'F',
           C_Address1, C_Address2, C_Address3, C_Address4 , C_Zip,
           SKU.StdNetWgt,
           SKU.StdCube,
           Remarks = CONVERT(NVARCHAR(255), ORDERS.Notes),
           showbarcode = CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END
   INTO #RESULT
   FROM LoadPlan (NOLOCK)
   JOIN LoadPlanDetail (NOLOCK) ON ( LoadPlan.LoadKey = LoadPlanDetail.LoadKey )
   JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey )
   JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
   JOIN SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and
                        ( SKU.Sku = ORDERDETAIL.Sku )
   JOIN PACK (NOLOCK) ON   ( SKU.PackKey = PACK.PackKey )
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.storerkey= ORDERS.Storerkey
                                     AND listname = 'REPORTCFG' and code ='SHOWBARCODE'
                                     AND long IN ('RPT_LP_PLISTC_001')
   WHERE ( ( LoadPlan.LoadKey = @c_LoadKey ) )
   GROUP BY ORDERS.Storerkey,
            ORDERS.C_Company,
            ORDERS.LabelPrice,
            ORDERS.OrderKey,
            LoadPlan.LoadKey,
            ORDERS.ExternOrderKey,
            LoadPlan.AddDate,
            ORDERDETAIL.Sku,
            PACK.PackUOM1,
            PACK.CaseCnt,
            PACK.PackUOM3,
            PACK.Qty,
            PACK.PackUOM4,
            PACK.Pallet,
            SKU.DESCR,
            C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, SKU.StdNetWgt, SKU.StdCube,
            CONVERT(NVARCHAR(255), ORDERS.Notes) ,CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END

   SELECT * FROM #RESULT

   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
      DROP TABLE #RESULT

END -- Procedure

GO