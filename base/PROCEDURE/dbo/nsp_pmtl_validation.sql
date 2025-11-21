SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_PMTL_Validation                                */
/* Creation Date: 07-Nov-2012                                           */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 07-Nov-2012  KHLim  1.1   DM integrity - Update EditDate  (KH01)     */
/************************************************************************/
CREATE PROC [dbo].[nsp_PMTL_Validation] 
AS  
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	DECLARE @n_continue int
	
	DECLARE @c_Externorderkey  NVARCHAR(30),
	@b_success  int ,
	@n_err      int ,
	@c_errmsg   NVARCHAR(225), 
	@d_DeliveryDate datetime,
	@d_finaldeldate datetime, 
	@c_Address4 NVARCHAR(45),
	@c_ZipCodefrom NVARCHAR(15),
	@c_Consigneekey NVARCHAR(15),
	@c_storerkey NVARCHAR(15),
	@c_Orderkey NVARCHAR(10) ,
	@c_Route NVARCHAR(10) ,
	@d_deldate datetime,
	@t_deltime datetime,
	@ll_DDate int,
	@c_day NVARCHAR(2),
	@c_month NVARCHAR(2),
	@c_year NVARCHAR(4),
	@c_time NVARCHAR(6),
	@c_adddate datetime,
	@c_sectionkey NVARCHAR(10) ,
	@c_prevOrderkey NVARCHAR(10)    
	
	SELECT @n_continue = 1 , @b_success = 1
	SELECT @ll_DDate = 0
	
	SELECT @c_orderkey = SPACE(10)
	
	WHILE 1=1
	BEGIN -- 01
		SET ROWCOUNT 1

		SELECT @c_Orderkey = ORDERS.Orderkey
		FROM   ORDERS (NOLOCK)
		WHERE  ORDERS.Orderkey > @c_Orderkey
		AND  ORDERS.Archivecop = '3'
		AND  ORDERS.Storerkey = 'PMTL'
		ORDER BY ORDERS.Orderkey
		-- 
		-- print 'test'
		-- select @c_orderkey
		
		IF (dbo.fnc_RTrim(@c_Orderkey) IS NULL OR dbo.fnc_RTrim(@c_Orderkey) = '') OR (@c_prevOrderkey = @c_orderkey)
		BREAK
		
		SELECT @c_prevorderkey = @c_orderkey
	
		SELECT @c_Externorderkey = ORDERS.ExternOrderkey,
		@c_Storerkey = ORDERS.Storerkey,
		@c_Consigneekey = ORDERS.Consigneekey,
		@d_DeliveryDate = ORDERS.DeliveryDate,
		@c_adddate = ORDERS.AddDate    
		FROM  ORDERS (NOLOCK)
		WHERE Orderkey = @c_Orderkey
	
		-- print 'test1'
		-- select @c_Externorderkey '@c_Externorderkey', @c_Storerkey '@c_Storerkey', @c_Consigneekey '@c_Consigneekey', @d_DeliveryDate '@d_DeliveryDate', @c_adddate '@c_adddate'
		
		IF @@ROWCOUNT = 0
			BREAK           

		SET ROWCOUNT 0
		
		SELECT @c_Address4 = STORER.Address4
		FROM   STORER (NOLOCK)
		WHERE  STORER.Storerkey = @c_Consigneekey
		
		-- print 'test2'
		-- select @c_Address4
		
		SELECT @c_ZipCodefrom = RouteMaster.ZipCodeFrom
		FROM   ROUTEMASTER (NOLOCK)
		WHERE  ROUTEMASTER.Route = @c_Address4 
	
		-- print 'test2'
		-- select @c_ZipCodefrom
		-- 
		-- select @c_Consigneekey, @c_Address4, @c_ZipCodefrom
		
		IF @c_ZipCodefrom is not NULL 
		BEGIN
			IF dbo.fnc_LTrim(dbo.fnc_RTrim(UPPER(@c_ZipCodefrom))) NOT IN ('UPC', 'BKK') 
			BEGIN
				SELECT @n_continue = 3
				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ZipFromCode " + @c_ZipCodefrom + " for Externorderkey " + @c_externorderkey + " does not setup correctly  (nsp_PMTL_Validation)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
			END
