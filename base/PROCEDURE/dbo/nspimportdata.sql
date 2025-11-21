SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspImportData                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspImportData]
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
   , @c_StorerKey NVARCHAR(15)
   , @c_externlinenumber NVARCHAR(20)
   , @c_sku NVARCHAR(20)
   , @c_uom NVARCHAR(10)
   , @n_qtyordered int
   , @c_externorderkey NVARCHAR(20)
   , @c_headflag NVARCHAR(1)
   , @c_detailflag NVARCHAR(1)
   , @n_shippedqty int
   , @c_detexternpokey NVARCHAR(20)
   , @c_pokey NVARCHAR(10)
   , @c_pogroup NVARCHAR(10)
   , @c_mode NVARCHAR(3)
   , @c_packkey NVARCHAR(10)
   , @n_counter int
   , @n_totalrec int
   , @n_errcount int
   , @c_detpokey NVARCHAR(10)
   , @c_detlinenumber NVARCHAR(5)
   , @c_Lottable02 NVARCHAR(18)
   , @c_Lottable02Label NVARCHAR(20)
   , @c_Lottable04Label NVARCHAR(20)
   , @d_Lottable04 datetime

   Declare @n_max int,  @c_maxlineno NVARCHAR(5)

   declare @c_detailexternpokey NVARCHAR(20)
   , @c_detailexternlineno NVARCHAR(20),
   @c_detailsku NVARCHAR(20),
   @c_temppokey NVARCHAR(10),
   @c_temppolineno NVARCHAR(5),
   @c_tempStorerKey NVARCHAR(15),
   @c_temppogroup NVARCHAR(10),
   @c_existpokey NVARCHAR(10),
   @c_skudescr NVARCHAR(45)
   -- ORDERS
   DECLARE @c_orderkey NVARCHAR(10)
   , @c_OrderGroup NVARCHAR(10)
   , @c_detexternOrderkey NVARCHAR(20)
   , @c_externlineno NVARCHAR(10)
   , @c_detorderkey NVARCHAR(10)

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
   WHEN 'PO' THEN 'UPLOADPODETAIL'
   WHEN 'ORDER' THEN 'UPLOADORDERDETAIL'
