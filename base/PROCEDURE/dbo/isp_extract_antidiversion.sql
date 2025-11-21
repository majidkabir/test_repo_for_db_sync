SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Extract_AntiDiversion                             	   */
/* CreatiON Date: 18-Nov-2004                                           */
/* CopyRIGHT: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Report to extract Anti-DiversiON Code (IDSMY-LOREAL)        */
/*                                                                      */
/* Input Parameters:    @c_storerkey, -- Storerkey                      */
/*                      @c_division,  -- DivisiON                       */
/*                      @n_day,       -- Day                            */
/*                      @n_month,     -- MONth                          */
/*                      @n_year       -- Year                           */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: dw r_dw_extract_antidiversion (RptID=IDSM48A)             */
/*                                                                      */
/* PVCS VersiON: 1.0		                                                */
/*                                                                      */
/* VersiON: 5.4                                                         */
/*                                                                      */
/* Data ModIFicatiONs:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 18-Nov-2004  June          Bug fixes(IDSMY) - chg dateline var length*/
/* 04-Jul-2005  Shong         Add Drop object                           */
/* 25-Jul-2005  MaryVong      SOS38346 - request by IDSMY-LOREAL        */
/*                            1) Changed from While Loop to CURSOR      */
/*                            2) No more using report module but changed*/
/*                               to DTS interface to extract records    */
/*                            3) Add in Day as retrieval parameters     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_Extract_AntiDiversion]
	@c_storerkey   NVARCHAR(18),
	@c_division    NVARCHAR(18),
   @n_day         int,        -- SOS38346
	@n_month       int,
	@n_year        int
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @c_orderkey NVARCHAR(10),
				@c_prevorderkey NVARCHAR(10),	-- SOS38346
				@d_shipdate datetime,
				@c_serialno NVARCHAR(18),		-- SOS38346
				@c_dateline NVARCHAR(10),
				@c_customer NVARCHAR(18),
				@c_hourline NVARCHAR(10),
				@b_debug int					-- SOS38346

	CREATE TABLE #temp_antidiversion (
		adcode NVARCHAR(18)
	)

	SELECT @b_debug = 0

	SELECT @c_orderkey = ''
	SELECT @c_prevorderkey = ''
	-- SOS38346 Change while loop to CURSOR
-- 	while (1=1)
-- 	BEGIN
	DECLARE ANTI_DIVERSION_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
		SELECT O.Orderkey, M.EditDate, S.SerialNo
		FROM MBOL M (NOLOCK) 
		JOIN ORDERS O (NOLOCK) ON (M.MBOLkey = O.MBOLkey)
		JOIN SERIALNO S (NOLOCK) ON (S.Orderkey = O.Orderkey)
		JOIN SKU (NOLOCK) ON (S.Storerkey = SKU.Storerkey
									AND S.Sku = SKU.Sku)
		WHERE O.Storerkey = @c_storerkey
			AND DATEPART(DAY, M.EditDate) = @n_day
			AND DATEPART(MONTH, M.EditDate) = @n_month
			AND DATEPART(YEAR, M.EditDate) = @n_year
			AND SKU.SUSR3 = @c_division
		ORDER BY O.Orderkey

	OPEN ANTI_DIVERSION_CUR

	FETCH NEXT FROM ANTI_DIVERSION_CUR INTO @c_orderkey, @d_shipdate, @c_serialno

	WHILE @@FETCH_STATUS <> -1
	BEGIN
-- 		SELECT @c_orderkey = min(O.orderkey),
-- 				@d_shipdate = min(M.editdate)
-- 		FROM mbol m (NOLOCK) JOIN orders o (NOLOCK)
-- 			ON M.mbolkey = O.mbolkey
-- 		WHERE O.storerkey = @c_storerkey
-- 			AND DATEPART(day, M.editdate) = @n_day
-- 			AND DATEPART(mONth, M.editdate) = @n_month
-- 			AND DATEPART(year, M.editdate) = @n_year
-- 			AND O.orderkey > @c_orderkey

		IF @b_debug = 1
		BEGIN
			SELECT @c_orderkey '@c_orderkey', @c_prevorderkey '@c_prevorderkey', 
						@d_shipdate '@d_shipdate'
		END

-- 		IF isnull(@c_orderkey, '') = ''
-- 			break

-- 		IF not exists (SELECT S.serialno
-- 							FROM serialno s (NOLOCK) JOIN sku (NOLOCK)
-- 								ON S.storerkey = sku.storerkey
-- 									AND S.sku = sku.sku
-- 							WHERE S.orderkey = @c_orderkey
-- 								AND sku.susr3 = @c_division)
-- 			continue

		IF @c_orderkey <> @c_prevorderkey 
		BEGIN 
			SELECT @c_dateline = 'A' +  -- fix as A
										RIGHT(CONVERT(char(4), @n_year), 2) + -- year 2-digit
										RIGHT('00' + dbo.fnc_RTrim(CONVERT(char(2), @n_month)), 2) + -- month 2-digit
										RIGHT('00' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(DAY, @d_shipdate))), 2) + -- day
										'298'
	
			INSERT #temp_antidiversion VALUES (@c_dateline)
	
			SELECT @c_customer = S.vat
			FROM ORDERS O (NOLOCK) JOIN STORER S (NOLOCK)
				ON O.Consigneekey = S.Storerkey
			WHERE O.orderkey = @c_orderkey
	
			IF dbo.fnc_RTrim(@c_customer) = '' OR dbo.fnc_RTrim(@c_customer) IS NULL
				SELECT @c_customer = 'XXXXXXXXXX'
	
			INSERT #temp_antidiversion VALUES (@c_customer)
	
			SELECT @c_hourline = 'S' +
										RIGHT('00' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(HOUR, @d_shipdate))), 2) + -- hour
										RIGHT('00' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(MINUTE, @d_shipdate))), 2) + -- min
										RIGHT('00' + dbo.fnc_RTrim(CONVERT(char(2), DATEPART(SECOND, @d_shipdate))), 2) + -- sec
										'XXX'
	
			INSERT #temp_antidiversion VALUES (@c_hourline)
		END -- IF @c_orderkey <> @c_prevorderkey

		INSERT #temp_antidiversion	
			SELECT @c_serialno	
-- 			SELECT S.serialno
-- 			FROM serialno s (NOLOCK) JOIN sku (NOLOCK)
-- 				ON S.storerkey = sku.storerkey
-- 					AND S.sku = sku.sku
-- 			WHERE S.orderkey = @c_orderkey
-- 				AND sku.susr3 = @c_division

		SELECT @c_prevorderkey = @c_orderkey

		FETCH NEXT FROM ANTI_DIVERSION_CUR INTO @c_orderkey, @d_shipdate, @c_serialno
	END -- WHILE @@FETCH_STATUS <> -1

	CLOSE ANTI_DIVERSION_CUR
	DEALLOCATE ANTI_DIVERSION_CUR
--	END

	SELECT * FROM #temp_antidiversion
	DROP TABLE #temp_antidiversion
END

GO