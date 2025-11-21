SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Delivery_Note_MBOL_3                                */  
/* Creation Date: 16-Jun-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-13730 - MYS-DLMY-Modify delivery note on No. of Pallet  */  
/*        :                                                             */  
/* Called By: r_dw_Delivery_Note_MBOL_3                                 */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Delivery_Note_MBOL_3]  
            @c_MBOLkey     NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)
         , @n_TotalPLTID      INT  
  
   SET @n_StartTCnt  = @@TRANCOUNT  
   SET @n_Continue   = 1  
   SET @b_Success    = 1  
   SET @n_Err        = 0  
   SET @c_Errmsg     = '' 
   SET @n_TotalPLTID = 0

   CREATE TABLE #TEMP_ORDERS (
      Orderkey   NVARCHAR(10)
   )

   INSERT INTO #TEMP_ORDERS
   SELECT DISTINCT MD.Orderkey
   FROM MBOLDETAIL MD (NOLOCK) 
   WHERE MD.MBOLKey = @c_MBOLkey

   SELECT @n_TotalPLTID = COUNT(DISTINCT ISNULL(PD.ID,0))
   FROM PICKDETAIL PD (NOLOCK)
   JOIN #TEMP_ORDERS t (NOLOCK) ON t.Orderkey = PD.Orderkey
   WHERE PD.ID > ''

   SELECT OD.SKU AS SKU
       ,  SKU.Descr AS Descr
       ,  SUM(PD.Qty) as QtyPicked
       ,  CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.CaseCnt  ELSE PACK.Qty END AS PACKQty
       ,  CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.PackUOM1  ELSE PACK.PackUOM3 END AS UOM
       ,  LOTT.Lottable02 AS Lottable02
       ,  LOTT.Lottable04 AS Lottable04
       ,  PACK.Pallet AS Pallet
       ,  @n_TotalPLTID AS TotalPLTID
   FROM ORDERS ORD (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.Orderkey = ORD.Orderkey
   JOIN SKU (NOLOCK) ON SKU.SKU = OD.SKU AND SKU.Storerkey = ORD.Storerkey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.SKU = OD.SKU AND PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
   JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = PD.LOT
   JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey
   WHERE (ORD.MbolKey = @c_MBOLkey)
   GROUP BY OD.SKU
         ,  SKU.Descr
         ,  CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.CaseCnt  ELSE PACK.Qty END
         ,  CASE WHEN ISNULL(PACK.PackUOM1, '') <> '' THEN PACK.PackUOM1  ELSE PACK.PackUOM3 END
         ,  LOTT.Lottable02
         ,  LOTT.Lottable04
         ,  PACK.Pallet
   ORDER BY OD.Sku

QUIT_SP:  

END -- procedure

GO