END
END
IF @b_debug = 1
BEGIN
   select @c_headertable
   Select @c_detailtable
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @c_modulename = 'PO'
   BEGIN
      -- Validation section
      -- WRONG SKU & StorerKey combination
      /** commented out due for performance problem **/
      -- Update UPLOADPODETAIL
      -- SET STATUS = 'A'
      -- WHERE SKU NOT IN ( select sku.sku
      --          FROM UPLOADPODETAIL, SKU
      --    WHERE UPLOADPODETAIL.sku = sku.sku
      -- and UPLOADPODETAIL.StorerKey = sku.StorerKey)
      -- AND STATUS = '0'

      -- equivalent stmt with less performance issue
      -- WALLY: 30apr
      update UPLOADPODETAIL
      set status = 'E' , REMARKS = 'Wrong SKU & StorerKey Combination or SKU Does not exists'
      from UPLOADPODETAIL left outer join sku
      on UPLOADPODETAIL.StorerKey = sku.StorerKey
      and UPLOADPODETAIL.sku = sku.sku
      where sku.sku is null
      and status = '0'

      UPDATE UPLOADPOHEADER
      SET UPLOADPOHEADER.STATUS = 'E',
      UPLOADPOHEADER.REMARKS = 'Detail has Wrong sku & StorerKey combination or SKU Does not exists'
      FROM UPLOADPOHEADER (nolock), UPLOADPODETAIL (nolock)
      WHERE UPLOADPOHEADER.POkey = UPLOADPODETAIL.POKey
      AND UPLOADPODETAIL.Status = 'A'
      AND UPLOADPOHEADER.Status = '0'

      /*
      UPDATE UPLOADPOHEADER
      SET UPLOADPOHEADER.STATUS = 'A'
      FROM UPLOADPOHEADER (nolock), UPLOADPODETAIL (nolock)
      WHERE UPLOADPOHEADER.POGROUP = UPLOADPODETAIL.POGROUP
      AND UPLOADPOHEADER.POkey = UPLOADPODETAIL.POKey
      AND UPLOADPOHEADER.ExternPOKey = UPLOADPODETAIL.ExternPOKey
      AND UPLOADPOHEADER.Mode = UPLOADPODETAIL.Mode
      AND UPLOADPODETAIL.Status = 'A'
      AND UPLOADPOHEADER.Status = '0'

      -- set details related to the wrong sku to 'E', and then administrator will check the sku and update the details back to '0'
      UPDATE UPLOADPODETAIL
      SET UPLOADPODETAIL.Status = 'E', REMARKS = ' '
      FROM UPLOADPOHEADER (NOLOCK), UPLOADPODETAIL (NOLOCK)
      WHERE UPLOADPOHEADER.POGROUP = UPLOADPODETAIL.POGROUP
      AND UPLOADPOHEADER.POkey = UPLOADPODETAIL.POKey
      AND UPLOADPOHEADER.ExternPOKey = UPLOADPODETAIL.ExternPOKey
      AND UPLOADPOHEADER.Mode = UPLOADPODETAIL.Mode
      AND UPLOADPOHEADER.Status = 'A'
      AND UPLOADPODETAIL.Status = '0'
      -- set the rest back to 'E' from 'A'

      UPDATE UPLOADPODETAIL
      Set status = 'E' , REMARKS = 'Wrong SKU & StorerKey Combination or SKU Does not exists'
      WHERE STATUS = 'A'

      UPDATE UPLOADPOHEADER
      SET STATUS = 'E', REMARKS = 'Detail has Wrong sku & StorerKey combination or SKU Does not exists'
      WHERE STATUS = 'A'
      */
      -- end of wrong sku & StorerKey combination.



      -- do sequential processing,
      DECLARE cur_po cursor  FAST_FORWARD READ_ONLY for
      SELECT POKey, Externpokey,POGROUP,  mode, StorerKey, POType, Sellername
      FROM UPLOADPOHEADER (NOLOCK)
      WHERE STATUS = '0' -- and pokey = '0000000039'
      ORDER BY pokey, externpokey, pogroup, mode

      OPEN cur_po

      WHILE (1 = 1) -- modulename = 'PO' Big LoOP
      BEGIN
         FETCH NEXT FROM cur_po INTO @c_pokey, @c_externpokey , @c_pogroup, @c_mode, @c_StorerKey, @c_potype, @c_sellername
         IF @@FETCH_STATUS <> 0 BREAK

         -- MODE = 1
         IF @c_mode = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE ExternPOKey = @c_externpokey)
            BEGIN
               -- existing externpokey , we don't want to fail it, let processing continue.
               -- If exists,
               -- check for details, make sure the lines does not exists,
               -- if does not exists, add it, else reject.

               select @n_errcount = 0
               IF EXISTS (SELECT 1 FROM PO (nolock) WHERE ExternPOKey = @c_externpokey AND ExternStatus = 'CLOSE')
               BEGIN
                  UPDATE UPLOADPODETAIL
                  SET STATUS = 'E', REMARKS = 'PO has been CLOSED'
                  WHERE ExternpOKey = @c_externpokey
                  AND STATUS = '0'
                  AND MODE = '1'
                  AND POGROUP = @c_pogroup

                  UPDATE UPLOADPOHEADER
                  SET STATUS = 'E', REMARKS = 'PO has been CLOSED'
                  WHERE ExternpOKey = @c_externpokey
                  AND STATUS = '0'
                  AND MODE = '1'
                  AND POGROUP = @c_pogroup

               END
            ELSE
               BEGIN
                  DECLARE cur_existdet CURSOR  FAST_FORWARD READ_ONLY FOR
                  SELECT ExternPOkey, ExternLinenumber, SKU, POkey, POlinenumber, StorerKey, pogroup, QtyOrdered, UOM,
                  SerialLot, ExpiryDate
                  FROM UPLOADPODETAIL (NOLOCK)
                  WHERE ExternPOKey = @c_externPOkey
                  AND MODE = @c_mode
                  AND STATUS = '0'

                  OPEN cur_existdet

                  WHILE (1 = 1)
                  BEGIN
                     FETCH NEXT FROM cur_existdet INTO @c_detailexternpokey, @c_detailexternlineno, @c_detailsku, @c_temppokey,
                     @c_temppolineno, @c_tempStorerKey, @c_temppogroup, @n_qtyordered, @c_uom,
                     @c_Lottable02, @d_Lottable04
                     IF @@FETCH_STATUS <> 0 BREAK

                     IF EXISTS (SELECT 1 FROM PODETAIL (NOLOCK) WHERE ExternPOKey = @c_detailexternpokey AND ExternLineno = @c_detailexternlineno )
                     BEGIN
                        -- Error
                        UPDATE UPLOADPODETAIL
                        SET STATUS = 'E', REMARKS = 'ExternLineno duplicated for MODE = 1'
                        WHERE ExternPOkey = @c_detailexternpokey
                        AND ExternLineNumber = @c_detailexternlineno
                        AND POGROUP = @c_temppogroup
                        AND POKey = @c_temppokey
                        AND POLinenumber = @c_temppolineno
                        AND Status = '0'
                        AND MODE = @c_mode

                        SELECT @n_errcount = @n_errcount + 1

                     END
                  ELSE
                     BEGIN
                        -- insert new podetail, use back the existing pokey, and generate a new polinenumber
                        SELECT @c_existpokey = POKEY
                        FROM   PO (NOLOCK)
                        WHERE  ExternPOKey = @c_externpokey
                        -- get the next polinenumber
                        -- Modify By SHONG on 18-Mar-2003
                        -- Found PO line = 00000 after successfully posted.
                        SELECT @n_max = Convert(int, MAX(POLineNumber))
                        FROM   PODETAIL (NOLOCK)
                        WHERE  Externpokey = @c_externPOKey

                        IF @n_max IS NULL OR @n_max = 0
                        SELECT @n_max = 1
                     ELSE
                        SELECT @n_max = @n_max + 1
                        -- End of modification on 18-Mar-2003

                        SELECT @c_maxlineno = RIGHT(dbo.fnc_RTrim(REPLICATE('0', 5) + CONVERT (char(5), @n_max)) , 5)

                        SELECT @c_packkey = PACKKEY, @c_skudescr = Descr,
                        @c_Lottable02Label = Lottable02Label,
                        @c_Lottable04Label = Lottable04Label
                        FROM SKU (NOLOCK)
                        WHERE SKU = @c_detailsku
                        AND StorerKey = @c_TempStorerKey

                        IF @c_Lottable02Label <> 'SERIAL_LOT'
                        SELECT @c_Lottable02 = ''

                        IF  @c_Lottable04Label <> 'EXP_DATE'
                        SELECt @d_Lottable04 = NULL

                        INSERT INTO PODETAIL (POKey, POLinenumber, StorerKey, ExternPOKey, Externlineno, SKU,
                        SKUDESCRIPTION, QtyOrdered, UOM, PACKKEY, Lottable04, Lottable02)
                        VALUES ( @c_existpokey, @c_maxlineno, @c_tempStorerKey, @c_detailexternpokey, @c_detailexternlineno,@c_detailsku,
                        @c_skudescr, @n_qtyordered, @c_uom, @c_packkey, @d_Lottable04, @c_Lottable02 )

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           -- error inserting
                           UPDATE UPLOADPODETAIL
                           SET STATUS = 'E', REMARKS = 'ERROR Inserting into PODETAIL '
                           WHERE ExternPOkey = @c_detailexternpokey
                           AND ExternLineNumber = @c_detailexternlineno
                           AND POGROUP = @c_temppogroup
                           AND POKey = @c_temppokey
                           AND POLinenumber = @c_temppolineno
                           AND Status = '0'
                           AND MODE = @c_mode
                           SELECT @n_errcount = @n_errcount + 1
                        END
                     ELSE
                        BEGIN
                           UPDATE UPLOADPODETAIL
                           SET STATUS = '9', REMARKS = ' '
                           WHERE ExternPOkey = @c_detailexternpokey
                           AND ExternLineNumber = @c_detailexternlineno
                           AND POGROUP = @c_temppogroup
                           AND POKey = @c_temppokey
                           AND POLinenumber = @c_temppolineno
                           AND Status = '0'
                           AND MODE = @c_mode
                        END
                     END -- if exists

                  END -- while
                  CLOSE cur_existdet
                  DEALLOCATE cur_existdet
               END -- if exists
               IF @n_errcount = 0
               BEGIN
                  UPDATE UPLOADPOHEADER
                  SET STATUS = '9', REMARKS = ' '
                  WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup  AND POKEy = @c_pokey
                  AND MODE = @c_mode
                  AND STATUS = '0'
               END
            ELSE
               BEGIN
                  UPDATE UPLOADPOHEADER
                  SET STATUS = 'E', REMARKS = 'There is some errors on detail lines'
                  WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup  AND POkey = @c_pokey
                  AND MODE = @c_mode
                  AND STATUS = '0'
               END
               /*
               UPDATE UPLOADPOHEADER
               SET STATUS = 'E', REMARKS = '65004 : ExternPOkey already exists'
               WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup  AND POKEy = @c_pokey
               AND MODE = @c_mode
               AND STATUS = '0'

               -- update the detail as well,
               UPDATE UPLOADPODETAIL
               SET STATUS = 'E', REMARKS = '65004 : ExternPOKey already exists. Unable to insert into Detail'
               WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup  AND POkey = @c_pokey
               AND MODE = @c_mode
               AND STATUS = '0'
               */
            END
         ELSE
            BEGIN

               INSERT INTO PO (Pokey, ExternPOkey, StorerKey, POType, SellerName)
               SELECT @c_pokey, @c_externpokey, StorerKey, POType, SellerName FROM UPLOADPOHEADER (nolock)
               WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup
               AND MODE = @c_mode  AND POKey = @c_pokey AND STATUS = '0'

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  UPDATE UPLOADPOHEADER
                  SET STATUS = 'E', REMARKS = '65001 : ERROR INSERTING INTO PO'
                  WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup and pokey = @c_pokey
                  AND MODE = @c_mode and Status = '0'
                  -- IF insert into Header fails, fail the detail as well


                  UPDATE UPLOADPODETAIL
                  SET STATUS = 'E', REMARKS = '65001 :Insert into Header Failed. Detail rejected'
                  WHERE ExternPOKey = @c_externpokey AND POGROUp = @c_pogroup and pokey = @c_pokey
                  AND MODE = @c_mode and Status = '0'

                  --  SELECT @n_continue = 3
                  --  SELECT @n_err = 65001
                  --  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PO (nspImportData)"
               END
            ELSE
               BEGIN --insert successful, update the status = '9'
                  UPDATE UPLOADPOHEADER
                  SET STATUS = '9', REMARKS = ''
                  WHERE ExternPOKey = @c_externpokey and POGROUP = @c_pogroup and pokey = @c_pokey AND MODE = @c_mode
                  --                  SELECT @n_err = @@ERROR
                  --                  IF @n_err <> 0
                  --                  BEGIN
                  --                     SELECT @n_continue = 3
                  --                     SELECT @n_err = 65002
                  --                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Updating Status = 9 (nspImportData)"
                  --                 END
                  -- insert the details
                  DECLARE cur_detail CURSOR  FAST_FORWARD READ_ONLY FOR
                  SELECT Externpokey, ExternLinenumber, SKU, POkey, POlinenumber
                  FROM UPLOADPODETAIL (NOLOCK)
                  WHERE ExternPOKey = @c_externpokey
                  AND MODE = @c_mode AND POGROUP = @c_POGROUP
                  AND STATUS = '0' and pokey = @c_pokey
                  ORDER BY POGROUP, ExternPOKey, ExternLinenumber

                  OPEN CUR_Detail

                  WHILE (1 = 1)
                  BEGIN
                     FETCH NEXT FROM cur_detail INTO @c_detexternpokey, @c_externlinenumber, @c_sku, @c_detpokey, @c_detlinenumber
                     IF @@FETCH_STATUS <> 0 BREAK

                     IF EXISTS ( SELECT 1
                     FROM UPLOADPODETAIL UD (nolock), SKU (nolock)
                     WHERE UD.SKU = SKU.SKU
                     AND UD.StorerKey = SKU.StorerKey
                     AND UD.MODE = @c_mode
                     AND UD.STATUS = '0'
                     AND UD.Externpokey = @c_detexternpokey
                     AND UD.ExternLineNumber = @c_externlinenumber
                     AND UD.POGROUP = @c_pogroup
                     AND UD.POkey = @c_detpokey
                     AND UD.POlinenumber = @c_detlinenumber
                     AND UD.StorerKey = @c_StorerKey
                     AND UD.Sku = @c_sku )
                     BEGIN
                        INSERT INTO PODETAIL ( Pokey, POLinenumber,  StorerKey,ExternPokey, ExternLineNo,
                        SKU, SKUDescription, QtyOrdered, UOM, PACKKEY,
                        Lottable04, Lottable02)
                        SELECT UD.POkey,
                        UD.POLinenumber ,
                        UD.StorerKey,
                        @c_detexternpokey,
                        @c_externlinenumber,
                        UD.SKU,
                        SKU.Descr,
                        UD.QtyOrdered,
                        UD.UOM,
                        SKU.Packkey,
                        UD.ExpiryDate,
                        UD.SerialLot
                        FROM UPLOADPODETAIL UD (nolock), SKU (nolock)
                        WHERE UD.SKU = SKU.SKU
                        AND UD.StorerKey = SKU.StorerKey
                        AND UD.MODE = @c_mode
                        AND UD.STATUS = '0'
                        AND UD.Externpokey = @c_detexternpokey
                        AND UD.ExternLineNumber = @c_externlinenumber
                        AND UD.POGROUP = @c_pogroup
                        AND UD.POkey = @c_detpokey
                        AND UD.POlinenumber = @c_detlinenumber
                        AND UD.StorerKey = @c_StorerKey
                        AND UD.SKU = @c_sku

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN -- error occurred,
                           UPDATE UPLOADPODETAIL
                           SET STATUS = 'E', REMARKS = '65003: ERROR INSERTING INTO PODETAIL'
                           WHERE Externpokey = @c_detexternpokey
                           AND Externlinenumber = @c_externlinenumber
                           AND POGROUP = @c_pogroup
                           and status = '0' and mode = @c_mode

                           --                        SELECT @n_continue = 3
                           --                        SELECT @n_err = 65003
                           --                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into PODETAIL(nspImportData)"
                        END
                     ELSE
                        BEGIN -- no errors,
                           UPDATE UPLOADPODETAIL
                           SET STATUS = '9', REMARKS = 'TYPE 1'
                           WHERE ExternPOkey = @c_detexternpokey
                           AND Externlinenumber = @c_externlinenumber
                           AND POGROUP = @c_pogroup AND pokey = @c_detpokey and polinenumber = @c_detlinenumber
                           AND STATUS = '0' AND MODE = @c_mode
                        END
                     END -- if exists
                  END -- while (for cursor detail)
                  CLOSE Cur_detail
                  DEALLOCATE cur_detail
               END

            END -- IF EXISTS

         END -- @c_mode = 1
      ELSE
         IF @c_mode = '2'
         BEGIN
            IF EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE ExternPOKey = @c_externPOKey)
            BEGIN
               UPDATE PO
               SET SellerName = @c_sellername,
               POType = @c_potype
               WHERE ExternPOKey = @c_externPOKey
               -- AND POGROUP = @c_pogroup
               AND ExternStatus <> 'CLOSE' -- ( when status = '9', it's automatically closed )


               SELECT @n_err = @@ERROR
               IF @n_err <> 0

               BEGIN -- error updating POheader

                  UPDATE UPLOADPOHEADER
                  SET STATUS = 'E', REMARKS = '65005 : Unable to Update PO table'
                  WHERE ExternPOKey = @c_externpokey
                  AND POGROUP = @c_pogroup and pokey = @c_pokey
                  AND MODE = @c_mode
                  AND Status = '0'
               END
            ELSE
               BEGIN -- no error
                  UPDATE UPLOADPOHEADER
                  SET STATUS = '9', REMARKS = ''
                  WHERE ExternPOKey = @c_externpokey
                  AND POGROUP = @c_pogroup and pokey = @c_pokey
                  AND MODE = @c_mode
                  AND Status = '0'

                  -- if header successfully updated, try detail
                  DECLARE cur_detailupdate CURSOR  FAST_FORWARD READ_ONLY FOR
                  SELECT Externpokey, ExternLinenumber, SKU, QtyOrdered, 'UOM' = ISNULL(UOM, 'EA'),
                  ExpiryDate,  SerialLot
                  FROM UPLOADPODETAIL (NOLOCK)
                  WHERE ExternPOKey = @c_externpokey
                  AND MODE = @c_mode AND POGROUP = @c_POGROUP
                  AND STATUS = '0' and POKey = @c_pokey
                  ORDER BY POGROUP, ExternPOkey, Externlinenumber

                  OPEN CUR_Detailupdate

                  WHILE (1 = 1)
                  BEGIN
                     FETCH NEXT FROM cur_detailupdate
                     INTO @c_detexternpokey, @c_externlinenumber,@c_sku,  @n_qtyordered, @c_uom,
                     @d_Lottable04, @c_Lottable02

                     IF @@FETCH_STATUS <> 0 BREAK

                     --   Check for podetail status, if qtyreceived > 0 , reject update
                     IF NOT EXISTS (SELECT 1 FROM PODETAIL (NOLOCK)
                     WHERE ExternPOKey = @c_detexternpokey
                     AND ExternLineno = @c_externlinenumber
                     AND QtyReceived > 0 )
                     BEGIN
                        SELECT @c_packkey = PACKKEY, @c_skudescr = Descr,
                        @c_Lottable02Label = Lottable02Label,
                        @c_Lottable04Label = Lottable04Label
                        FROM SKU (NOLOCK)
                        WHERE SKU = @c_sku AND StorerKey = @c_StorerKey

                        IF @c_Lottable02Label <> 'SERIAL_LOT'
                        SELECT @c_Lottable02 = ''

                        IF  @c_Lottable04Label <> 'EXP_DATE'
                        SELECt @d_Lottable04 = NULL


                        UPDATE PODETAIL
                        SET SKU = @c_sku,
                        QtyOrdered = @n_qtyOrdered,
                        UOM = @c_uom,
                        PACKKEY = @c_packkey,
                        Lottable02 = @c_Lottable02,
                        Lottable04 = @d_Lottable04
                        WHERE ExternPOKey = @c_detexternpokey
                        AND ExternLineNo = @c_externlinenumber
                        AND QtyReceived = 0

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN -- error occurred,
                           UPDATE UPLOADPODETAIL
                           SET STATUS = 'E', REMARKS = '65006: ERROR UPDATING PODETAIL'
                           WHERE Externpokey = @c_detexternpokey
                           AND Externlinenumber = @c_externlinenumber
                           AND POGROUP = @c_pogroup AND POKey = @c_pokey
                           and status = '0' and mode = @c_mode

                        END
                     ELSE
                        BEGIN -- no errors,
                           UPDATE UPLOADPODETAIL
                           SET STATUS = '9', REMARKS = 'TYPE 2'
                           WHERE ExternPOkey = @c_detexternpokey
                           AND Externlinenumber = @c_externlinenumber
                           AND POGROUP = @c_pogroup and POKey = @c_pokey
                           AND STATUS = '0' AND MODE = @c_mode
                        END
                     END -- IF EXISTS
                  END -- while (for cursor detail)
                  CLOSE CUR_Detailupdate
                  Deallocate cur_detailupdate

               END
            END -- IF EXISTS
         ELSE
            BEGIN
               UPDATE UPLOADPOHEADER
               SET STATUS = 'E', REMARKS = 'ExternPOKey does not exists. Update is not executed'
               WHERE ExternPOKey = @c_externpokey
               AND POGROUP = @c_pogroup and pokey = @c_pokey
               AND MODE = @c_mode

               UPDATE UPLOADPODETAIL
               SET STATUS = 'E', REMARKS = 'ExternPOKey does not exists. Update is not executed'
               where ExternPOKey = @c_externpokey
               AND POGROUP = @c_pogroup and pokey = @c_pokey
               AND MODE = @c_mode
            END

         END -- c_mode = '2'
      ELSE
         IF @c_mode = '3'
         BEGIN

            IF NOT EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE ExternPOKey = @c_externpokey and ExternStatus = 'CLOSE')
            BEGIN
               -- for  mode = 3 (DELETE), Delete the details first, and if all details has been deleted, delete the header.
               DECLARE cur_deletedetail CURSOR  FAST_FORWARD READ_ONLY FOR
               SELECT ExternPOKey, ExternLinenumber, POkey, POlinenumber
               FROM UPLOADPODETAIL (NOLOCK)
               WHERE Externpokey = @c_externpokey
               AND POGROUP = @c_pogroup
               AND MODE = @c_mode
               AND STATUS = '0'
               AND POKey = @c_pokey
               ORDER BY POGROUP, ExternPOKey, ExternLinenumber

               OPEN cur_deletedetail
               WHILE (1=1)
               BEGIN
                  FETCH NEXT FROM cur_deletedetail INTO @c_detexternpokey, @c_externlinenumber, @c_detpokey, @c_detlinenumber
                  IF @@FETCH_STATUS <> 0 BREAK

                  IF NOT EXISTS (SELECT 1 FROM PODETAIL (NOLOCK) WHERE ExternPOkey = @c_detexternpokey AND ExternlineNo = @c_externlinenumber
                  AND QtyReceived > 0)
                  BEGIN
                     DELETE PODETAIL
                     WHERE ExternPOkey = @c_detexternpokey
                     AND ExternLineNo = @c_externlinenumber
                     AND QtyReceived = 0
                     SELECT @n_err = @@ERROR
                     SELECT @n_cnt = @@ROWCOUNT
                     IF @n_cnt > 0 AND @n_err = 0
                     BEGIN
                        UPDATE UPLOADPODETAIL
                        SET STATUS = '9', REMARKS = 'type 3'
                        WHERE ExternPOkey = @c_detexternpokey
                        AND ExternLinenumber = @c_externlinenumber
                        and POGROUP = @c_pogroup and POKey = @c_pokey
                        AND MODE = @c_mode
                        AND STATUS = '0'
                     END
                  ELSE
                     BEGIN
                        UPDATE UPLOADPODETAIL
                        SET STATUS = 'E', REMARKS = '65009 : Unable to delete PODETAIL'
                        WHERE Externpokey = @c_detexternpokey
                        AND Externlinenumber = @c_externlinenumber
                        and POGROUP = @c_pogroup and pokey = @c_pokey
                        AND MODE = @c_mode
                        AND STATUS = '0'
                     END
                  END
               ELSE
                  BEGIN
                     UPDATE UPLOADPODETAIL
                     SET STATUS = 'E', REMARKS = '65010 : POdetail has QtyReceived > 0'
                     WHERE Externpokey = @c_detexternpokey
                     AND Externlinenumber = @c_externlinenumber
                     and POGROUP = @c_pogroup and pokey = @c_pokey
                     AND MODE = @c_mode
                     AND STATUS = '0'
                  END


                  /*
                  SELECT @count1 = COUNT(*) FROM UPLOADPODETAIL (nolock) WHERE ExternPOKey = @c_externpokey
                  AND POGROUP = @c_pogroup and POKey = @c_pokey and MODE = @c_mode and Status = 'E'

                  IF @count1 > 0
                  BEGIN
                  UPDATE UPLOADPOHEADER
                  SET STATUS = 'E', REMARKS = '65011: Error Occured in Detail'
                  WHERE Externpokey = @c_detexternpokey
                  AND POGROUP = @c_pogroup and pokey = @c_pokey
                  and MODE = @c_mode
                  AND Status = '0'
                  END -- count1 > 0
                  ELSE
                  IF @count1 = 0
                  BEGIN
                  UPDATE UPLOADPOHEADER
                  SET STATUS = '9', REMARKS = ' '
                  WHERE Externpokey = @c_detexternpokey
                  AND POGROUP = @c_pogroup and pokey = @c_pokey
                  and MODE = @c_mode
                  AND Status = '0'

                  END
                  */
               END -- End while (cur_deletedetail)
               CLOSE cur_deletedetail
               DEALLOCATE cur_deletedetail
               -- after delete detail, count the balance of details, if no more detail lines, then delete the header
               SELECT @count1 = COUNT(*) FROM PODETAIL (NOLOCK) WHERE ExternPOKey = @c_externPOKey
               IF @count1 = 0
               BEGIN
                  DELETE PO
                  WHERE ExternPOKey = @c_detexternPOkey
                  SELECT @n_err = @@ERROR
                  SELECT @n_cnt = @@ROWCOUNT

                  IF @n_err = 0 AND @n_cnt > 0
                  BEGIN
                     UPDATE UPLOADPOHEADER
                     SET Status = '9', REMARKS = ''
                     WHERE Externpokey = @c_detexternpokey
                     AND POGROUP = @c_pogroup and pokey = @c_detpokey
                     and MODE = @c_mode
                     AND Status = '0'
                  END
               END


            END -- if not exists
         ELSE
            BEGIN -- po has been closed
               UPDATE UPLOADPOHEADER
               SET STATUS = 'E', REMARKS = '65012: PO has been CLOSED'
               WHERE Externpokey = @c_detexternpokey
               AND POGROUP = @c_pogroup and pokey = @c_pokey
               and MODE = @c_mode
               AND Status = '0'

               UPDATE UPLOADPODETAIL
               SET STATUS = 'E', REMARKS = '65012: PO has been CLOSED'
               WHERE Externpokey = @c_detexternpokey
               AND POGROUP = @c_pogroup and pokey = @c_pokey
               and MODE = @c_mode
               AND Status = '0'
            END -- po has been closed
         END -- for mode = 3
      ELSE
         BEGIN -- everything fails
            UPDATE UPLOADPOHEADER
            SET STATUS = 'E', REMARKS = '65013 : Invalid MODE ,  ExternOrderkey or Status'
            WHERE ExternPOkey IS NULL
            OR STATUS IS NULL
            OR MODE IS NULL

            UPDATE UPLOADPODETAIL
            SET STATUS = 'E', REMARKS = '65014 : Invalid MODE, ExternOrderkey or status'
            WHERE  ExternPOkey IS NULL
            OR STATUS IS NULL
            OR MODE IS NULL
         END -- for all other reasons

         SELECT @count1 = COUNT(*) FROM UPLOADPOHEADER (NOLOCK) WHERE ExternPOkey = @c_externpokey and POGROUP = @c_pogroup and mode = @c_mode
         IF @count1 > 0
         BEGIN
            SELECT @n_counter = @n_counter + 1
         END
         SELECT @count1  = COUNT(*) FROM UPLOADPOHEADER (NOLOCK) WHERE ExternPOkey = @c_externpokey and POGROUP = @c_pogroup and mode = @c_mode
         IF @count1 > 0
         BEGIN
            SELECT @n_counter = @n_counter + 1
         END

      END -- while --modulename = 'PO', big LOOP
      CLOSE cur_po
      DEALLOCATE cur_po

      /*
      DECLARE cur_updateall CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT ExternPOkey, Externlinenumber, POkey, POlinenumber, POGROUP, MODE, REMARKS
      FROM UPLOADPODETAIL (NOLOCK)
      WHERE STATUS = 'A'

      OPEN cur_updateall
      WHILE (1 = 1)
      BEGIN
      FETCH NEXT FROM cur_updateall INTO @c_externpokey, @c_externlinenumber, @c_pokey, @c_polinenumber, @c_pogroup, @c_mode, @c_remarks
      IF @@FETCH_STATUS <> 0 BREAK

      UPDATE UPLOADPOHEADER
      SET STATUS = 'E', REMARKS = 'DETAIL ERROR ' + @c_remarks
      WHERE ExternPOKey = @c_externPOKey
      AND POKey = @c_pokey
      AND POGROUP = @c_pogroup
      AND MODE = @c_mode
      AND Status = '0'
      END   -- while
      */
   END -- modulename = 'PO'
   -- ------------------------------------------------------------------
   -- End of MODULENAME = 'PO'
   -- ------------------------------------------------------------------
   IF @c_modulename = 'Order'
   BEGIN
      -- Validation section
      -- start of wrong sku & StorerKey combination.
      UPDATE UPLOADORDERDETAIL
      SET status = 'E', remarks = 'Wrong SKU & StorerKey Combination or SKU Does not exists'
      FROM UPLOADORDERDETAIL (nolock) LEFT OUTER JOIN sku (nolock)
      ON UPLOADORDERDETAIL.StorerKey = sku.StorerKey
      AND UPLOADORDERDETAIL.sku = sku.sku
      AND UPLOADORDERDETAIL.status = '0'
      AND UPLOADORDERDETAIL.StorerKey not in ('C4LGTH','GTH','TRT')
      WHERE sku.sku = NULL

      UPDATE UPLOADORDERHEADER
      SET status = 'E', remarks = 'Detail has Wrong sku & StorerKey combination or SKU Does not exists'
      FROM UPLOADORDERHEADER h (nolock) INNER JOIN UPLOADORDERDETAIL d (nolock)
      ON h.orderkey = d.orderkey
      AND h.StorerKey not in ('C4LGTH','GTH','TRT')
      AND d.status = 'E'
      AND h.status = '0'
      -- end of wrong sku & StorerKey combination.

      -- do sequential processing,
      DECLARE cur_Order cursor  FAST_FORWARD READ_ONLY for
      SELECT OrderKey, ExternOrderkey,OrderGroup,  mode, StorerKey
      FROM UPLOADORDERHEADER (NOLOCK)
      WHERE STATUS = '0'
      and StorerKey not in ('C4LGTH','GTH','TRT')

      OPEN cur_Order

      WHILE (1 = 1) -- modulename = 'Order' Big LoOP
      BEGIN
         FETCH NEXT FROM cur_Order INTO @c_Orderkey, @c_externOrderkey , @c_OrderGroup, @c_mode, @c_StorerKey
         IF @@FETCH_STATUS <> 0 BREAK

         -- MODE = 1
         IF @c_mode = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_externOrderkey)
            BEGIN --existing externOrderkey , we don't want to fail it, let processing continue.
               UPDATE UPLOADORDERHEADER
               SET STATUS = 'E', REMARKS = '65004 : ExternOrderkey already exists'
               WHERE OrderKEy = @c_Orderkey
               AND STATUS = '0'
               -- update the detail as well,
               UPDATE UPLOADORDERDETAIL
               SET STATUS = 'E', REMARKS = '65004 : ExternOrderKey already exists. Unable to insert into Detail'
               WHERE Orderkey = @c_Orderkey
               AND STATUS = '0'
            END
         ELSE
            BEGIN -- does not exists
               INSERT INTO ORDERS (Orderkey, ExternOrderkey,StorerKey,Orderdate, Deliverydate,
               Priority, c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3, c_address4,
               c_city, c_state, c_zip, buyerpo, notes,invoiceno,  notes2, pmtterm, invoiceamount , ROUTE,Facility,
               Type)
               SELECT @c_Orderkey, @c_externOrderkey, UPLOADORDERHEADER.StorerKey, Orderdate, Deliverydate,
               Priority, c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3, c_address4,
               c_city, c_state, c_zip, buyerpo, notes,invoiceno,UPLOADORDERHEADER.notes2, pmtterm, invoiceamount ,
               ISNULL (ROUTE , '99'),STORER.Facility, ISNULL(UPLOADORDERHEADER.Type, '0')
               FROM UPLOADORDERHEADER (nolock), STORER(nolock)
               WHERE ExternOrderKey = @c_externOrderkey and OrderGroup = @c_OrderGroup
               AND MODE = @c_mode  AND OrderKey = @c_Orderkey AND UPLOADORDERHEADER.STATUS = '0'
               AND STORER.StorerKey=@c_StorerKey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  UPDATE UPLOADORDERHEADER
                  SET STATUS = 'E', REMARKS = '65001 : ERROR INSERTING INTO Order'
                  WHERE ExternOrderKey = @c_externOrderkey and OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
                  AND MODE = @c_mode and Status = '0'
                  -- IF insert into Header fails, fail the detail as well

                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = 'E', REMARKS = '65001 :Insert into Header Failed. Detail rejected'
                  WHERE ExternOrderKey = @c_externOrderkey AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
                  AND MODE = @c_mode and Status = '0'
               END
            ELSE
               BEGIN --insert successful, update the status = '9'
                  UPDATE UPLOADORDERHEADER
                  SET STATUS = '9', REMARKS = ''
                  WHERE ExternOrderKey = @c_externOrderkey and OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey AND MODE = @c_mode

                  select @c_detlinenumber   = ''
                  while (2=2)
                  begin
                     set rowcount 1
                     select @c_detlinenumber = orderlinenumber
                     from UPLOADORDERDETAIL (nolock)
                     where orderlinenumber > @c_detlinenumber
                     and orderkey = @c_orderkey
                     order by orderlinenumber

                     if @@rowcount = 0 break

                     set rowcount 0
                     INSERT INTO ORDERDETAIL ( Orderkey, Orderlinenumber, StorerKey, ExternOrderkey, ExternLineno,
                     SKU, Packkey, Openqty,UOM, ExtendedPrice, UnitPrice, Facility, Lottable02, Lottable04 )
                     SELECT UD.Orderkey,
                     UD.OrderLinenumber ,
                     UD.StorerKey,
                     UD.externorderkey,
                     UD.ExternLineno,
                     UD.SKU,
                     SKU.Packkey,
                     UD.OpenQty,
                     ISNULL(UD.UOM, 'EA'),
                     UD.ExtendedPrice,
                     UD.UnitPrice,
                     ISNULL (UD.Facility, ' '),
                     CASE WHEN SKU.Lottable02Label = 'SERIAL_LOT' THEN
                     ISNULL(UD.Lottable02, '')
                  ELSE
                     ''
                  END,
                  CASE WHEN SKU.Lottable04Label = 'EXP_DATE' THEN
                  UD.Lottable04
               ELSE
                  NULL
               END
               FROM UPLOADORDERDETAIL UD (nolock), SKU (nolock)
               WHERE UD.SKU = SKU.SKU
               AND UD.StorerKey = SKU.StorerKey
               AND UD.STATUS = '0'
               AND UD.Orderkey = @c_orderkey
               AND UD.Orderlinenumber = @c_detlinenumber
            end -- while (2=2)
            set rowcount 0

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN -- error occurred,
               UPDATE UPLOADORDERDETAIL
               SET STATUS = 'E', REMARKS = '65003: ERROR INSERTING INTO ORDERDETAIL'
               WHERE Orderkey = @c_orderkey
               AND Orderlinenumber = @c_detlinenumber
            END
         ELSE
            BEGIN -- no errors,
               UPDATE UPLOADORDERDETAIL
               SET STATUS = '9', REMARKS = 'TYPE 1'
               WHERE Orderkey = @c_orderkey
               AND Orderlinenumber = @c_detlinenumber
            END
         END --insert successful, update the status = '9'
      END -- does not exists
   END -- @c_mode = 1
