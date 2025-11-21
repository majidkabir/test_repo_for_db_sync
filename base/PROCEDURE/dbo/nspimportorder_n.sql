SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: nspImportOrder_N                                        */
/* Creation Date: 27-Nov-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: YokeBeen                                                 */
/*                                                                      */
/* Purpose: Duplicated from nspImportOrder  		                        */
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
/* Date         Author     Purposes                                     */
/* 27-Nov-2006  YokeBeen   Fixed issue for JJVC. - (SOS#63202)          */
/*                         - (YokeBeen01)                               */
/* 28-Nov-2006  YokeBeen   Re-write this program due to tables' status  */
/*                         update is not in the right sequence, causing */
/*                         Detail Lines' Insertion always fail to       */
/*                         process. - (SOS#63202)                       */
/* 08-Dec-2006  YokeBeen   Added parameter passing of Storerkey for     */
/*                         this SP in order to process on selected      */
/*                         storer separately. - (YokeBeen02)            */
/* 08-Feb-2007  YokeBeen   Add default value set for ORDERS.RoutingTool */
/*                         for TMS availability.                        */
/*                         Change to stop the process for storer NZM to */
/*                         upload from ILS. - (YokeBeen03)              */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspImportOrder_N] (
            @c_storerkey      NVARCHAR(15) 
 )
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_continue       int,  
        @n_starttcnt      int       , -- Holds the current transaction count
        @n_cnt            int       , -- Holds @@ROWCOUNT after certain operations
        @c_preprocess     NVARCHAR(250) , -- preprocess
        @c_pstprocess     NVARCHAR(250) , -- post process
        @n_err2           int       , -- For Additional Error Detection
        @b_debug          int       , -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
        @b_success        int       ,
        @n_err            int       ,   
        @c_errmsg         NVARCHAR(250) ,
        @errorcount       int

DECLARE @c_hikey          NVARCHAR(10),
        @c_cstorerkey     NVARCHAR(15), 
        @c_externorderkey NVARCHAR(30),
        @c_OldCompany     NVARCHAR(45),
        @c_OldAddress     NVARCHAR(45),
        @c_NewCompany     NVARCHAR(45),
        @c_NewAddress     NVARCHAR(45),
        @c_OrderHdrFlag   int 

SELECT @n_starttcnt=@@TRANCOUNT ,@n_continue=1, @b_success=0, @n_err=0, @n_cnt=0, @c_errmsg='', @n_err2=0
SELECT @b_debug = 0

