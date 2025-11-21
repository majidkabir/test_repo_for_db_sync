SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_StockOut_Loadplan01                                 */
/* Creation Date: 24-Jul-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14436 - Convert to call SP                              */
/*        :                                                             */
/* Called By: r_stockout_loadplan01                                     */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-07-24  WLChooi  1.1   WMS-14436 - Modify column based on        */
/*                            ReportCFG (WL01)                          */
/************************************************************************/
CREATE PROC [dbo].[isp_StockOut_Loadplan01]
           @c_Loadkey         NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT = 1
         , @n_Err             INT = 0
         , @c_ErrMsg          NVARCHAR(255) = ''
         , @b_success         INT = 1

   SELECT ORDERDETAIL.Sku,   
          ORDERS.StorerKey,   
          ORDERS.ExternOrderKey,   
          ORDERDETAIL.OrderLineNumber,   
          ORDERDETAIL.OpenQty,   
          ORDERDETAIL.QtyAllocated,   
          ORDERDETAIL.QtyPicked,   
          CASE WHEN ISNULL(CL2.Short,'N') = 'Y' THEN ORDERS.DeliveryDate ELSE ORDERS.OrderDate END AS OrderDate,   --WL01    
          (ORDERDETAIL.OpenQty - (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked)) shortages,   
          CASE WHEN ISNULL(CL1.Short,'N') = 'Y' THEN ORDERS.Consigneekey ELSE ORDERS.OrderKey END AS OrderKey,     --WL01 	
          ORDERS.B_Company,
          ORDERDETAIL.Lottable02,		/* SOS22748 */
          ORDERDETAIL.Lottable04,		/* SOS22748 */	 
          SKU.Descr,			            /* SOS33699 */ 
          ORDERDETAIL.UOM,			      /* SOS117891*/ 
          LOADPLAN.LoadKey,			   /* SOS117891*/ 
          ORDERS.Notes,			         /* SOS117891*/ 
          ISNULL(CL1.Short,'N') AS ShowConsigneekey   --WL01
   FROM ORDERS WITH (NOLOCK)
   JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )   
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON ( LOADPLANDETAIL.OrderKey = ORDERS.OrderKey )
   JOIN LOADPLAN WITH (NOLOCK) ON ( LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
   JOIN SKU WITH (NOLOCK) ON ( ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey) 
   --WL01 START
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON ( CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowConsigneeKey' AND 
                                             CL1.Storerkey = ORDERS.Storerkey AND
                                             CL1.Long = 'r_stockout_loadplan01' )
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON ( CL2.Listname = 'REPORTCFG' AND CL2.Code = 'ShowDeliveryDate' AND 
                                             CL2.Storerkey = ORDERS.Storerkey AND
                                             CL2.Long = 'r_stockout_loadplan01' )
   --WL01 END
   WHERE ( 0 < (ORDERDETAIL.OpenQty - (ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked))) AND
         ( LOADPLAN.LoadKey = @c_Loadkey )


QUIT_SP:
END -- procedure

GO