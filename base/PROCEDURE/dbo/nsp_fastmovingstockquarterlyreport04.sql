SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_FastMovingStockQuarterlyReport04               */
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

CREATE PROCEDURE [dbo].[nsp_FastMovingStockQuarterlyReport04]
( @c_storer NVARCHAR(10),
@c_sku_start NVARCHAR(20),
@c_sku_end NVARCHAR(20),
@c_month_year NVARCHAR(7)
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
-- SELECT @c_storer = 'SC', @c_sku_start = '401300', @c_sku_end = '401400', @c_month_year = '03/2001'

DECLARE  @c_month NVARCHAR(2),
@c_year NVARCHAR(4),
@i_month int,
@i_year int,
@i_first_month int,
@i_second_month int,
@i_third_month int
DECLARE  @c_storerkey NVARCHAR(10),	@c_sku NVARCHAR(20), @c_descr NVARCHAR(60), @c_uom NVARCHAR(10)
DECLARE @f_qty1 int, @f_times1 int, @f_qty2 int, @f_times2 int, @f_qty3 int, @f_times3 int
CREATE table #temp(
storerkey NVARCHAR(15) not null,
company NVARCHAR(60) not null,
sku NVARCHAR(20) not null,
descr NVARCHAR(60) null,
uom NVARCHAR(10) null,
qty_month1 int null,
times_month1 int null,
qty_month2 int null,
times_month2 int null,
qty_month3 int null,
times_month3 int null,
month1 int  not null,
month2 int  not null,
month3 int  not null)
SELECT @c_month=substring(@c_month_year,1,2)
SELECT @c_year=substring(@c_month_year,4,7)
SELECT @i_month=cast(@c_month as int)
SELECT @i_year=cast(@c_year as int)
SELECT @i_first_month=@i_month
SELECT @i_second_month=@i_first_month+1
IF @i_second_month=13
BEGIN
   SELECT @i_second_month = 1
END
SELECT @i_third_month = @i_second_month+1
-- initialize all the variables
SELECT @c_storerkey=null, @c_sku=null, @c_descr=null, @f_qty1=0, @f_times1=0, @f_qty2=0, @f_times2=0, @f_qty3=0, @f_times3=0
INSERT INTO #TEMP
--GROUP BY SKU.StorerKey, STORER.Company, ORDERDETAIL.Sku, SKU.DESCR, ORDERDETAIL.UOM
SELECT DISTINCT	@c_storer,
'Company',
ORDERDETAIL.Sku,
'Descr',
ORDERDETAIL.UOM,
CASE month (Orders.AddDate) WHEN @i_first_month THEN IsNull (sum(ORDERDETAIL.ShippedQty), 0) ELSE 0 END,
CASE month (Orders.AddDate) WHEN @i_first_month THEN IsNull (COUNT(ORDERDETAIL.Orderkey), 0) ELSE 0 END,
CASE month (Orders.AddDate) WHEN @i_second_month THEN IsNull (sum(ORDERDETAIL.ShippedQty), 0) ELSE 0 END,
CASE month (Orders.AddDate) WHEN @i_second_month THEN IsNull (COUNT(ORDERDETAIL.Orderkey), 0) ELSE 0 END,
CASE month (Orders.AddDate) WHEN @i_third_month THEN IsNull (sum(ORDERDETAIL.ShippedQty), 0) ELSE 0 END,
CASE month (Orders.AddDate) WHEN @i_third_month THEN IsNull (COUNT(ORDERDETAIL.Orderkey), 0) ELSE 0 END,
   @i_month,
   @i_second_month,
   @i_third_month
   FROM ORDERDETAIL (nolock)
   JOIN ORDERS  (nolock) ON (ORDERS.ORDERKEY = ORDERDETAIL.Orderkey AND ORDERS.Storerkey = ORDERDETAIL.Storerkey)
   WHERE   ORDERDETAIL.Sku between @c_sku_start and @c_sku_end
   AND ORDERDETAIL.Storerkey = 'SC'
   AND ( year(ORDERS.AddDate) = @i_year )
   AND ( month(ORDERS.AddDate) BETWEEN 3 AND 5 )
   GROUP BY ORDERDETAIL.Sku, ORDERDETAIL.UOM, month (Orders.AddDate)
   --	HAVING SUM(ORDERDETAIL.ShippedQty) <> 0
   SELECT
   #TEMP.storerkey,
   Storer.company,
   #TEMP.sku,
   Sku.descr,
   #TEMP.uom,
   Sum (#TEMP.qty_month1),
   Sum (#TEMP.times_month1),
   Sum (#TEMP.qty_month2),
   Sum (#TEMP.times_month2),
   Sum (#TEMP.qty_month3),
   Sum (#TEMP.times_month3),
   #TEMP.month1,
   #TEMP.month2,
   #TEMP.month3
   FROM #TEMP
   JOIN Storer (nolock) ON (#TEMP.StorerKey = Storer.StorerKey)
   JOIN Sku    (nolock) ON (#TEMP.StorerKey = Storer.StorerKey AND #TEMP.Sku = Sku.Sku)
   GROUP BY #TEMP.storerkey, Storer.company, #TEMP.sku, Sku.descr, #TEMP.uom, #TEMP.month1, #TEMP.month2, #TEMP.month3
   DROP TABLE #TEMP

GO