SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_82_rdt                            */
/* Creation Date: 2020-09-02                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-14884 - [CN] Lacoste_Ecom Packing List_CR               */
/*                                                                      */
/* Called By: r_dw_Packing_List_82_rdt                                  */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_82_rdt] (
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

   SELECT ORDERS.M_Company
        , ORDERS.C_contact1
        , ORDERS.DeliveryNote
        , ORDERS.C_zip
        , LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + 
          LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,''))) AS C_Addresses
        , ORDERS.Orderkey
        , ORDERS.ExternOrderkey
        , GETDATE() AS TodayDate
        , ORDERDETAIL.SKU
        , SKU.Descr
        , SKU.Color
        , SKU.size
        , SUM(PICKDETAIL.qty) AS Qty
   FROM PICKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PICKHEADER.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = ORDERS.StorerKey AND SKU.SKU = ORDERDETAIL.SKU
   JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber AND
                               PICKDETAIL.Sku = ORDERDETAIL.Sku
   WHERE PICKHEADER.Pickheaderkey = @c_Pickslipno
   GROUP BY ORDERS.M_Company
          , ORDERS.C_contact1
          , ORDERS.DeliveryNote
          , ORDERS.C_zip
          , LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) + 
            LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address3,''))) + LTRIM(RTRIM(ISNULL(ORDERS.C_Address4,'')))
          , ORDERS.Orderkey
          , ORDERS.ExternOrderkey
          , ORDERS.M_Company
          , ORDERDETAIL.SKU
          , SKU.Descr
          , SKU.Color
          , SKU.size

END     

GO