-- 			Else
-- 			BEGIN
-- 				SELECT @n_continue = 3
-- 				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
-- 				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Routemaster " + @c_Address4 + " for Externorderkey " + @c_externorderkey + " does not Exists  (nsp_PMTL_Validation)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
-- 			END
		END 
		Else
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Consigneekey " + @c_consigneekey + " for Externorderkey " + @c_externorderkey + " does not exist or Storer's Address4 is BLANK  (nsp_PMTL_Validation)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
		END
	
		IF (@d_deliverydate is not NULL OR @d_deliverydate = '')
		BEGIN
			SELECT @ll_DDate = LEN(convert(char(20),@d_deliverydate,103))
			SELECT @c_day = LEFT(convert(char(20),@d_deliverydate,103),2)
			SELECT @c_month = Substring(CONVERT(char(20),@d_deliverydate,103),4,2)
			SELECT @c_year = Substring(CONVERT(char(20),@d_deliverydate,103),7,4)
		END

		DECLARE @c_WkendTime01 NVARCHAR(2), @c_WkendTime02 NVARCHAR(2), @c_WkendTime03 NVARCHAR(4)

		SELECT @c_WkendTime01 = SUBSTRING(CONVERT(char(20),@c_adddate,113),13,2) 
		SELECT @c_WkendTime02 = Substring(CONVERT(char(20),@c_adddate,113),16,2)
		select @c_WkendTime03 = @c_WkendTime01 + @c_WkendTime02

		IF DATEPART ( dw , @c_adddate ) = 7 
		BEGIN 
			IF @c_WkendTime03 > 1300 
			BEGIN 
				SELECT @c_adddate = Convert(char(12),DATEADD(day,2,@c_adddate),106) 
			END
			ELSE
			BEGIN 
				SELECT @c_adddate = Convert(char(12),DATEADD(day,-1,@c_adddate),106) + '18:00'
			END
		END
		ELSE
		BEGIN 
			IF DATEPART ( dw , @c_adddate ) = 1 
			BEGIN 
				SELECT @c_adddate = Convert(char(12),DATEADD(day,1,@c_adddate),106)
			END 
		END 
		
		IF (@ll_DDate <= 10) AND UPPER(dbo.fnc_LTrim(dbo.fnc_RTrim(@d_deliverydate))) <> NULL 
		BEGIN
			SELECT @c_time = '00:00:00'
			SELECT @d_deliverydate = Convert(char(12), @d_deliverydate, 106)

			IF DATEPART ( dw , @d_deliverydate ) = 7 
			BEGIN 
				SELECT @d_deliverydate = Convert(char(12),DATEADD(day,2,@d_deliverydate),106)
			END
			ELSE
			BEGIN 
				IF DATEPART ( dw , @d_deliverydate ) = 1 
				BEGIN 
					SELECT @d_deliverydate = Convert(char(12),DATEADD(day,1,@d_deliverydate),106)
				END 
			END
		END
		ELSE 
		BEGIN
			SELECT @d_deliverydate = @c_adddate
		END


		IF @n_continue = 1 or @n_continue = 2
		BEGIN  --001
			declare @c_time01 NVARCHAR(2),
			@c_time02 NVARCHAR(2), 
			@c_timenow int,
			@ll_dayadd int,
			@c_currentdate datetime
	
			SELECT @c_time01 = Substring(CONVERT(char(20),@c_adddate,113),13,2) 
			SELECT @c_time02 = Substring(CONVERT(char(20),@c_adddate,113),16,2)
			SELECT @c_timenow = @c_time01 + @c_time02
			
			--    select @c_time01 '@c_time01',@c_time02 '@c_time01', @c_timenow '@c_timenow'      
			
			IF @c_timenow > 1300 
			--  BEGIN --002
				IF UPPER(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ZipCodeFrom))) = 'BKK'
				BEGIN
					SELECT @c_currentdate = Convert(char(12),DATEADD(day,2,@c_adddate),106)
	
					IF DATEDIFF ( day , @c_adddate, @d_deliverydate ) > 2  
					BEGIN 
						IF DATEPART ( dw , @d_deliverydate ) = 7  
						BEGIN 
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@d_deliverydate),106)		
						END 
						ELSE
						IF DATEPART ( dw , @d_deliverydate ) = 1  
						BEGIN
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@d_deliverydate),106)		
						END
						ELSE
						BEGIN
							Select @d_finaldeldate = Convert(char(12), @d_deliverydate, 106)
						END

						UPDATE ORDERS
						SET DeliveryDate = @d_finaldeldate, Trafficcop = Null  
                     ,EditDate = GETDATE() -- KH01
						WHERE Externorderkey = @c_externorderkey						
					END	
					ELSE
					BEGIN
						IF DATEPART ( dw , @c_currentdate ) = 7  
						BEGIN 
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@c_currentdate),106)		
						END 
						ELSE
						IF DATEPART ( dw , @c_currentdate ) = 1  
						BEGIN
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@c_currentdate),106)		
						END
						ELSE
						BEGIN
							Select @d_finaldeldate = Convert(char(12), @c_currentdate, 106)
						END

						UPDATE ORDERS
						SET DeliveryDate = @d_finaldeldate, Trafficcop = Null  
                     ,EditDate = GETDATE() -- KH01
						WHERE Externorderkey = @c_externorderkey
					END
	
					--   select @c_currentdate '@c_currentdate'
					--   select @d_deliverydate '@d_deliverydate'
				END
				ELSE
				BEGIN 
					IF DATEPART ( dw , @c_adddate ) = 6 -- Friday  
					BEGIN
						SELECT @c_currentdate = Convert(char(12),DATEADD(day,4,@c_adddate),106)
					END
					ELSE
					BEGIN 
						SELECT @c_currentdate = Convert(char(12),DATEADD(day,3,@c_adddate),106)
					END
	
					IF DATEDIFF ( day , @c_adddate, @d_deliverydate ) > 3  
					BEGIN 
						IF DATEPART ( dw , @d_deliverydate ) = 7  
						BEGIN 
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@d_deliverydate),106)		
						END 
						ELSE
						IF DATEPART ( dw , @d_deliverydate ) = 1  
						BEGIN
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@d_deliverydate),106)		
						END
						ELSE
						BEGIN
							Select @d_finaldeldate = Convert(char(12), @d_deliverydate, 106)
						END

						UPDATE ORDERS
						SET DeliveryDate = @d_finaldeldate, Trafficcop = Null  
                     ,EditDate = GETDATE() -- KH01
						WHERE Externorderkey = @c_externorderkey						
					END	
					ELSE
					BEGIN
						IF DATEPART ( dw , @c_currentdate ) = 7  
						BEGIN 
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@c_currentdate),106)		
						END 
						ELSE
						IF DATEPART ( dw , @c_currentdate ) = 1  
						BEGIN
							Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@c_currentdate),106)		
						END
						ELSE
						BEGIN
							Select @d_finaldeldate = Convert(char(12), @c_currentdate, 106)
						END

						UPDATE ORDERS
						SET DeliveryDate = @d_finaldeldate, Trafficcop = Null   
                     ,EditDate = GETDATE() -- KH01
						WHERE Externorderkey = @c_externorderkey
					END
				END   
			ELSE 
			IF UPPER(dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ZipCodeFrom))) = 'BKK'
			BEGIN
				SELECT @c_currentdate = Convert(char(12),DATEADD(day,1,@c_adddate), 106) 

				IF DATEDIFF ( day , @c_adddate, @d_deliverydate ) > 1  
				BEGIN 
					IF DATEPART ( dw , @d_deliverydate ) = 7  
					BEGIN 
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@d_deliverydate),106)		
					END 
					ELSE
					IF DATEPART ( dw , @d_deliverydate ) = 1  
					BEGIN
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@d_deliverydate),106)		
					END
					ELSE
					BEGIN
						Select @d_finaldeldate = Convert(char(12), @d_deliverydate, 106)
					END

					UPDATE ORDERS
					SET DeliveryDate = @d_finaldeldate, Trafficcop = Null   
                  ,EditDate = GETDATE() -- KH01
					WHERE Externorderkey = @c_externorderkey						
				END	
				ELSE
				BEGIN 
					IF DATEPART ( dw , @c_currentdate ) = 7  
					BEGIN 
						Select @d_finaldeldate = Convert(char(12),DATEADD(d,2,@c_currentdate),106)		
					END 
					ELSE
					IF DATEPART ( dw , @c_currentdate ) = 1  
					BEGIN
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@c_currentdate),106)		
					END
					ELSE
					BEGIN
						Select @d_finaldeldate = Convert(char(12), @c_currentdate, 106)
					END

					UPDATE ORDERS
					SET DeliveryDate = @d_finaldeldate, Trafficcop = Null   
                  ,EditDate = GETDATE() -- KH01
					WHERE Externorderkey = @c_externorderkey
				END

				--   select @c_currentdate '@c_currentdate'
				--   select @d_deliverydate '@d_deliverydate'
			END
			ELSE
			BEGIN 
				IF DATEPART ( dw , @c_adddate ) = 6 -- Friday  
				BEGIN
					SELECT @c_currentdate = Convert(char(12),DATEADD(day,3,@c_adddate),106)
				END
				ELSE
				BEGIN 
					SELECT @c_currentdate = Convert(char(12),DATEADD(day,2,@c_adddate),106)
				END

				IF DATEDIFF ( day , @c_adddate, @d_deliverydate ) >= 2  
				BEGIN 
					IF DATEPART ( dw , @d_deliverydate ) = 7  
					BEGIN 
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@d_deliverydate),106)		
					END 
					ELSE
					IF DATEPART ( dw , @d_deliverydate ) = 1  
					BEGIN
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@d_deliverydate),106)		
					END
					ELSE
					BEGIN
						Select @d_finaldeldate = Convert(char(12), @d_deliverydate, 106)
					END

					UPDATE ORDERS
					SET DeliveryDate = @d_finaldeldate, Trafficcop = Null   
                  ,EditDate = GETDATE() -- KH01
					WHERE Externorderkey = @c_externorderkey						
				END	
				ELSE
				BEGIN
					IF DATEPART ( dw , @c_currentdate ) = 7  
					BEGIN 
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,2,@c_currentdate),106)		
					END 
					ELSE
					IF DATEPART ( dw , @c_currentdate ) = 1  
					BEGIN
						Select @d_finaldeldate = Convert(char(12),DATEADD(day,1,@c_currentdate),106)		
					END
					ELSE
					BEGIN
						Select @d_finaldeldate = Convert(char(12), @c_currentdate, 106)
					END

					UPDATE ORDERS
					SET DeliveryDate = @d_finaldeldate, Trafficcop = Null   
                  ,EditDate = GETDATE() -- KH01
					WHERE Externorderkey = @c_externorderkey
				END
			END   
		END--001     
	