ELSE
   IF @c_mode = '2'
   BEGIN
      IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_externOrderKey)
      BEGIN
         UPDATE ORDERS
         SET ORDERS.OrderDate = OH.Orderdate,
         ORDERS.DeliveryDate = OH.DeliveryDate,
         ORDERS.Priority = OH.Priority,
         ORDERS.c_contact1 = OH.c_contact1,
         ORDERS.c_contact2 = OH.c_contact2,
         ORDERS.c_company = OH.C_company,
         ORDERS.c_address1 = OH.C_Address1,
         ORDERS.c_address2 = OH.C_Address2,
         ORDERS.c_address3 = OH.C_Address3,
         ORDERS.c_address4 = OH.C_Address4,
         ORDERS.c_city = OH.C_city,
         ORDERS.c_state = ISNULL(OH.c_state,' '),
         ORDERS.c_zip = ISNULL (OH.c_zip,' '),
         ORDERS.buyerPO = ISNULL (OH.BuyerPO, ' '),
         ORDERS.Notes = ISNULL (OH.Notes, ' ' ),
         ORDERS.Invoiceno = ISNULL (OH.InvoiceNO, ' ' ),
         ORDERS.Notes2 = ISNULL (OH.Notes2, ' ' ),
         ORDERS.pmtterm = ISNULL (OH.pmtterm, ' '),
         ORDERS.Invoiceamount = OH.Invoiceamount ,
         ORDERS.Route = ISNULL(OH.Route, '99'),
         ORDERS.Facility = (STORER.Facility),
                  ORDERS.Trafficcop = null,
         ORDERS.Type = CASE WHEN dbo.fnc_RTrim(OH.Type) IS NULL Then ORDERS.Type
      ELSE OH.Type
      END
      FROM ORDERS (nolock), UPLOADORDERHEADER OH (nolock), STORER(nolock)
      WHERE ORDERS.ExternOrderkey = OH.ExternOrderkey
      AND ORDERS.ExternOrderKey = @c_externOrderKey
      -- AND OrderGroup = @c_OrderGroup
      AND ORDERS.SOStatus <> 'CLOSE' -- ( when status = '9', it's automatically closed )
      AND OH.ExternOrderkey = @c_externOrderkey
      AND STORER.StorerKey=@c_StorerKey
      AND OH.Status = '0'
      AND OH.Mode = @c_mode
      AND OH.OrderGroup = @c_OrderGroup

      SELECT @n_err = @@ERROR
      IF @n_err <> 0

      BEGIN -- error updating Orderheader

         UPDATE UPLOADORDERHEADER
         SET STATUS = 'E', REMARKS = '65005 : Unable to Update Order table'
         WHERE ExternOrderKey = @c_externOrderkey
         AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
         AND MODE = @c_mode
         AND Status = '0'
      END
   ELSE
      BEGIN -- no error
         UPDATE UPLOADORDERHEADER
         SET STATUS = '9', REMARKS = ''
         WHERE ExternOrderKey = @c_externOrderkey
         AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
         AND MODE = @c_mode
         AND Status = '0'

         -- if header successfully updated, try detail
         DECLARE cur_ORDERDETAILupdate CURSOR  FAST_FORWARD READ_ONLY FOR
         SELECT ExternOrderkey, ExternLineno, SKU, OPENQTY, 'UOM' = ISNULL(UOM, 'EA'),
         Lottable02, Lottable04
         FROM UPLOADORDERDETAIL (NOLOCK)
         WHERE ExternOrderKey = @c_externOrderkey
         AND MODE = @c_mode AND OrderGroup = @c_OrderGroup
         AND STATUS = '0' and OrderKey = @c_Orderkey
         ORDER BY OrderGroup, ExternOrderkey, ExternLineno

         OPEN cur_ORDERDETAILupdate

         WHILE (1 = 1)
         BEGIN
            FETCH NEXT FROM cur_ORDERDETAILupdate
            INTO @c_detexternOrderkey, @c_ExternLineno,@c_sku,  @n_qtyordered, @c_uom, @c_Lottable02, @d_Lottable04

            IF @@FETCH_STATUS <> 0 BREAK

            --   Check for ORDERDETAIL status, if qtyreceived > 0 , reject update
            IF NOT EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK)
            WHERE ExternOrderKey = @c_detexternOrderkey
            AND ExternLineno = @c_ExternLineno
            AND Shippedqty > 0 )
            BEGIN
               SELECT @c_packkey = PACKKEY, @c_skudescr = Descr,
               @c_Lottable02Label = Lottable02Label,
               @c_Lottable04Label = Lottable04Label
               FROM SKU (NOLOCK)
               WHERE SKU = @c_sku AND StorerKey = @c_StorerKey

               IF @c_Lottable02Label <> 'SERIAL_LOT'
               SELECT @c_Lottable02 = ''

               IF  @c_Lottable04Label <> 'EXP_DATE'
               SELECt @d_Lottable04 = NULL

               UPDATE ORDERDETAIL
               SET SKU = @c_sku,
               Openqty = @n_qtyOrdered,
               UOM = @c_uom,
               PACKKEY = @c_packkey,
               Lottable02 = @c_Lottable02,
               Lottable04 = @d_Lottable04
               WHERE ExternOrderKey = @c_detexternOrderkey
               AND ExternLineNo = @c_ExternLineno
               AND ShippedQty = 0

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN -- error occurred,
                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = 'E', REMARKS = '65006: ERROR UPDATING ORDERDETAIL'
                  WHERE ExternOrderkey = @c_detexternOrderkey
                  AND ExternLineno = @c_ExternLineno
                  AND OrderGroup = @c_OrderGroup AND OrderKey = @c_Orderkey
                  and status = '0' and mode = @c_mode

                  --  SELECT @n_continue = 3
                  --  SELECT @n_err = 65003
                  --  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error Inserting into ORDERDETAIL(nspImOrderrtData)"
               END
            ELSE
               BEGIN -- no errors,
                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = '9', REMARKS = 'TYPE 2'
                  WHERE ExternOrderkey = @c_detexternOrderkey
                  AND ExternLineno = @c_ExternLineno
                  AND OrderGroup = @c_OrderGroup and OrderKey = @c_Orderkey
                  AND STATUS = '0' AND MODE = @c_mode
               END
            END -- IF EXISTS
         END -- while (for cursor detail)
         CLOSE cur_ORDERDETAILupdate
         Deallocate cur_ORDERDETAILupdate

      END
   END -- IF EXISTS
