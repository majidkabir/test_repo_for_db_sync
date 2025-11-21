SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_FastMovingStockQuarterlyReport                 */
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
/* 02-JUL-2007	 LEONG			SOS#80114 Modification:							*/
/*										1) New Calculation to calculate Quarterly */
/*										2) Verification for those Quarter that    */
/*											overlap to next year							*/
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_FastMovingStockQuarterlyReport]
(@c_storer NVARCHAR(10), 
 @c_sku_start NVARCHAR(20),
 @c_sku_end NVARCHAR(20), 
 @c_month_year NVARCHAR(7)
)

AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE  @c_month NVARCHAR(2),
			@c_year NVARCHAR(4),
			@i_month int,
			@i_year int,
			@i_first_month int,
			@i_second_month int,
			@i_third_month int,
			-- SOS#80114
			@i_last_month int,
			@i_second_year int,
			@c_first_month NVARCHAR(2),
			@c_last_month NVARCHAR(2),
			@c_start_date NVARCHAR(10),
			@c_end_date NVARCHAR(10),
			@dt_start_date datetime,
			@dt_end_date datetime

CREATE table 	#temp(
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

-- SOS#80114 Initialize variable
SELECT 	@i_month = 0,
			@i_first_month = 0,
			@i_second_month = 0,
			@i_third_month = 0,
			@i_last_month = 0,
			@i_year = 0,
			@i_second_year = 0

SELECT @c_month=substring(@c_month_year,1,2)
SELECT @c_year=substring(@c_month_year,4,7)
SELECT @i_month=cast(@c_month as int)
SELECT @i_year=cast(@c_year as int)

SELECT @i_first_month = @i_month

-- SOS#80114 Start Modify---------------------------------------------------------

SELECT @i_last_month = @i_month + 3 -- calculate the 4th month

IF @i_last_month <= 12 -- If the selected months range are within a year
	BEGIN
		SELECT @i_second_month = @i_month + 1
		SELECT @i_third_month  = @i_month + 2
		SELECT @i_second_year  = @i_year
END	

IF @i_last_month > 12 -- If the selected months range are overlap within two year
	BEGIN
		SELECT @i_second_month = CASE WHEN @i_month + 1 > 12 -- when @i_second_month = 13
												THEN @i_month + 1 - 12 
												ELSE @i_month + 1 
										 		END
		
		SELECT @i_third_month  = CASE WHEN @i_month + 2 > 12 -- when @i_third_month = 14
												THEN @i_month + 2 - 12 
												ELSE @i_month + 2
										 		END
		
		SELECT @i_last_month = @i_last_month - 12
		
		SELECT @i_second_year = @i_year + 1 -- The year increase by 1 for next year

END

-- Convert month to string
SELECT @c_first_month = RIGHT( REPLICATE('0', 2) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(2),@i_first_month))), 2)
SELECT @c_last_month  = RIGHT( REPLICATE('0', 2) + dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(char(2),@i_last_month))), 2)

-- Concate year, month, day
SELECT @c_start_date = CONVERT(char(4),@i_year) + @c_first_month + '01'
SELECT @c_end_date = CONVERT(char(4),@i_second_year) + @c_last_month + '01'

-- Convert @c_start_date and @c_end_date into datetime format
SELECT @dt_start_date = CONVERT (datetime, @c_start_date, 112)
SELECT @dt_end_date = CONVERT (datetime, @c_end_date, 112)

-- SOS#80114 End Modify---------------------------------------------------------

INSERT INTO #TEMP 
SELECT DISTINCT @c_storer,
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
   FROM  ORDERDETAIL (nolock)
   	   JOIN ORDERS  (nolock) ON (ORDERS.ORDERKEY = ORDERDETAIL.Orderkey AND ORDERS.Storerkey = ORDERDETAIL.Storerkey)
   WHERE ORDERDETAIL.Sku between @c_sku_start and @c_sku_end
   AND 	ORDERDETAIL.Storerkey = @c_storer --'SC' -- SOS#80114
		   -- AND ( year(ORDERS.AddDate) = @i_year ) -- SOS#80114
		   -- AND ( month(ORDERS.AddDate) BETWEEN 3 AND 5 ) -- SOS#80114
   AND 	ORDERS.AddDate >= @dt_start_date -- SOS#80114 -- Set date range using AddDate
   AND 	ORDERS.AddDate <  @dt_end_date -- SOS#80114 -- Set date range using AddDate
   GROUP BY ORDERDETAIL.Sku, ORDERDETAIL.UOM, month (Orders.AddDate)

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
	ORDER BY #TEMP.Sku ASC

   DROP TABLE #TEMP

GO