--		select @d_finaldeldate '@c_currentdate'

		IF @n_continue = 1 or @n_continue = 2 
		BEGIN
			DECLARE @C_Company char (45)
			, @C_vat char (18)
			, @C_Address1 char (45)
			, @C_Address2 char (45)
			, @C_Address3 char (45)
			--  , @C_Address4 
			, @C_City char (45)
			, @C_State char (2)
			, @C_Zip char (18)
			, @C_Country char (30)
			, @C_ISOCntryCode char (10)
			, @C_Contact1 char (30)
			, @C_Contact2 char (30)
			, @C_Phone1 char (18)
			, @C_Phone2 char (18)
			, @C_Fax1 char (18)
			, @C_Fax2 char (18)
			, @B_contact1 char (30) 
			, @B_Contact2 char (30)
			, @B_Company char (45)
			, @B_Address1 char (45)
			, @B_Address2 char (45)
			, @B_Address3 char (45)
			, @B_Address4 char (45)
			, @B_City char (45)
			, @B_State char (2)
			, @B_Zip char (18)
			, @B_Country char (30)
			, @B_ISOCntryCode char (10)
			, @B_Phone1 char (18)
			, @B_Phone2 char (18)
			, @B_Fax1 char (18)
			, @B_Fax2 char (18)
			, @BillToKey char (15)
					
			SELECT   @C_Company = Company
			, @C_vat = VAT
			, @C_Address1 = Address1
			, @C_Address2 = Address2
			, @C_Address3 = Address3
			--    , @C_Address4 = Address4
			, @C_City = City
			, @C_State = State
			, @C_Zip = Zip
			, @C_Country = Country
			, @C_ISOCntryCode = ISOCntryCode
			, @C_Contact1 = Contact1
			, @C_Contact2 = Contact2
			, @C_Phone1 = Phone1
			, @C_Phone2 = Phone2
			, @C_Fax1 = Fax1
			, @C_Fax2 = Fax2
			, @B_contact1 = B_contact1
			, @B_Contact2 = B_Contact2
			, @B_Company = B_Company
			, @B_Address1 = B_Address1
			, @B_Address2 = B_Address2
			, @B_Address3 = B_Address3
			, @B_Address4 = B_Address4
			, @B_City = B_City
			, @B_State = B_State
			, @B_Zip = B_Zip
			, @B_Country = B_Country
			, @B_ISOCntryCode = B_ISOCntryCode
			, @B_Phone1 = B_Phone1
			, @B_Phone2 = B_Phone2
			, @B_Fax1 = B_Fax1
			, @B_Fax2 = B_Fax2
			, @BillToKey = @c_consigneekey
			FROM   Storer (NOLOCK)
			WHERE  Storer.Storerkey = @c_consigneekey
	
			UPDATE ORDERS
			SET   C_Company = @C_Company
			, C_vat = @C_vat
			, C_Address1 = @C_Address1
			, C_Address2 = @C_Address2
			, C_Address3 = @C_Address3
			-- , C_Address4 = @C_Address4
			, C_City = @C_City
			, C_State = @C_State
			, C_Zip = @C_Zip
			, C_Country = @C_Country
			, C_ISOCntryCode = @C_ISOCntryCode
			, C_Contact1 = @C_Contact1
			, C_Contact2 = @C_Contact2
			, C_Phone1 = @C_Phone1
			, C_Phone2 = @C_Phone2
			, C_Fax1 = @C_Fax1
			, C_Fax2 = @C_Fax2
			, B_contact1 = @B_contact1
			, B_Contact2 = @B_Contact2
			, B_Company = @B_Company
			, B_Address1 = @B_Address1
			, B_Address2 = @B_Address2
			, B_Address3 = @B_Address3
			, B_Address4 = @B_Address4
			, B_City = @B_City
			, B_State = @B_State
			, B_Zip = @B_Zip
			, B_Country = @B_Country
			, B_ISOCntryCode = @B_ISOCntryCode 
			, B_Phone1 = @B_Phone1
			, B_Phone2 = @B_Phone2
			, B_Fax1 = @B_Fax1
			, B_Fax2 = @B_Fax2
			, BillToKey = @c_consigneekey 
			, Trafficcop = Null 
         , EditDate = GETDATE() -- KH01
			WHERE ORDERS.Consigneekey = @c_consigneekey
			AND ORDERS.Orderkey = @c_orderkey  
		END
	
		IF @n_continue = 1 or @n_continue = 2 
		BEGIN
			EXECUTE nspg_getkey
			"Sectionkey"
			, 10
			, @c_sectionkey OUTPUT
			, @b_success OUTPUT
			, @n_err OUTPUT
			, @c_errmsg OUTPUT

			BEGIN
				UPDATE ORDERS
				SET Sectionkey = @c_sectionkey, Trafficcop = Null 
               ,EditDate = GETDATE() -- KH01
				WHERE Orderkey = @c_orderkey 
			END
		END
	
		IF @n_continue = 1 or @n_continue = 2 
		BEGIN
			UPDATE ORDERS
			SET XDockFlag = '0', Userdefine08 = 'N', EffectiveDate = getdate(), Archivecop = NULL, Trafficcop = NULL
            ,EditDate = GETDATE() -- KH01
			WHERE Orderkey = @c_orderkey

			UPDATE ORDERDETAIL 
			SET ORDERDETAIL.PACKKEY = SKU.PACKKEY, ORDERDETAIL.Archivecop = NULL, 
			    ORDERDETAIL.FreeGoodQty = 0, ORDERDETAIL.EffectiveDate = getdate(), ORDERDETAIL.Trafficcop = NULL 
            ,ORDERDETAIL.EditDate = GETDATE() -- KH01
			FROM SKU (Nolock) 
			WHERE SKU.STORERKEY = ORDERDETAIL.STORERKEY 	
			  AND SKU.SKU = ORDERDETAIL.SKU 
			  AND ORDERDETAIL.Orderkey = @c_orderkey
		END
	END --01
END

GO