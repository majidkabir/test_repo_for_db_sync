SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ShipmentSummary                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2018-12-15   TLTING01 1.1  Missing nolock                            */
/************************************************************************/

CREATE PROC [dbo].[nsp_ShipmentSummary] (
@c_orderkey_start NVARCHAR(10),
@c_orderkey_end   NVARCHAR(10),
@c_storerkey_start  NVARCHAR(18),
@c_storerkey_end    NVARCHAR(18),
@d_date_start	    datetime,
@d_date_end	    datetime
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT STORER.company,
   ORDERS.orderkey,
   ORDERS.externorderkey,
   ORDERS.consigneekey,
   ORDERS.c_company,
   shipdate = CONVERT(CHAR(10), ORDERDETAIL.editdate, 103),
   totalqty = SUM(ORDERDETAIL.shippedqty),
   totalpallets = 0
   INTO #RESULT
   FROM ORDERS (NOLOCK) INNER JOIN ORDERDETAIL (NOLOCK)
   ON ORDERS.orderkey = ORDERDETAIL.orderkey
   INNER JOIN STORER (NOLOCK)
   ON ORDERS.storerkey = STORER.storerkey
   WHERE ORDERS.orderkey BETWEEN @c_orderkey_start AND @c_orderkey_end
   AND ORDERS.storerkey BETWEEN @c_storerkey_start AND @c_storerkey_end
   AND ORDERDETAIL.editdate >= @d_date_start
   AND ORDERDETAIL.editdate <= @d_date_end
   GROUP BY STORER.company,
   ORDERS.orderkey,
   ORDERS.externorderkey,
   ORDERS.consigneekey,
   ORDERS.c_company,
   CONVERT(CHAR(10), ORDERDETAIL.editdate, 103)

   DECLARE @c_orderkey NVARCHAR(10),
   @n_totalpallet int,
   @c_orderlinenumber NVARCHAR(5),
   @c_sku NVARCHAR(20),
   @n_pallet int

   DECLARE cur_1 CURSOR fast_forward read_only
   FOR
   SELECT orderkey FROM #RESULT

   OPEN cur_1
   FETCH next FROM cur_1 INTO @c_orderkey
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @n_totalpallet = 0
      --TLTING01
      DECLARE cur_2 CURSOR LOCAL fast_forward read_only
      FOR
      SELECT orderlinenumber, sku from ORDERDETAIL (NOLOCK) WHERE orderkey = @c_orderkey

      OPEN cur_2
      FETCH next FROM cur_2 INTO @c_orderlinenumber, @c_sku
      WHILE (@@fetch_status <> -1)
      BEGIN
         SELECT @n_pallet = PACK.pallet
         FROM SKU (NOLOCK)
         INNER JOIN PACK (NOLOCK) ON SKU.packkey = PACK.packkey
         WHERE sku = @c_sku

         IF @n_pallet <> 0
         BEGIN
            SELECT @n_totalpallet = @n_totalpallet + (shippedqty / @n_pallet)
            FROM ORDERDETAIL (NOLOCK)
            WHERE orderkey = @c_orderkey
            AND orderlinenumber = @c_orderlinenumber
            AND sku = @c_sku
         END

         FETCH NEXT FROM cur_2 INTO @c_orderlinenumber, @c_sku
      END
      CLOSE cur_2
      DEALLOCATE cur_2

      UPDATE #RESULT
      SET totalpallets = @n_totalpallet
      WHERE orderkey = @c_orderkey

      FETCH NEXT FROM cur_1 INTO @c_orderkey
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT * FROM #RESULT
   DROP TABLE #RESULT
END

GO