/* Start Main Processing */
BEGIN TRAN
   -- get the hikey,
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   SELECT @b_success = 0

   EXECUTE nspg_GetKey
          'hirun',
           10,
           @c_hikey    OUTPUT,
           @b_success  OUTPUT,
           @n_err      OUTPUT,
           @c_errmsg   OUTPUT

   IF NOT @b_success = 1
   BEGIN
      SELECT @n_continue = 3
   END
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @b_debug = 1
   BEGIN
      SELECT '@c_hikey: ', @c_hikey
   END

   INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
   VALUES ( @c_hikey, ' -> nspImportOrder -- The HI Run Identifer Is ' + 
            @c_hikey + ' started at ' + convert (char(20), getdate()), 'GENERAL', ' ')

   SELECT @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed On HIERROR. (nspImportOrder_N)' + ' ( ' + 
                         ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   END
END
-- BEGIN VALIDATION SECTION
-- do all the validation on the WMSORM and WMSORD tables first before inserting into temp table
-- 'ERROR CODES ->
-- 1. E1 for blank externorderkey
-- 2. E2 for blank storerkey
-- 3. E3 for Invalid Storerkey
-- 4. E4 for Invalid sku
-- 5. E5 for repeating externorderkey
-- 6. E6 for non existing externorderkey in header file
-- 7. E7 for Invalid Lottable01 - HOSTWHCODE
-- check for existing externorderkey

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   DECLARE @count1 int

   IF EXISTS (SELECT 1 FROM WMSORM (NOLOCK) WHERE WMS_FLAG = 'N')
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Records to process from WMSORM... '
      END

      SELECT @n_continue = 1

      -- update the hikey to the column addwho in the tables WMSRCM and WMSRCD 
      Update WMSORM WITH (ROWLOCK)
         SET ADDWHO = @c_hikey
       WHERE WMS_FLAG = 'N'
         AND ( dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) IS NULL )

      UPDATE WMSORD WITH (ROWLOCK)
         SET ADDWHO = @c_hikey
       WHERE WMS_FLAG = 'N'
         AND (dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(ADDWHO)) IS NULL )
   END
   ELSE
   BEGIN
      SELECT @n_continue = 4
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
      VALUES ( @c_hikey, ' -> nspImportOrder -- There is no records to be processed for ' + 
               @c_hikey + '. Process ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed On HIERROR. (nspImportOrder_N)' + 
                            ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
 	
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'Records error status update... '
      END

      IF EXISTS ( SELECT DISTINCT 1 FROM WMSORM (NOLOCK) JOIN ORDERS (NOLOCK) 
                      ON (WMSORM.ExternOrderkey = ORDERS.ExternOrderkey)
                   WHERE WMSORM.WMS_FLAG = 'N'
                     AND ORDERS.ExternOrderKey <> '' 
                     AND WMSORM.Storerkey = ORDERS.Storerkey )
      BEGIN -- Header records' check
         IF NOT EXISTS ( SELECT DISTINCT 1 FROM WMSORD (NOLOCK) JOIN ORDERS (NOLOCK) 
                         ON (WMSORD.ExternOrderkey = ORDERS.ExternOrderkey)
                      WHERE WMSORD.WMS_FLAG = 'N'
                        AND ORDERS.ExternOrderKey <> '' 
                        AND WMSORD.Storerkey = ORDERS.Storerkey )
         BEGIN -- Detail records' check
            IF @b_debug = 1
            BEGIN
               SELECT 'Records found to be duplicated... '
            END

            UPDATE WMSORM WITH (ROWLOCK)
               SET WMS_FLAG = 'E5'
              FROM WMSORM 
              JOIN ORDERS (NOLOCK) ON WMSORM.ExternOrderkey = ORDERS.ExternOrderkey
             WHERE WMSORM.WMS_FLAG = 'N'
               AND ORDERS.ExternOrderKey <> ''  -- (YokeBeen01)
               AND WMSORM.Storerkey = ORDERS.Storerkey  -- (YokeBeen01)
      
            UPDATE WMSORD WITH (ROWLOCK)
               SET WMS_FLAG = 'E5'
              FROM WMSORD 
              JOIN ORDERS (NOLOCK) ON WMSORD.ExternOrderkey = ORDERS.ExternOrderkey
             WHERE WMSORD.WMS_FLAG = 'N'
               AND WMSORD.Storerkey = ORDERS.Storerkey  -- (YokeBeen01)
         END -- Detail records' check
      END -- Header records' check

      -- check for blank externorderkey
      UPDATE WMSORM WITH (ROWLOCK)
         SET WMS_FLAG = 'E1'
       WHERE ( ExternOrderkey = '' 
          OR ExternOrderkey IS NULL )
         AND WMS_FLAG = 'N'
      
      -- check for blank externorderkey in detail 
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E1'
       WHERE ( ExternOrderkey = '' 
          OR ExternOrderkey IS NULL )
         AND WMS_FLAG = 'N'

      -- check for blank storerkey
      UPDATE WMSORM WITH (ROWLOCK)
         SET WMS_FLAG = 'E2'
       WHERE ( Storerkey = ''
          OR Storerkey IS NULL )
         AND WMS_FLAG = 'N'

      -- if header has a storerkey, and not detail, populate the header storerkey (valid one) based on the externorderkey
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMSORD.Storerkey = WMSORM.Storerkey
        FROM WMSORM
        JOIN WMSORD ON WMSORM.ExternOrderkey = WMSORD.ExternOrderkey
        JOIN STORER (NOLOCK) ON WMSORM.Storerkey = STORER.Storerkey
       WHERE WMSORM.Storerkey <> ''
         AND WMSORM.WMS_FLAG = 'N'
         AND WMSORD.WMS_Flag = 'N'
      
      -- check for invalid storerkey
      UPDATE WMSORM WITH (ROWLOCK)
         SET WMS_FLAG = 'E3'
        FROM WMSORM 
        LEFT OUTER JOIN STORER (NOLOCK) ON WMSORM.Storerkey = STORER.Storerkey
       WHERE STORER.Storerkey IS NULL 
         AND WMS_FLAG = 'N'
      
      -- make the detail invalid too once the storerkey in the header is invalid
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E3'
        FROM WMSORD 
        JOIN WMSORM ON (WMSORM.ExternOrderkey = WMSORD.ExternOrderkey )
        LEFT OUTER JOIN STORER (NOLOCK) ON WMSORM.Storerkey = STORER.Storerkey
       WHERE WMSORD.WMS_FLAG = 'N'
         AND STORER.Storerkey IS NULL 
         AND WMSORM.WMS_Flag = 'E3'
      
      -- check for invalid sku
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E4'
        FROM WMSORD 
        LEFT OUTER JOIN SKU (NOLOCK) ON WMSORD.Storerkey = SKU.Storerkey AND WMSORD.SKU = SKU.SKU 
       WHERE SKU.SKU IS NULL 
         AND WMSORD.WMS_FLAG = 'N'
      
      -- once we found the invalid sku, reject the rest of the detail lines as well as the header 
      UPDATE WMSORM WITH (ROWLOCK)
         SET WMS_FLAG = 'E4'
        FROM WMSORM
        JOIN WMSORD ON (WMSORD.ExternOrderkey = WMSORM.ExternOrderkey) 
       WHERE WMSORD.WMS_FLAG = 'E4'
         AND WMSORM.WMS_FLAG = 'N'
      
      -- check this one, might now work
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E4'
        FROM WMSORD 
        JOIN (SELECT DISTINCT ExternOrderkey FROM WMSORD (NOLOCK) Where WMS_Flag = 'E4') AS WMSORD_E4 
          ON WMSORD.ExternOrderkey = WMSORD_E4.ExternOrderkey
         AND WMSORD.WMS_FLAG = 'N'
      
      -- check for externorderkey that only exist in detail but not header
      Update WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E6'
        FROM WMSORD 
        LEFT OUTER JOIN WMSORM (NOLOCK) ON (WMSORD.ExternOrderkey = WMSORM.ExternOrderkey)
       WHERE WMSORM.ExternOrderkey IS NULL 
         AND WMSORD.WMS_FLAG = 'N'
      
      -- check for existance of lottable01
      UPDATE WMSORD WITH (ROWLOCK)
         SET WMS_FLAG = 'E7'
       WHERE ( dbo.fnc_LTrim(dbo.fnc_RTrim(Lottable01)) = '' OR dbo.fnc_LTrim(dbo.fnc_RTrim(Lottable01) ) IS NULL )
         AND WMS_FLAG = 'N'
   END -- @n_continue

   IF EXISTS (SELECT 1 FROM WMSORM (NOLOCK) WHERE SUBSTRING(WMS_FLAG,1,1) = 'E' AND ADDWHO = @c_hikey )
   BEGIN
      INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType, sourcekey )
      VALUES ( @c_hikey, 'There are invalid externorderkeys and/or storerkey.' , 'GENERAL', ' ')

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed On HIERROR. (nspImportOrder_N)' + 
                            ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
