SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspImportData_old                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspImportData_old]
@c_modulename NVARCHAR(10)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug: 0 - OFF, 1 - show all, 2 - map
   , @c_headertable NVARCHAR(40)
   , @c_detailtable NVARCHAR(40)
   , @n_tablecounter int
   , @count1 int
   , @string NVARCHAR(250)
   , @c_externpokey NVARCHAR(20)
   , @c_sellername NVARCHAR(45)
   , @c_potype NVARCHAR(10)
   , @c_storerkey NVARCHAR(15)
   , @c_externlinenumber NVARCHAR(20)
   , @c_sku NVARCHAR(20)
   , @c_uom NVARCHAR(10)
   , @n_qtyordered int
   , @c_externorderkey NVARCHAR(20)
   , @c_headflag NVARCHAR(1)
   , @c_detailflag NVARCHAR(1)
   , @n_shippedqty int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg="", @n_err2=0
   SELECT @b_debug = 0
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_headertable =
      CASE @c_modulename
      WHEN 'PO' THEN 'UPLOADPOHEADER'
      WHEN 'ORDER' THEN 'UPLOADORDERHEADER'
   END,
   @c_detailtable =
   CASE @c_modulename
   WHEN 'PO' THEN 'UpLoadPODetail'
   WHEN 'ORDER' THEN 'UploadOrderdetail'
END
END
IF @b_debug = 1
BEGIN
   select @c_headertable
   Select @c_detailtable
