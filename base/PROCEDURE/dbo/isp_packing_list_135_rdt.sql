SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Packing_List_135_rdt                           */
/* Creation Date: 2023-06-15                                            */
/* Copyright: LFL                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-22774 - CN - GOLDWIN ECOM Packlist Report               */
/*                                                                      */
/* Called By: r_dw_Packing_List_135_rdt                                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 15-Jun-2023  CSCHONG 1.0   DevOps Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Packing_List_135_rdt] (
   @c_Pickslipno     NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)
   BEGIN
      SELECT @c_Pickslipno = Pickheaderkey
      FROM PICKHEADER (NOLOCK)
      WHERE OrderKey = @c_Pickslipno
   END

   SELECT ORDERS.Orderkey
        , ORDERS.ExternOrderkey
        , sku.altsku
        , SKU.Descr 
        , SKU.Color 
        , SKU.size
        , SUM(ORDERDETAIL.QtyAllocated+Orderdetail.QtyPicked) AS Qty
        , ISNULL(C.Notes,'') AS FooterNotes
   FROM PICKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PICKHEADER.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = ORDERS.StorerKey AND SKU.SKU = ORDERDETAIL.SKU
   --JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber AND
   --                            PICKDETAIL.Sku = ORDERDETAIL.Sku
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME ='GWPKList' AND C.Storerkey = ORDERS.storerkey
   WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno
   GROUP BY ORDERS.Orderkey
          , ORDERS.ExternOrderkey
          , sku.altsku
          , SKU.Descr
          , SKU.Color
          , SKU.size
          , ISNULL(C.Notes,'') 

END

GO