SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Daily_Orders                                   */
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
/************************************************************************/

CREATE PROC [dbo].[nsp_Daily_Orders] AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @orderdate NVARCHAR(10),
   @shipped int,
   @picked int,
   @normal int

   SELECT DISTINCT orderdate = CONVERT(CHAR(10), ORDERS.orderdate, 101),
   ORDERS.orderkey,
   ORDERS.storerkey,
   qtyordered = SUM(ORDERDETAIL.originalqty),
   shippedqty = SUM(ORDERDETAIL.shippedqty),
   ORDERS.status,
   total_shipped = 0,
   total_picked = 0,
   total_outstanding = 0
   INTO #TEMP
   FROM ORDERS INNER JOIN ORDERDETAIL
   ON ORDERS.orderkey = ORDERDETAIL.orderkey
   WHERE ( ORDERS.orderdate >= '18/12/2000' )
   AND ( ORDERS.orderdate < dateadd(day, 1, '18/12/2000' ) )
   GROUP BY CONVERT(CHAR(10), ORDERS.orderdate, 101),
   ORDERS.storerkey,
   ORDERS.orderkey,
   ORDERS.status

   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT DISTINCT orderdate FROM #TEMP

   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @orderdate
   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @shipped = COALESCE(SUM(shippedqty), 0)
      FROM #TEMP
      WHERE orderdate = @orderdate
      AND status = '9'
      GROUP BY orderdate
      IF @shipped IS NULL SELECT @shipped = 0

      SELECT @picked = SUM(qtyordered)
      FROM #TEMP
      WHERE orderdate = @orderdate
      AND status = '5'
      GROUP BY orderdate
      IF @picked IS NULL SELECT @picked = 0

      SELECT @normal = COALESCE(SUM(qtyordered), 0)
      FROM #TEMP
      WHERE orderdate = @orderdate
      AND status NOT IN ('9', '5')
      GROUP BY orderdate
      IF @normal IS NULL SELECT @normal = 0

      UPDATE #TEMP
      SET total_shipped = @shipped, total_picked = @picked, total_outstanding = @normal
      WHERE orderdate = @orderdate
      FETCH NEXT FROM cur_1 INTO @orderdate
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT * FROM #TEMP
   DROP TABLE #TEMP
END

GO