ELSE
   BEGIN
      UPDATE UPLOADORDERHEADER
      SET STATUS = 'E', REMARKS = 'ExternOrderKey does not exists. Update is not executed'
      WHERE ExternOrderKey = @c_externOrderkey
      AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
      AND MODE = @c_mode

      UPDATE UPLOADORDERDETAIL
      SET STATUS = 'E', REMARKS = 'ExternOrderKey does not exists. Update is not executed'
      where ExternOrderKey = @c_externOrderkey
      AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
      AND MODE = @c_mode
   END

END -- c_mode = '2'
ELSE
   IF @c_mode = '3'
   BEGIN

      IF NOT EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE ExternOrderKey = @c_externOrderkey and SOStatus = 'CLOSE')
      BEGIN
         --
         -- for  mode = 3 (DELETE), Delete the details first, and if all details has been deleted, delete the header.
         DECLARE CUR_DELORDERDETAIL CURSOR  FAST_FORWARD READ_ONLY FOR
         SELECT ExternOrderKey, ExternLineno, Orderkey, Orderlinenumber
         FROM UPLOADORDERDETAIL (NOLOCK)
         WHERE ExternOrderkey = @c_externOrderkey
         AND OrderGroup = @c_OrderGroup
         AND MODE = @c_mode
         AND STATUS = '0'
         AND OrderKey = @c_Orderkey
         ORDER BY OrderGroup, ExternOrderKey, ExternLineno

         OPEN CUR_DELORDERDETAIL
         WHILE (1=1)
         BEGIN
            FETCH NEXT FROM CUR_DELORDERDETAIL INTO @c_detexternOrderkey, @c_ExternLineno, @c_detOrderkey, @c_detlinenumber
            IF @@FETCH_STATUS <> 0 BREAK

            IF NOT EXISTS (SELECT 1 FROM ORDERDETAIL (NOLOCK) WHERE ExternOrderkey = @c_detexternOrderkey AND ExternlineNo = @c_ExternLineno
            AND ShippedQty > 0)
            BEGIN
               DELETE ORDERDETAIL
               WHERE ExternOrderkey = @c_detexternOrderkey
               AND ExternLineNo = @c_ExternLineno
               AND ShippedQty = 0
               SELECT @n_err = @@ERROR
               SELECT @n_cnt = @@ROWCOUNT
               IF @n_cnt > 0 AND @n_err = 0
               BEGIN
                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = '9', REMARKS = 'type 3'
                  WHERE ExternOrderkey = @c_detexternOrderkey
                  AND ExternLineno = @c_ExternLineno
                  and OrderGroup = @c_OrderGroup and OrderKey = @c_Orderkey
                  AND MODE = @c_mode
                  AND STATUS = '0'
               END
            ELSE
               BEGIN
                  UPDATE UPLOADORDERDETAIL
                  SET STATUS = 'E', REMARKS = '65009 : Unable to delete ORDERDETAIL'
                  WHERE ExternOrderkey = @c_detexternOrderkey
                  AND ExternLineno = @c_ExternLineno
                  and OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
                  AND MODE = @c_mode
                  AND STATUS = '0'
               END
            END
         ELSE
            BEGIN
               UPDATE UPLOADORDERDETAIL
               SET STATUS = 'E', REMARKS = '65010 : ORDERDETAIL has QtyReceived > 0'
               WHERE ExternOrderkey = @c_detexternOrderkey
               AND ExternLineno = @c_ExternLineno
               and OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
               AND MODE = @c_mode
               AND STATUS = '0'
            END


         END -- End while (CUR_DELORDERDETAIL)
         CLOSE CUR_DELORDERDETAIL
         DEALLOCATE CUR_DELORDERDETAIL
         -- after delete detail, count the balance of details, if no more detail lines, then delete the header
         SELECT @count1 = COUNT(*) FROM ORDERDETAIL (NOLOCK) WHERE ExternOrderKey = @c_externOrderKey
         IF @count1 = 0
         BEGIN
            DELETE ORDERS
            WHERE ExternOrderKey = @c_detexternOrderkey
            SELECT @n_err = @@ERROR
            SELECT @n_cnt = @@ROWCOUNT

            IF @n_err = 0 AND @n_cnt > 0
            BEGIN
               UPDATE UPLOADORDERHEADER
               SET Status = '9', REMARKS = ''
               WHERE ExternOrderkey = @c_detexternOrderkey
               AND OrderGroup = @c_OrderGroup and Orderkey = @c_detOrderkey
               and MODE = @c_mode
               AND Status = '0'
            END
         END


      END -- if not exists
   ELSE
      BEGIN -- Order has been closed
         UPDATE UPLOADORDERHEADER
         SET STATUS = 'E', REMARKS = '65012: Order has been CLOSED'
         WHERE ExternOrderkey = @c_detexternOrderkey
         AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
         and MODE = @c_mode
         AND Status = '0'

         UPDATE UPLOADORDERDETAIL
         SET STATUS = 'E', REMARKS = '65012: Order has been CLOSED'
         WHERE ExternOrderkey = @c_detexternOrderkey
         AND OrderGroup = @c_OrderGroup and Orderkey = @c_Orderkey
         and MODE = @c_mode
         AND Status = '0'
      END -- Order has been closed
   END -- for mode = 3