END
-- --------------------------------------------------------------------------------------------------------------
-- BEGIN PROCESSING FOR MODE = '1' - RECORDS INSERTION
-- --------------------------------------------------------------------------------------------------------------
IF @n_continue = 1 OR @n_continue = 2 -- mode 1
BEGIN
   -- do insertion of records
   IF @c_headertable = 'UPLOADPOHEADER'
   BEGIN
      SELECT @count1 = COUNT(*) FROM UPLOADPOHEADER (nolock) WHERE MODE = '1' AND STATUS = '0'
      IF @b_debug = 1
      BEGIN
         IF @count1 = 0
         BEGIN
            SELECT 'No Records for PO HEader for MODE = 1 '
         END
      END
      IF @count1 > 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Inserting PO Header Records'
         END
         INSERT INTO PO (Pokey, ExternPokey, POGROUP, Storerkey, POType, SellerName )
         SELECT POkey, ExternPokey, POGROUP, Storerkey, POTYpe, SellerName
         FROM UPLOADPOHEADER (nolock) WHERE MODE = '1'
         AND STATUS = '0'
         SELECT @n_err = @@ERROR
         IF @n_err = 0
         BEGIN
            -- once inserted, update the status = '9'
            UPDATE UPLOADPOHEADER
            SET Status = '9'
            WHERE MODE = '1'
            AND STATUS = '0'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 65005
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PO (nspImportData_old)"
            END
         END
      ELSE
         BEGIN
            -- error updating
            UPDATE UPLOADPOHEADER
            SET STATUS = '5', REMARKS = '65006: ERROR Uploading PO Header'
            WHERE Status = '0'
            and MODE = '1'
            SELECT @n_continue = 3
            SELECT @n_err = 65006
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PO (nspImportData_old)"
         END
      END
   END -- header table uploadpoheader
   IF @c_headertable = 'UPLOADORDERHEADER'
   BEGIN
      -- insert records into Orders table.
      SELECT @count1 = COUNT(*) FROM UPLOADORDERHEADER (nolock) WHERE MODE = '1' AND STATUS = '0'
      IF @count1 > 0
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT 'Inserting Orders Header'
         END
         INSERT INTO ORDERS (Orderkey, storerkey, externorderkey, orderdate, deliverydate, priority,
         c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3, c_address4,
         c_city , c_state, c_zip, buyerpo, notes, invoiceno, notes2, pmtterm, invoiceamount )
         SELECT Orderkey, storerkey, externorderkey, orderdate, deliverydate, priority,
         c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3, c_address4,
         c_city , c_state, c_zip, ISNULL(buyerpo, ' ' ), ISNULL (notes, ' ' ), ISNULL (invoiceno, ' ' ), ISNULL(notes2, ' '), pmtterm, invoiceamount
         FROM UPLOADORDERHEADER (nolock)
         WHERE MODE = '1'
         AND STATUS = '0'
         SELECT @n_err = @@ERROR
         IF @n_err = 0
         BEGIN
            UPDATE UPLOADORDERHEADER
            SET UPLOADORDERHEADER.Status = '9'
            FROM UPLoadOrderheader (nolock), ORDERS (nolock)
            Where Uploadorderheader.ExternOrderkey = ORDERS.ExternOrderkey
            and Uploadorderheader.Orderkey = ORDERS.Orderkey
            and Uploadorderheader.status = '0'
            AND UPLOADORDERHEADER.Mode = '1'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 65001
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PO (nspImportData_old)"
            END
         END
      ELSE
         BEGIN
            UPDATE UPLOADORDERHEADER
            SET STATUS = '5', REMARKS = '65007: Error Uploading Order Header'
            WHERE status = '0'
            and Mode = '1'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 65007
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PO (nspImportData_old)"
            END
         END
      END -- count1 > 0
   END -- @c_headertable = 'UPLOADORDERHEADER'
   --  --------------------------
   -- DETAIL SECTION FOR MODE = '1'
   --  ---------------------------
   IF @n_continue = 1 OR @n_continue = 2 -- detail section for mode 1
   BEGIN
      IF @c_detailtable = 'UPLOADPODetail'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADPODETAIL (nolock) WHERE MODE = '1' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT 'Inserting PO Detail'
            END
            DECLARE cur_podet1 cursor  FAST_FORWARD READ_ONLY for
            SELECT EXTERNPOKEY, ExternLineNumber
            FROM UPLOADPODETAIL (nolock)
            WHERE MODE = '1' AND STATUS = '0'
            OPEN cur_podet1
            WHILE (1=1)
            BEGIN
               FETCH NEXT FROM cur_podet1 INTO @c_externpokey, @c_externlinenumber
               IF @@FETCH_STATUS <> 0 BREAK
               INSERT INTO PODETAIL (Pokey, POLinenumber,  Storerkey,ExternPokey, ExternLineNo, SKU, SKUDescription, QtyOrdered, UOM, PACKKEY)
               SELECT UD.POkey,
               UD.POLinenumber ,
               UD.Storerkey,
               @c_externpokey,
               @c_externlinenumber,
               UD.SKU,
               SKU.Descr,
               UD.QtyOrdered,
               UD.UOM,
               SKU.Packkey
               FROM UPLOADPODETAIL UD (nolock), SKU (nolock)
               WHERE UD.SKU = SKU.SKU
               AND UD.Storerkey = SKU.Storerkey
               AND UD.MODE = '1'
               AND UD.STATUS = '0'
               AND UD.Externpokey = @c_externpokey
               AND UD.ExternLineNumber = @c_externlinenumber
               SELECT @n_err = @@ERROR
               IF @n_err = 0
               BEGIN
                  -- once inserted, update the status = '9'
                  UPDATE UPLOADPODETAIL
                  SET Status = '9'
                  WHERE MODE = '1'
                  AND STATUS = '0'
                  and Externpokey = @c_externpokey
                  AND ExternLineNumber = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 65001
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPODETAIL(nspImportData_old)"
                  END
               END
            ELSE
               BEGIN
                  UPDATE UPLOADPODETAIL
                  SET STATUS = '5', REMARKS = '65008: Unable to Insert into PODETAIL.Table Error'
                  WHERE MODE = '1' AND STATUS = '0'
                  AND ExternPokey = @c_externpokey
                  and externlinenumber = @c_externlinenumber
                  -- error updating
                  SELECT @n_continue = 3
                  SELECT @n_err = 65008
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PODetail (nspImportData_old)"
               END
            END -- WHILE
            CLOSE cur_podet1
            DEALLOCATE cur_podet1
         END -- count1 > 0
      END -- @detailtable = UPLOADPODETAIL
      -- upload of UPLOADOrderDetail
      IF @c_detailtable = 'UPLOADORDERDETAIL'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADORDERDETAIL (nolock) WHERE MODE = '1' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            DECLARE cur_orddet1 CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT ExternOrderkey, ExternLineNo
            FROM UPLOADORDERDETAIL (NOLOCK)
            WHERE MODE = '1' AND STATUS = '0'
            OPEN cur_orddet1
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_orddet1 INTO @c_externorderkey, @c_externlinenumber
               IF @@FETCH_STATUS <> 0 BREAK
               INSERT INTO ORDERDETAIL (Orderkey, Orderlinenumber, ExternOrderkey, SKU,  Storerkey, Openqty,
               Packkey, UOM, ExternLineno, ExtendedPrice, UnitPrice, Facility)
               SELECT UD.Orderkey,
               UD.OrderLinenumber ,
               @c_externOrderkey,
               UD.SKU,
               UD.Storerkey,
               UD.Openqty,
               SKU.Packkey,
               UD.UOM,
               @c_externlinenumber,
               ISNULL(UD.ExtendedPrice, 0.0 ),
               ISNULL(UD.UnitPrice, 0.0),
               ISNULL(UD.Facility, ' ')
               FROM UPLOADORDERDETAIL UD (nolock), SKU (nolock)
               WHERE UD.SKU = SKU.SKU
               AND UD.Storerkey = SKU.Storerkey
               AND UD.MODE = '1'
               AND UD.STATUS = '0'
               AND UD.ExternOrderkey = @c_externOrderkey
               AND UD.ExternLineNo = @c_externLinenumber
               SELECT @n_err = @@ERROR
               IF @n_err = 0
               BEGIN
                  -- once inserted, update the status = '9'
                  UPDATE UPLOADORDERDETAIL
                  SET Status = '9'
                  WHERE MODE = '1'
                  AND STATUS = '0'
                  AND ExternOrderKey = @c_externorderkey
                  AND ExternLineNo = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 65001
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERDETAIL(nspImportData_old)"
                  END
               END
            ELSE
               BEGIN
                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = '5', REMARKS = '65020: Unable to insert into orderdetail.Table error'
                  WHERE MODE = '1' and STATUS = '0'
                  AND ExternOrderkey = @c_externOrderkey
                  AND ExternLineNo = @c_externlinenumber
                  -- error updating
                  SELECT @n_continue = 3
                  SELECT @n_err = 65020
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into ORDERDetail (nspImportData_old)"
               END
            END
         END -- WHile
      END -- count1 > 0
   END -- @n_continue = 1 for mode 1
   -- --------------------------------------------------------------------------------------------------------------
   -- End of processing for Mode = '1'
   -- --------------------------------------------------------------------------------------------------------------
   -- --------------------------------------------------------------------------------------------------------------
   -- Begin PROCESSING FOR MODE = '2'
   -- --------------------------------------------------------------------------------------------------------------
   IF @n_continue = 1 OR @n_continue = 2 -- for mode 2
   BEGIN
      -- declare cursor for mode = '2', there won't be any documentkey, only externkey. use that to check
      -- process each line, check whether they exists in the original table (based on externkey and externlinenumber)
      -- if exists, update the record, else insert new record.
      IF @c_headertable = 'UPLOADPOHEADER'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADPOHEADER (nolock) WHERE MODE = '2' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            DECLARE cur_poheader CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT ExternPOKey, SellerName, POtype FROM UPLOADPOHEADER (NOLOCK)
            WHERE MODE = '2' and Status = '0'
            OPEN cur_poheader
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_poheader INTO @c_externpokey, @c_sellername, @c_potype
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM UPLOADPOHEADER  (NOLOCK) WHERE ExternPoKey = @c_externPoKey )
               BEGIN
                  UPDATE PO
                  SET POType = @c_potype,
                  SellerName = @c_sellername,
                  trafficcop = NULL
                  WHERE ExternPokey = @c_externpokey
                  SELECT @n_err = @@ERROR
                  IF @n_err = 0
                  BEGIN
                     -- once updated, set status ='9' ,
                     -- nOTE : make sure the externpokey for mode 2 and 3 does not repeat.
                     UPDATE UPLOADPOHEADER
                     SET Status = '9'
                     WHERE ExternPoKey = @c_externPOkey
                  END
               END -- if exists
            ELSE
               BEGIN
                  UPDATE UPLOADPOHEADER
                  SET REMARKS = '65010: ExternPOKEY is not valid or does not exists'
                  WHERE ExternPoKey = @c_externPOkey
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65010
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPOHEADER. Remark column(nspImportData_old)"
                  END
               END
            END -- while
            CLOSE cur_poheader
            DEALLOCATE cur_poheader
         END -- @count1 > 0
      END -- @c_headertable = 'UPLOADPOHEADER'
      IF @c_headertable = 'UPLOADORDERHEADER'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADOrderHEADER (NOLOCK)  WHERE MODE = '2' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            DECLARE cur_Orderheader CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT ExternOrderKey FROM UPLOADOrderHEADER (NOLOCK)
            WHERE MODE = '2' and Status = '0'
            OPEN cur_Orderheader
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_Orderheader INTO @c_externOrderkey
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM UPLOADOrderHEADER (NOLOCK) WHERE ExternOrderKey = @c_externOrderKey )
               BEGIN
                  UPDATE Orders
                  SET 	Orders.c_contact1 = UH.c_contact1,
                  Orders.c_contact2 = UH.c_contact2 ,
                  Orders.c_company = UH.c_company ,
                  Orders.c_address1 = UH.c_address1,
                  Orders.c_address2 = UH.c_address2,
                  Orders.c_address3 = UH.c_address3,
                  Orders.c_address4 = UH.c_address4,
                  Orders.c_city = UH.c_city ,
                  Orders.c_state = UH.c_state ,
                  Orders.c_zip = UH.c_zip,
                  Orders.buyerpo = UH.buyerpo,
                  Orders.notes = UH.notes,
                  Orders.invoiceno = UH.invoiceno,
                  Orders.notes2 =  UH.notes2 ,
                  Orders.pmtterm = UH.pmtterm,
                  Orders.invoiceamount = UH.Invoiceamount ,
                  Orders.trafficcop = NULL
                  FROM Orders (NOLOCK) , UPLOADORDERHEADER UH (NOLOCK)
                  WHERE Orders.ExternOrderkey = UH.ExternOrderkey
                  AND Orders.ExternOrderkey = @c_externOrderkey
                  SELECT @n_err = @@ERROR
                  IF @n_err = 0
                  BEGIN
                     -- once updated, set status ='9' ,
                     -- nOTE : make sure the externOrderkey for mode 2 and 3 does not repeat.
                     UPDATE UPLOADOrderHEADER
                     SET Status = '9'
                     WHERE ExternOrderKey = @c_externOrderkey
                  END
               END -- if exists
            ELSE
               BEGIN
                  UPDATE UPLOADOrderHEADER
                  SET REMARKS = '65021: ExternOrderKEY is not valid or does not exists'
                  WHERE ExternOrderKey = @c_externOrderkey
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65021
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADOrderHEADER. Remark column(nspImOrderrtData)"
                  END
               END
            END -- while
            CLOSE cur_Orderheader
            DEALLOCATE cur_Orderheader
         END -- @count1 > 0      END
      END -- IF @c_headertable = 'UPLOADORDERHEADER'
   END  -- for mode 2 header section
   -- begin detail section for mode 2
   IF @n_continue = 1 OR @n_continue = 2 -- mode 2
   BEGIN
      IF @c_detailtable = 'UPLOADPODETAIL'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADPODETAIL (nolock) WHERE MODE = '2' AND STATUS = '0'
         BEGIN
            DECLARE cur_podetail CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey, ExternPOKEY, ExternLineNumber, SKU, QtyOrdered, UOM
            FROM UPLOADPODETAIL (NOLOCK)
            WHERE MODE = '2'
            AND STATUS = '0'
            OPEN cur_podetail
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_podetail INTO @c_storerkey, @c_externpokey, @c_externlinenumber, @c_sku, @n_QtyOrdered, @c_uom
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM PODETAIL (nolock) WHERE ExternPokey = @c_externPokey AND ExternLineno = @c_externLinenumber
               and QtyReceived > 0 )
               BEGIN
                  UPDATE UPLOADPODETAIL
                  SET REMARKS = '65004: PODetail has been received',
                  status = '5'
                  WHERE Externpokey = @c_externpokey
                  AND Externlinenumber = @c_externlinenumber
                  and Status = '0'
               END
               IF EXISTS (SELECT 1 FROM PODETAIL (nolock) WHERE ExternPokey = @c_externPokey AND ExternLineno = @c_externLinenumber and qtyreceived = 0)
               BEGIN
                  UPDATE PODETAIL
                  SET SKU = @c_sku,
                  QtyOrdered = @n_qtyOrdered,
                  UOM = @c_uom
                  WHERE ExternPokey = @c_externPOkey
                  AND ExternLineNo = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err = 0
                  BEGIN
                     UPDATE UPLOADPODETAIL
                     Set Status = '9'
                     Where ExternPokey = @c_externpokey
                     and externlinenumber = @c_externlinenumber
                     AND Status = '0'
                     AND Mode = '2'
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        -- error updating
                        SELECT @n_continue = 3
                        SELECT @n_err = 65011
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPODETAIL.(nspImportData_old)"
                     END
                  END
               ELSE
                  BEGIN
                     UPDATE UPLOADPODETAIL
                     SET STATUS = '5'
                     WHERE ExternPOKey = @c_externpokey
                     and externlinenumber = @c_externlinenumber
                     AND Status = '0'
                     AND Mode = '2'
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65011
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPODetail. Unable to insert into PODETAIL (nspImportData_old)"
                  END
               END     -- if exists
            END -- while
            CLOSE cur_podetail
            DEALLOCATE cur_podetail
         END -- @count > 0
      END -- @c_detailtable = 'UPLOADPODETAIL'
      IF @c_detailtable = 'UPLOADORDERDETAIL'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADORDERDETAIL (nolock) WHERE MODE = '2' AND STATUS = '0'
         BEGIN
            DECLARE cur_ORDERdetail CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT Storerkey, ExternORDERKEY, ExternLineNo, SKU, UOM
            FROM UPLOADORDERDETAIL (NOLOCK)
            WHERE MODE = '2'
            AND STATUS = '0'
            OPEN cur_ORDERdetail
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_ORDERdetail INTO @c_storerkey, @c_externORDERkey, @c_externlinenumber, @c_sku, @c_uom
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM ORDERDETAIL (nolock) WHERE ExternORDERkey = @c_externORDERkey AND ExternLineno = @c_externLinenumber
               and ShippedQty > 0 )
               BEGIN
                  UPDATE UPLOADORDERDETAIL
                  SET REMARKS = '65014:ORDERDetail has been Shipped',
                  status = '5'
                  WHERE ExternORDERkey = @c_externORDERkey
                  AND Externlineno = @c_externlinenumber
                  and Status = '0'
                  and mode = '2'
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65014
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERDETAIL.(nspImportData_old)"
                  END
               END
               IF EXISTS (SELECT 1 FROM ORDERDETAIL (nolock) WHERE ExternORDERkey = @c_externORDERkey AND ExternLineno = @c_externLinenumber and ShippedQty = 0)
               BEGIN
                  UPDATE ORDERDETAIL
                  SET ORDERDETAIL.SKU = UD.SKU,
                  ORDERDETAIL.OpenQty = UD.OpenQty,
                  ORDERDETAIL.UOM = UD.UOM,
                  ORDERDETAIL.FACILITY = UD.Facility,
                  ORDERDETAIL.ExtendedPrice = ISNULL(UD.ExtendedPrice, 0.0),
                  ORDERDETAIL.Unitprice = ISNULL (UD.UnitPrice, 0.0)
                  FROM ORDERDETAIL (NOLOCK)  , UPLOADORDERDETAIL UD (NOLOCK)
                  WHERE ORDERDETAIL.ExternOrderkey= UD.ExternOrderkey
                  AND ORDERDETAIL.ExternLineno = UD.ExternLineno
                  AND ORDERDETAIL.ExternORDERkey = @c_externORDERkey
                  AND ORDERDETAIL.ExternLineNo = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err = 0
                  BEGIN
                     UPDATE UPLOADORDERDETAIL
                     Set Status = '9'
                     Where ExternORDERkey = @c_externORDERkey
                     and externlineno = @c_externlinenumber
                     AND STATUS = '0'
                     AND MODE = '2'
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        -- error updating
                        SELECT @n_continue = 3
                        SELECT @n_err = 65012
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERDETAIL.(nspImportData_old)"
                     END
                  END
               ELSE
                  BEGIN
                     UPDATE UPLOADORDERDETAIL
                     Set Status = '5', REMARKS = '65015: Unable to Insert into Orderdetail.Table Error'
                     Where ExternORDERkey = @c_externORDERkey
                     and externlineno = @c_externlinenumber
                     AND STATUS = '0'
                     AND MODE = '2'
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65015
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERDetail. Unable to insert into ORDERDETAIL (nspImORDERrtData)"
                  END
               END     -- if exists
            END -- while
            CLOSE cur_ORDERdetail
            DEALLOCATE cur_ORDERdetail
         END -- @count > 0
      END -- if @c_detailtable
   END-- End for mode 2
   -- --------------------------------------------------------------------------------------------------------------
   -- END PROCESSING FOR MODE = '2'
   -- --------------------------------------------------------------------------------------------------------------
   -- --------------------------------------------------------------------------------------------------------------
   -- Begin PROCESSING FOR MODE = '3'
   -- For Deletion, the detail lines have to be deleted before deleting the header.
   -- --------------------------------------------------------------------------------------------------------------
   -- DETAIL SECTION FOR MODE = '3'
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_detailtable = 'UPLOADPODETAIL'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADPODETAIL (nolock) WHERE MODE = '3' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            -- loop through the detail line,
            DECLARE cur_pddelete CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT ExternPOkey , ExternLinenumber from UPLOADPODETAIL (nolock)
            WHERE MODE = '3' AND STATUS = '0'
            OPEN cur_pddelete
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_pddelete INTO @c_externPokey, @c_externlinenumber
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM PO (nolock) WHERE ExternPOKey = @c_externpokey  AND EXTERNSTATUS = '9')
               BEGIN
                  UPDATE UPLOADPODETAIL
                  SET REMARKS = '65016: PO Status has been CLOSED', Status = '5'
                  WHERE MODE = '3' AND STATUS = '0'
                  AND Externpokey = @c_externpokey
                  and Externlinenumber = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65016
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPODETAIL.(nspImportData_old)"
                  END
               END
            ELSE IF EXISTS (SELECT 1 FROM PODETAIL (NOLOCK) WHERE Externpokey = @c_externpokey and Externlineno = @c_externlinenumber and QtyReceived > 0 )
               BEGIN
                  DELETE PODETAIL WHERE ExternPOKey = @c_externPOkey and Externlineno = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65012
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING PODETAIL.(nspImportData_old)"
                  END
               ELSE
                  BEGIN
                     UPDATE UPLOADPODETAIL
                     SET STATUS = '9'
                     WHERE ExternPOKey = @c_externPokey
                     AND ExternLinenumber = @c_externlinenumber
                     AND MODE = '3' AND STATUS = '0'
                     -- delete the header, if there are no details left.
                     SELECT @count1 = COUNT(*) FROM PODETAIL (NOLOCK) WHERE ExternPokey = @c_externpokey
                     IF @count1 <= 0
                     BEGIN
                        DELETE PO
                        WHERE ExternPokey = @c_externpokey
                        IF @n_err <> 0
                        BEGIN
                           -- error updating
                           SELECT @n_continue = 3
                           SELECT @n_err = 65015
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING PO. The rest of the detail lines has been deleted (nspImportData_old)"
                        END
                        IF @n_continue = 1 OR @n_continue = 2
                        BEGIN
                           -- update the uploadpoheader
                           UPDATE UPLOADPOHEADER
                           SET Status = '9', REMARKS = '65017: PODetail has been deleted'
                           WHERE ExternPOKey = @c_externPokey
                           and STATUS = '0' AND MODE = '3'
                           IF @n_err <> 0
                           BEGIN
                              -- error updating
                              SELECT @n_continue = 3
                              SELECT @n_err = 65017
                              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING UPLOADPOHEADER. The rest of the detail lines has been deleted (nspImportData_old)"
                           END
                        END
                     END
                  END
               END
            END -- WHILE
         END -- count1 > 0
      END
      IF @c_detailtable = 'UPLOADORDERDETAIL'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADORDERDETAIL (nolock) WHERE MODE = '3' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            -- loop through the detail line,
            DECLARE cur_pddelete CURSOR  FAST_FORWARD READ_ONLY FOR
            SELECT ExternORDERkey , ExternLineno from UPLOADORDERDETAIL (nolock)
            WHERE MODE = '3' AND STATUS = '0'
            OPEN cur_pddelete
            WHILE (1 = 1)
            BEGIN
               FETCH NEXT FROM cur_pddelete INTO @c_externORDERkey, @c_externlinenumber
               IF @@FETCH_STATUS <> 0 BREAK
               IF EXISTS (SELECT 1 FROM ORDERS (nolock) WHERE ExternORDERKey = @c_externORDERkey  AND STATUS = '9')
               BEGIN
                  UPDATE UPLOADORDERDETAIL
                  SET REMARKS = '65018: ORDERS has been shipped', Status = '5'
                  WHERE MODE = '3' AND STATUS = '0'
                  AND ExternORDERkey = @c_externORDERkey
                  and Externlineno = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65018
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERDETAIL.(nspImportData_old)"
                  END
               END
            ELSE IF EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE ExternORDERkey = @c_externORDERkey and Externlineno = @c_externlinenumber and ShippedQty > 0 )
               BEGIN
                  DELETE ORDERDETAIL WHERE ExternORDERKey = @c_externORDERkey and Externlineno = @c_externlinenumber
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     -- error updating
                     SELECT @n_continue = 3
                     SELECT @n_err = 65019
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING ORDERDETAIL.(nspImportData_old)"
                  END
               ELSE
                  BEGIN
                     UPDATE UPLOADORDERDETAIL
                     SET STATUS = '9'
                     WHERE ExternORDERKey = @c_externORDERkey
                     AND ExternLineno = @c_externlinenumber
                     AND MODE = '3' AND STATUS = '0'
                     -- delete the header, if there are no details left.
                     SELECT @count1 = COUNT(*) FROM ORDERDETAIL (NOLOCK) WHERE ExternORDERkey = @c_externORDERkey
                     IF @count1 <= 0
                     BEGIN
                        DELETE ORDERS
                        WHERE ExternORDERkey = @c_externORDERkey
                        AND Status <> '9'
                        IF @n_err <> 0
                        BEGIN
                           -- error updating
                           SELECT @n_continue = 3
                           SELECT @n_err = 65030
                           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING ORDERS. The rest of the detail lines has been deleted (nspImportData_old)"
                        END
                        IF @n_continue = 1 OR @n_continue = 2
                        BEGIN
                           -- update the uploadORDERheader
                           UPDATE UPLOADORDERHEADER
                           SET Status = '9', REMARKS = '65031: ORDERDetail has been deleted'
                           WHERE ExternORDERKey = @c_externORDERkey
                           and STATUS = '0' AND MODE = '3'
                           IF @n_err <> 0
                           BEGIN
                              -- error updating
                              SELECT @n_continue = 3
                              SELECT @n_err = 65031
                              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error DELETING UPLOADORDERHEADER. The rest of the detail lines has been deleted (nspImportData_old)"
                           END
                        END
                     END
                  END
               END
            END -- WHILE
         END -- count1 > 0
      END
   END -- if @n_continue = 1 or
   -- start of mode 3 -- delete records
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_headertable = 'UPLOADPOHEADER'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADPOHEADER (nolock) WHERE MODE = '3' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            -- do validation checking, make sure the PO Header is not 'CLOSED'
            UPDATE UPLOADPOHEADER
            SET UPLOADPOHEADER.REMARKS = '65032: PO Header has externstatus = CLOSED', UPLOADPOHEADER.STATUS = '5'
            FROM UPLOADPOHEADER (NOLOCK) , PO  (NOLOCK)
            WHERE UPLOADPOHEADER.ExternPOkey = PO.ExternPOkey
            AND PO.ExternStatus = '9'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               -- error updating
               SELECT @n_continue = 3
               SELECT @n_err = 65032
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPOHeader.Mode = '3'.(nspImportData_old)"
            END
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               -- reject the rest as well, coz header sent to Exceed has to have details, if no details, reject
               UPDATE UPLOADPOHEADER
               SET REMARKS = '65033: PO Header does not have any details', STATUS = '5'
               WHERE Status = '0' and mode = '3'
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  -- error updating
                  SELECT @n_continue = 3
                  SELECT @n_err = 65033
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADPOHeader.Mode = '3'.(nspImportData_old)"
               END
            END
         END -- count1 > 0
      END -- headertable = 'UPLOADPOHEADER'
      IF @c_headertable = 'UPLOADORDERHEADER'
      BEGIN
         SELECT @count1 = COUNT(*) FROM UPLOADORDERHEADER (nolock) WHERE MODE = '3' AND STATUS = '0'
         IF @count1 > 0
         BEGIN
            UPDATE UPLOADORDERHEADER
            SET Status = '5', REMARKS = '65034: ORDER has been shipped'
            FROM ORDERS (NOLOCK) , UploadOrderHeader UH (NOLOCK)
            WHERE ORDERS.ExternOrderkey = UH.ExternOrderkey
            AND ORDERS.Status = '9'
            AND UH.Mode = '3' AND UH.STATUS = '0'
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               -- error updating
               SELECT @n_continue = 3
               SELECT @n_err = 65034
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERHEADER.Mode = '3'.(nspImportData_old)"
            END
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               UPDATE UPLOADORDERHEADER
               SET STATUS = '5', REMARKS = '65035: Order header does not have any details deleted'
               WHERE Status = '0' and mode = '3'
               IF @n_err <> 0
               BEGIN
                  -- error updating
                  SELECT @n_continue = 3
                  SELECT @n_err = 65035
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating UPLOADORDERHeader.Mode = '3'.(nspImportData_old)"
               END
            END
         END
      END
   END --n_continue for mode '3' process.
   -- End of Mode = '3'
   -- --------------------------------------------------------------------------------------------------------------
   -- END PROCESSING FOR MODE = '2'
   -- --------------------------------------------------------------------------------------------------------------
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
   execute nsp_logerror @n_err, @c_errmsg, "nspImportData_old"
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