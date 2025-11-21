SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_sales_order_process                            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCedure [dbo].[nsp_sales_order_process] (
@Storer_start    NVARCHAR(15),
@Storer_end      NVARCHAR(15),
@Date_start      NVARCHAR(10),
@Date_end        NVARCHAR(10),
@Orderkey_start  NVARCHAR(10),
@Orderkey_end    NVARCHAR(10),
@CustOrder_start NVARCHAR(20),
@CustOrder_end   NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT ORDERS.PRIORITY, CODELKUP.Description
   INTO #RESULT
   FROM ORDERS (NOLOCK)
   JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY )
   JOIN STORER (NOLOCK) ON ( STORER.STORERKEY = ORDERS.STORERKEY )
   JOIN SKU (NOLOCK) ON ( ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku )
   JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PackKey )
   LEFT OUTER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Code = ORDERS.Priority AND
   CODELKUP.ListName = 'ORDRPRIOR')
   WHERE ORDERS.STORERKEY BETWEEN @Storer_start AND @Storer_end
   AND   ORDERS.ADDDATE BETWEEN CONVERT(datetime, @Date_start) AND DATEADD( day, 1, CONVERT(datetime, @Date_end) )
   AND   ORDERS.ORDERKEY BETWEEN @Orderkey_start AND @Orderkey_end
   AND   ORDERS.ExternOrderKey BETWEEN @CustOrder_start AND @CustOrder_end
   GROUP BY ORDERS.ADDDATE, ORDERS.DELIVERYDATE, ORDERS.BUYERPO,
   ORDERS.EXTERNORDERKEY, ORDERS.C_COMPANY, ORDERS.PRIORITY, ORDERS.ORDERKEY, ORDERS.deliverynote, ORDERS.rdd,
   STORER.COMPANY, ORDERS.Type, ORDERS.ContainerType, ORDERS.SequenceNo, CODELKUP.Description


   SELECT Priority, Description, count(*) as Cnt
   FROM #RESULT
   GROUP BY Priority, description

   DROP TABLE #RESULT

END

GO