ELSE
   BEGIN -- everything fails
      UPDATE UPLOADORDERHEADER
      SET STATUS = 'E', REMARKS = '65013 : Invalid MODE ,  ExternOrderkey or Status'
      WHERE ExternOrderkey IS NULL
      OR STATUS IS NULL
      OR MODE IS NULL

      UPDATE UPLOADORDERDETAIL
      SET STATUS = 'E', REMARKS = '65014 : Invalid MODE, ExternOrderkey or status'
      WHERE  ExternOrderkey IS NULL
      OR STATUS IS NULL
      OR MODE IS NULL
   END -- for all other reasons

   SELECT @count1 = COUNT(*) FROM UPLOADORDERHEADER (NOLOCK) WHERE ExternOrderkey = @c_externOrderkey and OrderGroup = @c_OrderGroup and mode = @c_mode
   IF @count1 > 0
   BEGIN
      SELECT @n_counter = @n_counter + 1
   END
   SELECT @count1  = COUNT(*) FROM UPLOADORDERHEADER (NOLOCK) WHERE ExternOrderkey = @c_externOrderkey and OrderGroup = @c_OrderGroup and mode = @c_mode
   IF @count1 > 0
   BEGIN
      SELECT @n_counter = @n_counter + 1
   END

END -- while --modulename = 'Order', big LOOP
CLOSE cur_Order
DEALLOCATE cur_Order
END -- modulename = 'Order'
END -- @n_continue = 1
-- ---------------
   -- Records is processed sequentially based on the running number
-- ------------------------
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
   execute nsp_logerror @n_err, @c_errmsg, "nspImportData"
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