END -- @n_continue
-- END OF VALIDATION SECTION

DECLARE @c_lastexternorderkey NVARCHAR(30),
        @c_currentexternorderkey NVARCHAR(30),
        @c_orderkey NVARCHAR(10),
        @c_orderlinenumber NVARCHAR(5),
        @c_orderdate NVARCHAR(10),
        @c_effectivedate NVARCHAR(10),
        @c_deliveryDate NVARCHAR(10)

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   UPDATE WMSORM WITH (ROWLOCK)
      SET ROUTE = ISNULL(DS.ROUTE, ''),
          DOOR  = ISNULL(DS.DOOR, ''),
          STOP  = ISNULL(DS.STOP, '')
     FROM WMSORM, STORERSODEFAULT DS (NOLOCK) 
    WHERE WMS_FLAG = 'N'
      AND WMSORM.ConsigneeKey = DS.StorerKey
      AND ( WMSORM.ROUTE IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(WMSORM.ROUTE)) = '' )
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   SELECT @c_lastexternorderkey = ''
   -- the date format is yyyymmdd   

   -- (YokeBeen02) - Start
   IF (@c_storerkey = '%')
   BEGIN
      DECLARE cur_mas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ExternOrderkey, Storerkey, CONVERT(CHAR(10), OrderDate), 
             CONVERT(CHAR(10), EffectiveDate), CONVERT (CHAR(10), DeliveryDate)
        FROM WMSORM (NOLOCK) 
       WHERE WMS_FLAG = 'N'
         AND Storerkey NOT IN ('JNJ','NZM','CHD') -- (YokeBeen03)
       ORDER BY StorerKey, ExternOrderkey 
   END
   ELSE
   BEGIN
      DECLARE cur_mas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT ExternOrderkey, STORERKEY, CONVERT(CHAR(10), OrderDate), 
             CONVERT(CHAR(10), EffectiveDate), CONVERT (CHAR(10), DeliveryDate)
        FROM WMSORM (NOLOCK) 
       WHERE WMS_FLAG = 'N'
         AND Storerkey = @c_storerkey 
         AND Storerkey NOT IN ('NZM','CHD') -- (YokeBeen03)
       ORDER BY StorerKey, ExternOrderkey 
   END
   -- (YokeBeen02) - End

   OPEN cur_mas

   FETCH NEXT FROM cur_mas INTO @c_currentexternorderkey, @c_cstorerkey, @c_orderdate, 
                                @c_effectivedate, @c_deliverydate

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_continue = 3 BREAK

      SELECT @c_OrderHdrFlag = 0
      SELECT @c_OrderHdrFlag = 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_currentexternorderkey

      IF @b_debug = 1
      BEGIN
         SELECT '@c_OrderHdrFlag/@c_currentexternorderkey/@c_cstorerkey: ', 
                 @c_OrderHdrFlag, @c_currentexternorderkey, @c_cstorerkey 
      END

      IF (@c_lastexternorderkey <> @c_currentexternorderkey) 
      BEGIN
         IF (@c_OrderHdrFlag <> 1)
         BEGIN 
            -- generate a new orderkey
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               EXECUTE nspg_GetKey
                      'ORDER',
                       10,
                       @c_orderkey OUTPUT,
                       @b_success   	 OUTPUT,
                       @n_err       	 OUTPUT,
                       @c_errmsg    	 OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
         END -- IF (@c_OrderHdrFlag <> 1)
         ELSE
         BEGIN
            SELECT @c_orderkey = OrderKey FROM ORDERS (NOLOCK) 
             WHERE ExternOrderKey = @c_currentexternorderkey AND StorerKey = @c_cstorerkey
         END -- IF (@c_OrderHdrFlag = 1)
      END

      IF @b_debug = 1
      BEGIN
         SELECT '@c_orderkey: ', @c_orderkey 
      END

      -- change the date format, from AS/400, it's numeric
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_orderdate)) = '0'
      BEGIN
         SELECT @c_orderdate = CONVERT(CHAR(10), getdate(), 101)   
      END
      ELSE
      BEGIN      -- yyyymmdd
         SELECT @c_orderdate = SUBSTRING(@c_orderdate, 5,2) + '/' + 
                               SUBSTRING(@c_orderdate, 7,2) + '/' + SUBSTRING(@c_orderdate, 1,4)
      END

      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_effectivedate)) = '0'
      BEGIN
         SELECT @c_effectivedate = convert ( NVARCHAR(10), getdate(), 101)   
      END
      ELSE
      BEGIN      -- yyyymmdd
         SELECT @c_effectivedate = SUBSTRING(@c_effectivedate, 5,2) + '/' + 
                                   SUBSTRING(@c_effectivedate, 7,2) + '/' + SUBSTRING(@c_effectivedate, 1,4)
      END

      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_deliverydate)) = '0'
      BEGIN
         SELECT @c_deliverydate = CONVERT(CHAR(10), getdate(), 101)   
      END
      ELSE
      BEGIN      -- yyyymmdd
         SELECT @c_deliverydate = SUBSTRING(@c_deliverydate, 5,2) + '/' + 
                                  SUBSTRING(@c_deliverydate, 7,2) + '/' + SUBSTRING(@c_deliverydate, 1,4)
      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN -- Order Processing
         IF @b_debug = 1
         BEGIN
            SELECT 'Order processing... ', @c_currentexternOrderkey 
         END

         DECLARE @c_consigneekey NVARCHAR(15)
         -- insert new consignee into storer table, if it is new one.

         SELECT @c_consigneekey = dbo.fnc_LTrim(dbo.fnc_RTrim(Consigneekey))
           FROM WMSORM (NOLOCK) 
          WHERE WMS_FLAG = 'N'
            AND ExternOrderkey = @c_currentexternOrderkey

         IF NOT EXISTS ( SELECT 1 FROM STORER (NOLOCK) WHERE STORERKEY = @c_consigneekey )
         BEGIN
            INSERT INTO STORER ( Storerkey, Type, VAT, Company, Address1, Address2, Address3, Address4, 
                                 City, State, Zip, Country, ISOCntryCode, Contact1, Contact2, Phone1, 
                                 Phone2, Fax1, Fax2 )
            SELECT @c_consigneekey, '2', C_vat, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, 
                   C_City, C_State, C_Zip, C_Country, C_ISOCntryCode,  C_contact1, C_Contact2, C_Phone1, 
                   C_Phone2, C_Fax1, C_Fax2
              FROM WMSORM
             WHERE WMS_FLAG = 'N'
               AND ExternOrderkey = @c_currentExternOrderkey

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62121   
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                                  ': Unable to create new consignee. (nspImportOrder_N)' + 
                                  ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
					-- ONG01 Check before insert new StorerBiling
					IF NOT EXISTS ( SELECT 1 FROM STORERBILLING (NOLOCK) WHERE STORERKEY = @c_consigneekey ) 
					BEGIN
	               INSERT INTO STORERBILLING (Storerkey)
	               VALUES (@c_consigneekey)
					END
            END
         END -- if not exists
         ELSE
         BEGIN -- Added By Shong, If Company or Address is Diff then update consignee info
            SELECT @c_NewCompany = C_Company, 
                   @c_NewAddress = C_Address1
              FROM WMSORM (NOLOCK) 
             WHERE WMS_FLAG = 'N'
               AND ExternOrderkey = @c_currentExternOrderkey

            SELECT @c_OldCompany = Company,
                   @C_OldAddress = Address1
              FROM STORER (NOLOCK)
             WHERE STORERKEY = @c_consigneekey

            IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OldCompany)) <> dbo.fnc_RTrim(dbo.fnc_LTrim(@c_NewCompany)) OR
               dbo.fnc_RTrim(dbo.fnc_LTrim(@c_OldAddress)) <> dbo.fnc_RTrim(dbo.fnc_LTrim(@c_NewAddress))
            BEGIN
               UPDATE STORER WITH (ROWLOCK)
                  SET Company = @c_NewCompany,
                      Address1 = @c_NewAddress
                WHERE STORERKEY = @c_consigneekey
            END
         END 

         IF @n_continue = 1 OR @n_continue = 2 
         BEGIN      
            IF (@c_OrderHdrFlag <> 1)
            BEGIN
               IF @b_debug = 1
               BEGIN
                  SELECT 'New Order Insertion.. ', @c_currentexternOrderkey 
               END

               INSERT INTO ORDERS ( OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate, Priority, ConsigneeKey,
           		   C_contact1, C_Contact2, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City,
     	   		   C_State, C_Zip, C_Country, C_ISOCntryCode, C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat,
    		   	   BuyerPO, BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2, B_Address3,
    			      B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode, B_Phone1, B_Phone2, B_Fax1,
    			      B_Fax2, B_Vat, IncoTerm, PmtTerm, Openqty, status, DischargePlace, DeliveryPlace, IntermodalVehicle,
       			   CountryOfOrigin, CountryDestination,  Type, OrderGroup, Door, Route, Stop, Notes, EffectiveDate,
       			   ContainerType, ContainerQty, BilledContainerQty, SOStatus, InvoiceNo, InvoiceAmount, Salesman,
    	   		   GrossWeight, Capacity, PrintFlag, rdd, Notes2, SequenceNo, Rds, SectionKey , FACILITY, RoutingTool) -- (YokeBeen03)
               SELECT @c_orderkey, STORERKEY, ExternOrderkey, CONVERT(DATETIME, @c_orderdate) , 
                   CONVERT(DATETIME,@c_deliverydate), PRIORITY, dbo.fnc_LTrim(dbo.fnc_RTrim(CONSIGNEEKEY)),
    	      	    C_CONTACT1, C_CONTACT2, C_COMPANY, C_ADDRESS1, C_ADDRESS2, C_ADDRESS3, C_ADDRESS4, C_CITY,
          		    C_STATE, C_ZIP, C_COUNTRY, C_ISOCNTRYCODE, C_PHONE1, C_PHONE2, C_FAX1, C_FAX2, C_VAT, 
          		    BUYERPO, BILLTOKEY, B_CONTACT1, B_CONTACT2, B_COMPANY, B_ADDRESS1, B_ADDRESS2,B_ADDRESS3,
          		    B_ADDRESS4, B_CITY, B_STATE, B_ZIP, B_COUNTRY, B_ISOCNTRYCODE, B_PHONE1, B_PHONE2, B_FAX1,
          		    B_FAX2, B_VAT, INCOTERM, PMTTERM, 0, '0', DISCHARGEPLACE, DELIVERYPLACE, INTERMODALVEHICLE,
          		    COUNTRYOFORIGIN, COUNTRYDESTINATION, TYPE, ORDERGROUP, DOOR, ROUTE, STOP, NOTES, 
                   CONVERT(DATETIME, @c_effectivedate),
          		    CONTAINERTYPE, CONTAINERQTY, BILLEDCONTAINERQTY, '0', INVOICENO, INVOICEAMOUNT, SALESMAN,
          		    0.0, 0.0, 'N' , RDD, NOTES2, SEQUENCENO, RDS, SECTIONKEY, Facility, 'Y' -- (YokeBeen03)
                 FROM WMSORM (NOLOCK) 
                WHERE WMS_FLAG = 'N'
                  AND ExternOrderkey = @c_currentexternOrderkey 

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62103   
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed On Orders. (nspImportOrder_N)' + 
                                     ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- IF (@c_OrderHdrFlag <> 1)
         END -- @n_continue = 1

         -- send confirmation back to ILS, indicating this externorderkey has been successfully downloaded.
         /* Comment by Shong - Change procedure
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            INSERT INTO WMS_DAILY..OrderConf (ExternOrderkey)
            VALUES ( @c_currentExternOrderkey)
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62113   
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+
                                ": Unable to insert Confirmation record(nspImportOrder)" + 
                                " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
         END
         End of Comment */

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'Order Detail Processing.. ', @c_currentexternOrderkey 
            END

            IF (@c_OrderHdrFlag = 1)
      BEGIN
               SELECT @c_orderlinenumber = ISNULL(MAX(OrderLineNumber),0)
                 FROM ORDERDETAIL (nolock)
                WHERE ExternOrderkey = @c_currentexternOrderkey
                  AND OrderKey = @c_orderkey

      			SELECT @c_orderlinenumber = @c_orderlinenumber + 1
            END
            ELSE
            BEGIN
               SELECT @c_orderlinenumber = 1
            END

            IF @b_debug = 1
            BEGIN
               SELECT 'Initial Order Detail Line.. ', @c_orderlinenumber 
            END

            DECLARE @c_lottable04 NVARCHAR(10), @c_lottable05 NVARCHAR(10), @c_det_externorderkey NVARCHAR(30), 
                    @c_det_storerkey NVARCHAR(15), @c_det_sku NVARCHAR(20), @c_packkey NVARCHAR(10), @c_externlineno NVARCHAR(20)
            -- inserting lines into orderdetail, have to use cursor

            DECLARE CUR_Det CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT dbo.fnc_RTrim(dbo.fnc_LTrim(WMSORD.ExternOrderkey)), WMSORD.Storerkey, SKU, CONVERT(CHAR(10), Lottable04 ), 
                   CONVERT (CHAR(10), Lottable05), CONVERT(CHAR(10), WMSORD.Effectivedate ), ExternLineNo, ConsigneeKey
              FROM WMSORD (NOLOCK), WMSORM (NOLOCK)
             WHERE WMSORD.ExternOrderkey = @c_currentexternOrderkey
               AND WMSORD.WMS_FLAG = 'N'
               AND WMSORD.ExternOrderkey = WMSORM.ExternOrderkey

            OPEN cur_det

            FETCH NEXT FROM cur_det INTO @c_det_externorderkey , @c_det_storerkey , @c_det_sku, @c_lottable04, 
                                         @c_lottable05, @c_effectivedate, @c_externlineno, @c_ConsigneeKey        

            WHILE (@@FETCH_STATUS <> -1) --or ( @n_continue <> '3' )
            BEGIN 
               IF @b_debug = 1
               BEGIN
                  SELECT 'Order Detail Cursor Loop for ExternOrderkey.. ', @c_currentexternOrderkey 
               END

               IF NOT EXISTS ( SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE ExternOrderKey = @c_currentexternorderkey 
                                  AND ExternLineNo = @c_externlineno )
               BEGIN -- Detail Line Not Exist 
                  IF @n_continue = 3 BREAK

                  -- get the packkey
                  SELECT @c_packkey = PACKKEY 
                    FROM SKU (NOLOCK)
                   WHERE SKU = @c_det_sku and storerkey = @c_det_storerkey  --Jeff added for Riche Monde packkey ----

                  -- convert the lottable04 and lottable05 if any
                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable04)) = '0'
                  BEGIN
                     SELECT @c_lottable04 = '' -- null
                  END
                  ELSE
                  BEGIN      -- yyyymmdd 
                     SELECT @c_lottable04 = SUBSTRING(@c_lottable04, 5,2) + '/' + 
                                            SUBSTRING(@c_lottable04, 7,2) + '/' + SUBSTRING(@c_lottable04, 1,4)
                  END            

                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable05)) = '0'
                  BEGIN
                     SELECT @c_lottable05 = '' -- null
                  END
                  ELSE
                  BEGIN      -- yyyymmdd
                     SELECT @c_lottable05 = SUBSTRING(@c_lottable05, 5,2) + '/' + 
                                            SUBSTRING(@c_lottable05, 7,2) + '/' + SUBSTRING(@c_lottable05, 1,4)
                  END            

                  IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_effectivedate)) = '0'
                  BEGIN
                     SELECT @c_effectivedate = CONVERT(CHAR(10), getdate(), 101)   
                  END
                  ELSE
                  BEGIN      -- yyyymmdd
                     SELECT @c_effectivedate = SUBSTRING(@c_effectivedate, 5,2) + '/' + 
                                               SUBSTRING(@c_effectivedate, 7,2) + '/' + Substring(@c_effectivedate, 1,4)
                  END

                -- Obtain packuom3 from pack table
                  DECLARE @c_uom NVARCHAR(10)
                   SELECT @c_uom = PACKUOM3 
                     FROM PACK (NOLOCK) 
                     JOIN SKU (NOLOCK) ON (SKU.PackKey = PACK.PackKey )
                    WHERE sku = @c_det_sku and storerkey = @c_det_storerkey

                   -- generate the orderlinenumber 
             	    SELECT @c_orderlinenumber  
                   SELECT @c_orderlinenumber = CONVERT(CHAR(5), 
                                               REPLICATE('0', (5 - LEN(@c_orderlinenumber))) + @c_orderlinenumber) 

                   IF @b_debug = 1
                   BEGIN
                      SELECT 'Order DetailLine Insertion.. ', @c_currentexternOrderkey, @c_externLineno 
                   END

                   -- Modifed By SHONG 
                   -- Date: 25th April 2001
                   -- SOS Ticket No 963
                   -- Force only retrieve 1 record in-case there are more then 1 records in the WMSORD
                   SET ROWCOUNT 1 
                   INSERT INTO ORDERDETAIL ( OrderKey, OrderLineNumber, ExternOrderKey, ExternLineNo, Sku, StorerKey,
       			                ManufacturerSku, RetailSku, AltSku, OriginalQty, OpenQty, AdjustedQty, 
                               UOM, PackKey, Status, UnitPrice, Tax01, Tax02, ExtendedPrice, 
                               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                               EffectiveDate, TariffKey, GrossWeight, Capacity )
                   SELECT DISTINCT @c_orderkey, @c_orderlinenumber, @c_currentexternorderkey, @c_externlineno, SKU, STORERKEY, 
          		           MANUFACTURERSKU, RETAILSKU, ALTSKU, ORIGINALQTY, OPENQTY, ADJUSTEDQTY, 
                          @c_uom, @c_packkey , '0', 0.0, 0.0, 0.0, 0.0, 
                          LOTTABLE01, LOTTABLE02, @c_ConsigneeKey, CONVERT(DATETIME, @c_Lottable04), 
                          CONVERT(DATETIME, @c_lottable05), 
                          CONVERT(DATETIME, @c_effectivedate), 'XXXXXXXXXX', 0.0, 0.0 
                     FROM WMSORD
                    WHERE WMS_FLAG = 'N'
                      AND ExternOrderkey = @c_currentexternorderkey
             	       AND ExternLineNo = @c_externLineno
             	       AND SKU = @c_det_sku

                  -- Set the row count back to NORMAL
                  SET ROWCOUNT 0
           	      SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62104   
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                                        ': Insert Failed On OrderDetail. (nspImportOrder_N)' + 
                                        ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END

                -- update the status WMSORD after it has been successfully inserted into orderdetail table.
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT 'WMSORD Status Update.. ', @c_currentexternOrderkey, @c_externLineno 
                     END

                     UPDATE WMSORD WITH (ROWLOCK)
                        SET Orderkey = @c_orderkey, Orderlinenumber = @c_orderlinenumber, WMS_FLAG = 'R'
                      WHERE ExternOrderkey = @c_currentexternorderkey
                        AND ExternLineno = @c_externlineno

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62112   
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                                           ': Update Failed On WMSORD. (nspImportOrder_N)' + 
                                           ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END            
                  SELECT @c_orderlinenumber = @c_orderlinenumber + 1  
               END -- Detail Line Not Exist 
               ELSE 
               BEGIN 
                  SELECT @c_orderlinenumber = OrderLineNumber 
                    FROM ORDERDETAIL (nolock)
                   WHERE ExternOrderkey = @c_currentexternOrderkey
                     AND ExternLineNo = @c_externlineno 
                     AND OrderKey = @c_orderkey

                  IF EXISTS ( SELECT 1 FROM WMSORD (NOLOCK) WHERE ExternOrderkey = @c_currentexternorderkey 
                                 AND ExternLineno = @c_externlineno AND ISNULL(Orderkey,'') = '' 
                                 AND ISNULL(Orderlinenumber,'') = '' AND WMS_FLAG = 'N' )
                  BEGIN
                     UPDATE WMSORD WITH (ROWLOCK)
                        SET Orderkey = @c_orderkey, Orderlinenumber = @c_orderlinenumber, WMS_FLAG = 'R'
                      WHERE ExternOrderkey = @c_currentexternorderkey
                        AND ExternLineno = @c_externlineno

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62114   
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + 
                                           ': Update Failed On WMSORD. (nspImportOrder_N)' + 
                                           ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
               END -- Detail Line Exist

               FETCH NEXT FROM cur_det INTO @c_det_externorderkey , @c_det_storerkey , @c_det_sku, @c_lottable04, 
                                            @c_lottable05, @c_effectivedate, @c_externlineno, @c_ConsigneeKey        
            END -- end while for detail
         	CLOSE cur_det
           	DEALLOCATE cur_det
         END -- IF NOT EXISTS @c_consigneekey Check

         -- update the original table, to indicate that the order header has been successfully downloaded   
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            IF EXISTS ( SELECT DISTINCT 1 FROM ORDERDETAIL (NOLOCK) WHERE ExternOrderkey = @c_currentexternOrderkey )
            BEGIN 
               IF NOT EXISTS ( SELECT DISTINCT 1 FROM WMSORD (NOLOCK) 
                                WHERE WMSORD.ExternOrderkey = @c_currentexternOrderkey
                                  AND WMSORD.WMS_FLAG = 'N' )
               BEGIN 
                  IF @b_debug = 1
                  BEGIN
                     SELECT 'WMSORM Status Update.. ', @c_currentexternOrderkey 
                  END

                  UPDATE WMSORM WITH (ROWLOCK)
                     SET Orderkey = @c_orderkey, WMS_FLAG = 'R'
                   WHERE ExternOrderkey = @c_currentexternorderkey

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62111   
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Failed On WMSORM. (nspImportOrder_N)' + 
                                     ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END 
               END 
            END -- Check any detail lines exist 
         END -- Update Header Status
      END -- Order Processing
      SELECT @c_lastexternorderkey = @c_currentexternorderkey

      FETCH NEXT FROM cur_mas INTO @c_currentexternorderkey, @c_cstorerkey, @c_orderdate, 
                                   @c_effectivedate, @c_deliverydate
   END -- while
   CLOSE cur_mas
   DEALLOCATE cur_mas
END -- @n_continue 

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   INSERT INTO HIERROR (HiErrorGroup, ErrorText, ErrorType , sourcekey)
   VALUES ( @c_hikey, ' -> nspImportOrder. Process completed for ' + 
            @c_hikey + '. Process ended at ' + convert (char(20), getdate()), 'GENERAL', ' ')
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed On HIERROR. (nspImportOrder_N)' + 
                         ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   END
END

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END

   EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'nspImportOrder_N'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END
END -- end of procedure

GO