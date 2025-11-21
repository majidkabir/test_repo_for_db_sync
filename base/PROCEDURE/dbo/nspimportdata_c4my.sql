SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* SP     : nspImportData_C4MY                                           */
/* Creation Date: 25 Nov 2004                                            */
/* Copyright: IDS                                                        */
/* Written by:   YTWan (Copy FROM nspImportData)                         */
/*                                                                       */
/* Purpose: Upload SO & PO data to WMS System                            */
/*                                                                       */
/* Input Parameters:                                                     */
/*                                                                       */
/* Output Parameters:                                                    */
/*                                                                       */
/* Return Status:                                                        */
/*                                                                       */
/* Usage:   C4 PO & SO Interface Import                                  */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: C4 EC IDSC4PO &  IDSC4ORD                                  */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Purposes                                        */
/* 17 Feb 2005  YTWan    FBR 32265 Link for C4 Flow Thru                 */
/* 04 Mar 2005  YTWan    FBR 32746 Review Current Xdock Process          */
/*                       -- Auto Populate PO to ASN                      */
/* 17-Mar-2005  YTWan    FBR33101: Split Order. 1 Order to 1 PO          */
/* 25-Apr-2005  June     SOS34830, bug fixed insert ReceiptDetail        */
/*                       error                                           */
/* 01-Nov-2005 Shong     FBR42502 - OrderLines Missing                   */
/* 19-Feb-2008 Shong     Prevent XDOCK SO to import to Orders Table      */
/*                       before PO imported to WMS.                      */
/* 02-SEP-2008 Audrey      SOS# 114709:priority = consigneekey for Orders*/
/* 16-Jun-2009 Rick Liew SOS96737 - Remove C4LGMY Type Hardcoding        */
/* 17-jun-2009 Shong     To make the Store Order# AND Storer Id mandatory*/
/*                       when type = Flowthru                            */
/* 18-Jun-2009 Rick Liew Add the StorerKey checking (Rick Liew01)        */
/* 26-Jun-2009 Rick Liew Not to auto populate ASN for POType = 10,10A    */
/*                       (Rick Liew02)                                   */
/* 10-Apr-2014 Audrey    SOS308367 - Ensure ExternPOKey in Orders is not */
/*                                   NULL.                               */
/*************************************************************************/

CREATE PROC [dbo].[nspImportData_C4MY]
     @c_modulename NVARCHAR(10)
   , @b_Success    INT           OUTPUT
   , @n_err        INT           OUTPUT
   , @c_errmsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue         INT
         , @n_starttcnt        INT         -- Holds the current transaction count
         , @n_cnt              INT               -- Holds @@ROWCOUNT after certain operations
         , @c_preprocess       NVARCHAR(250)  -- preprocess
         , @c_pstprocess       NVARCHAR(250)  -- post process
         , @n_err2             INT             -- For Additional Error Detection
         , @b_debug            INT             -- Debug: 0 - OFF, 1 - show all, 2 - map
         , @c_headertable      NVARCHAR(40)
         , @c_detailtable      NVARCHAR(40)
         , @n_tablecounter     INT
         , @count1             INT
         , @string             NVARCHAR(250)
         , @c_ExternPOKey      NVARCHAR(20)
         , @c_sellername       NVARCHAR(45)
         , @c_potype           NVARCHAR(10)
         , @c_StorerKey        NVARCHAR(15)
         , @c_ConsigneeKey     NVARCHAR(15)
         , @c_externLineNumber NVARCHAR(20)
         , @c_sku              NVARCHAR(20)
         , @c_uom              NVARCHAR(10)
         , @n_QtyOrdered       INT
         , @c_ExternOrderKey   NVARCHAR(30)
         , @c_headflag         NVARCHAR(1)
         , @c_detailflag       NVARCHAR(1)
         , @n_shippedqty       INT
         , @c_detExternPOKey   NVARCHAR(20)
         , @c_Best_bf_date     NVARCHAR(8)
         , @c_POKey            NVARCHAR(10)
         , @c_POGroup          NVARCHAR(10)
         , @c_mode             NVARCHAR(3)
         , @c_packkey          NVARCHAR(10)
         , @n_counter          INT
         , @n_totalrec         INT
         , @n_errcount         INT
         , @c_detpokey         NVARCHAR(10)
         , @c_detLineNumber    NVARCHAR(5)
         , @c_rff              NVARCHAR(10)  -- 25-Nov-2004 YTWan Xdock /FlowThru Link
         , @c_storeorderno     NVARCHAR(9)   -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link
         , @c_storeid          NVARCHAR(3)   -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link
         , @c_receiptkey       NVARCHAR(10)  -- 04-Mar-2005 YTWan FBR32746: Auto Populate PO to ASN
         , @c_splitorderkey    NVARCHAR(10)  -- 17-Mar-2005  YTWan FBR33101: Split Order. 1 Order to 1 PO
         , @c_orddetlineno     NVARCHAR(5)   -- 17-Mar-2005  YTWan FBR33101: Split Order. 1 Order to 1 PO
         , @c_Type             NVARCHAR(10)  -- By SHONG ON 13th Feb 2008

   DECLARE @n_max              INT
         , @c_maxlineno        NVARCHAR(5)

   DECLARE @c_detailExternPOKey  NVARCHAR(20)
         , @c_detailexternlineno NVARCHAR(20)
         , @c_detailsku          NVARCHAR(20)
         , @c_temppokey          NVARCHAR(10)
         , @c_temppolineno       NVARCHAR(5)
         , @c_tempStorerKey      NVARCHAR(15)
         , @c_tempPOGroup        NVARCHAR(10)
         , @c_existpokey         NVARCHAR(10)
         , @c_skudescr           NVARCHAR(45)
   -- Orders
   DECLARE @c_orderkey          NVARCHAR(10)
         , @c_OrderGroup        NVARCHAR(10)
         , @c_detExternOrderKey NVARCHAR(20)
         , @c_externlineno      NVARCHAR(10)
         , @c_detorderkey       NVARCHAR(10)
         , @d_OrderDate         DATETIME

   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = '', @n_err2 = 0
   SELECT @b_debug = 0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_headertable =
            CASE @c_modulename
               WHEN 'PO' THEN 'UploadC4POHeader'
               WHEN 'ORDER' THEN 'UploadC4OrderHeader'
            END,
            @c_detailtable =
            CASE @c_modulename
               WHEN 'PO' THEN 'UploadC4PODetail'
               WHEN 'ORDER' THEN 'UploadC4OrderDetail'
            END
   END

   IF @b_debug = 1
   BEGIN
      SELECT @c_headertable
      SELECT @c_detailtable
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   -- IF @c_modulename = 'PO'
   -- BEGIN
         UPDATE UploadC4PODetail
         SET Status = 'E', Remarks = 'Wrong Sku & StorerKey Combination or Sku Does not exists'
         FROM UploadC4PODetail
         LEFT OUTER JOIN Sku (NOLOCK) ON UploadC4PODetail.StorerKey = Sku.StorerKey
         AND UploadC4PODetail.Sku = Sku.Sku
         WHERE ISNULL(RTRIM(Sku.Sku),'') = ''
         AND Status = '0'

         UPDATE UploadC4POHeader
         SET UploadC4POHeader.Status = 'E',
             UploadC4POHeader.Remarks = 'Detail has Wrong Sku & StorerKey combination or Sku Does not exists'
         FROM UploadC4POHeader (NOLOCK), UploadC4PODetail (NOLOCK)
         WHERE UploadC4POHeader.POKey = UploadC4PODetail.POKey
         AND UploadC4PODetail.Status = 'E'
         AND UploadC4POHeader.Status = '0'

         UPDATE UploadC4PODetail
         SET Status = 'E', Remarks = 'Store Order# AND Store ID is required for Flow Thru PO Type'
         FROM UploadC4PODetail D
         INNER JOIN UploadC4POHeader H (NOLOCK) ON H.POKey = D.POKey
         INNER JOIN CodeLkUp (NOLOCK) ON CodeLkUp.Code = H.POType AND CodeLkUp.ListName = 'POType'
         INNER JOIN CodeLkUp FLOWTHRU (NOLOCK) ON FLOWTHRU.Code = CodeLkUp.Code AND FLOWTHRU.ListName = 'FLOWTHRU'
         WHERE D.Status = '0'
         AND ISNULL(RTRIM(D.StoreOrderNo),'') = ''
         AND ISNULL(RTRIM(D.StoreID),'') = ''

         -- Added SHONG To make the Store Order# AND Storer Id mandatory when type = Flowthru
         UPDATE UploadC4POHeader
         SET UploadC4POHeader.Status = 'E',
             UploadC4POHeader.Remarks = 'Store Order# AND Store ID is required for Flow Thru PO Type'
         FROM UploadC4POHeader (NOLOCK), UploadC4PODetail (NOLOCK)
         WHERE UploadC4POHeader.POKey = UploadC4PODetail.POKey
         AND UploadC4PODetail.Status = 'E'
         AND UploadC4POHeader.Status = '0'

         -- do sequential processing,
         DECLARE CUR_PO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT POKey, ExternPOKey, POGroup, Mode, StorerKey, POType, SellerName
            FROM UploadC4POHeader (NOLOCK)
            WHERE Status = '0' -- AND POKey = '0000000039'
            ORDER BY POKey, ExternPOKey, POGroup, Mode

         OPEN CUR_PO
         WHILE (1 = 1) -- modulename = 'PO' Big LoOP
         BEGIN
            FETCH NEXT FROM CUR_PO INTO @c_POKey, @c_ExternPOKey , @c_POGroup, @c_mode, @c_StorerKey, @c_potype, @c_sellername

            IF @@FETCH_Status <> 0 BREAK

            -- Mode = 1
            IF @c_mode = 1
            BEGIN
               IF EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey) --(Rick Liew01)
               BEGIN
                  --existing ExternPOKey , we don't want to fail it, let processing continue.
                  -- If exists,
                  -- check for details, make sure the lines does not exists,
                  -- if does not exists, add it, else reject.
                  SELECT @n_errcount = 0

                  IF EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND ExternStatus = '9')--(Rick Liew01)
                  BEGIN
                     UPDATE UploadC4PODetail
                     SET Status = 'E', Remarks = 'PO has been CLOSED'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                     AND Status = '0'
                     AND Mode = '1'
                     AND POGroup = @c_POGroup

                     UPDATE UploadC4POHeader
                     SET Status = 'E', Remarks = 'PO has been CLOSED'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                     AND Status = '0'
                     AND Mode = '1'
                     AND POGroup = @c_POGroup
                  END
                  ELSE
                  BEGIN
                     -- 25-Nov-2004 YTWan Xdock/FlowThrough Link - START
                     -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - START
                     DECLARE CUR_EXISTDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ExternPOKey, ExternLineNumber, Sku, POKey, POLineNumber, StorerKey,
                               POGroup, QtyOrdered, UOM, RFF, StoreOrderNo, StoreID
                        FROM UploadC4PODetail (NOLOCK)
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                        AND Mode = @c_mode
                        AND Status = '0'

                     OPEN CUR_EXISTDET
                     WHILE (1 = 1)
                     BEGIN
                        FETCH NEXT FROM CUR_EXISTDET INTO @c_detailExternPOKey, @c_detailexternlineno, @c_detailsku, @c_temppokey,
                                                          @c_temppolineno, @c_tempStorerKey, @c_tempPOGroup, @n_QtyOrdered, @c_uom,
                                                          @c_rff, @c_storeorderno, @c_storeid
                        IF @@FETCH_Status <> 0 BREAK

                        IF EXISTS (SELECT 1 FROM PODetail (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detailExternPOKey AND ExternLineNo = @c_detailexternlineno)  --(Rick Liew01)
                        BEGIN
                           -- Error
                           UPDATE UploadC4PODetail
                           SET Status = 'E', Remarks = 'ExternLineNo duplicated for Mode = 1'
                           WHERE StorerKey = @c_TempStorerKey AND ExternPOKey = @c_detailExternPOKey  --(Rick Liew01)
                            AND ExternLineNumber = @c_detailexternlineno
                            AND POGroup = @c_tempPOGroup
                            AND POKey = @c_temppokey
                            AND POLineNumber = @c_temppolineno
                            AND Status = '0'
                            AND Mode = @c_mode

                           SELECT @n_errcount = @n_errcount + 1
                        END
                        ELSE
                        BEGIN
                           -- insert new PODetail, use back the existing POKey, and generate a new poLineNumber
                           SELECT @c_existpokey = POKey FROM PO (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)

                           -- get the next poLineNumber
                           SELECT @n_max = CONVERT(INT, MAX(POLineNumber)) + 1 FROM PODetail (NOLOCK) WHERE ExternPOKey = @c_ExternPOKey

                           SELECT @c_maxlineno = RIGHT(dbo.fnc_RTrim(REPLICATE('0', 5) + CONVERT (char(5), @n_max)) , 5)

                           SELECT @c_packkey = PackKey, @c_skudescr = Descr FROM Sku (NOLOCK) WHERE Sku = @c_detailsku AND StorerKey = @c_TempStorerKey

                           INSERT INTO PODetail (POKey, POLineNumber, StorerKey, ExternPOKey, ExternLineNo, Sku,
                                                 SkuDescription, QtyOrdered, UOM, PackKey,Best_bf_Date, UserDefine01, UserDefine02, UserDefine03 )
                           VALUES ( @c_existpokey, @c_maxlineno, @c_tempStorerKey, @c_detailExternPOKey, @c_detailexternlineno,@c_detailsku,
                                    @c_skudescr, @n_QtyOrdered, @c_uom, @c_packkey,@c_Best_bf_Date, @c_rff, @c_storeorderno, @c_storeid )

                           SELECT @n_err = @@ERROR

                           -- 25-Nov-2004 YTWan Xdock/FlowThrough Link - END
                           -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - END
                           IF @n_err <> 0
                           BEGIN
                              -- error inserting
                              UPDATE UploadC4PODetail
                              SET Status = 'E', Remarks = 'ERROR Inserting into PODetail'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detailExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_detailexternlineno
                              AND POGroup = @c_tempPOGroup
                              AND POKey = @c_temppokey
                              AND POLineNumber = @c_temppolineno
                              AND Status = '0'
                              AND Mode = @c_mode

                              SELECT @n_errcount = @n_errcount + 1
                           END
                           ELSE
                           BEGIN
                              UPDATE UploadC4PODetail
                              SET Status = '9', Remarks = ''
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detailExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_detailexternlineno
                              AND POGroup = @c_tempPOGroup
                              AND POKey = @c_temppokey
                              AND POLineNumber = @c_temppolineno
                              AND Status = '0'
                              AND Mode = @c_mode
                           END
                        END -- if exists
                     END -- WHILE
                     CLOSE CUR_EXISTDET
                     DEALLOCATE CUR_EXISTDET

                     IF EXISTS(  SELECT 1 FROM PODetail (NOLOCK)
                                 INNER JOIN PO (NOLOCK)       ON  (PODetail.POKey = PO.POKey)
                                 INNER JOIN CodeLkUp (NOLOCK) ON  (PO.POType = CodeLkUp.Code)
                                                              AND (CodeLkUp.ListName = 'POType')
                                 INNER JOIN Receipt (NOLOCK)  ON  (Receipt.WarehouseReference = PO.ExternPOKey)
                                 INNER JOIN CodeLkUp XDLOC (NOLOCK) ON (XDLOC.Code = dbo.fnc_RTrim(dbo.fnc_LTrim(CAST (CodeLkUp.NOTES AS NVARCHAR(10))))
                                                                    AND XDLOC.ListName = 'C4MYRECLOC')
                                 WHERE PODetail.StorerKey = @c_StorerKey AND PODetail.ExternPOKey = @c_ExternPOKey --(Rick Liew01)
                                   AND NOT EXISTS (SELECT 1 FROM ReceiptDetail (NOLOCK)
                                                   WHERE StorerKey    = PODetail.StorerKey --(Rick Liew01)
                                                     AND ExternPOKey  = PODetail.ExternPOKey
                                                     AND ExternLineNo = PODetail.ExternLineNo)
                                   AND NOT EXISTS (SELECT 1 FROM CodeLkUp WITH (NOLOCK)
                                                   WHERE Code     = PO.POType
                                                     AND ListName = 'NOAUTOASN') ) -- (Rick Liew02)
                     BEGIN
                        -- Insert ASN Detail
                        INSERT INTO ReceiptDetail (Receiptkey,
                                                   ReceiptLineNumber,
                                                   ExternReceiptkey,
                                                   ExternLineNo,
                                                   ExternPOKey,
                                                   POKey,
                                                   POLineNumber,
                                                   StorerKey,
                                                   Sku,
                                                   PackKey,
                                                   UOM,
                                                   QtyExpected,
                                                   Lottable01,
                                                   Lottable02,
                                                   Lottable03,
                                                   Lottable04,
                                                   ToLoc)
                        SELECT Receipt.Receiptkey,
                               PODetail.POLineNumber,
                               PODetail.ExternPOKey,
                               PODetail.ExternLineNo,
                               PODetail.ExternPOKey,
                               PODetail.POKey,
                               PODetail.POLineNumber,
                               PODetail.StorerKey,
                               PODetail.Sku,
                               PODetail.PackKey,
                               PODetail.UOM,
                               QtyOrdered,
                               Lottable01,
                               Lottable02,
                               Lottable03,
                               Lottable04,
                               CASE WHEN ISNULL(RTRIM(PODetail.Userdefine01),'') = ''
                                    THEN 'C4STAGE'
                                    -- Start : SOS34830
                                    -- ELSE LOC.Loc
                                    ELSE XDLOC.Short
                                    -- End : SOS34830
                               END
                        FROM PODetail (NOLOCK)
                        INNER JOIN PO (NOLOCK) ON (PODetail.POKey = PO.POKey)
                        INNER JOIN CodeLkUp (NOLOCK) ON (PO.POType = CodeLkUp.Code)
                                                    AND (CodeLkUp.ListName = 'POType')
                        INNER JOIN Receipt (NOLOCK)  ON (Receipt.WarehouseReference = PO.ExternPOKey)
                        -- Start : SOS34830
                        INNER JOIN CodeLkUp XDLOC (NOLOCK) ON (XDLOC.Code = dbo.fnc_RTrim(dbo.fnc_LTrim(CAST (CodeLkUp.NOTES AS NVARCHAR(10))))
                                                           AND XDLOC.ListName = 'C4MYRECLOC')
                        -- INNER JOIN LOC (NOLOCK) ON (CAST(CodeLkUp.NOtes AS NVARCHAR(10)) = LOC.HostWHCode)
                        -- End : SOS34830
                        WHERE PODetail.StorerKey = @c_StorerKey AND PODetail.ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                          AND NOT EXISTS (SELECT 1 FROM ReceiptDetail (NOLOCK)
                                          WHERE ExternPOKey  = PODetail.ExternPOKey
                                          AND   ExternLineNo = PODetail.ExternLineNo)

                        IF @@Error <> 0
                        BEGIN
                           UPDATE UploadC4POHeader
                           SET Status = 'E', Remarks = 'Error on insert additional record to ReceiptDetail'
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                           AND Status = '0'
                           AND Mode = '1'
                           AND POGroup = @c_POGroup
                        END
                     END
                  END -- if exists

                  IF @n_errcount = 0
                  BEGIN
                     UPDATE UploadC4POHeader
                     SET Status = '9', Remarks = ''
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup  AND POKey = @c_POKey --(Rick Liew01)
                     AND Mode = @c_mode
                     AND Status = '0'
                  END
                  ELSE
                  BEGIN
                     UPDATE UploadC4POHeader
                     SET Status = 'E', Remarks = 'There is some errors on detail lines'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup  AND POKey = @c_POKey  --(Rick Liew01)
                     AND Mode = @c_mode
                     AND Status = '0'
                  END
               END
               ELSE
               BEGIN -- New PO Records (Which not exists)
                  INSERT INTO PO (POKey, ExternPOKey, StorerKey, POType, SellerName,LoadingDate)
                  SELECT @c_POKey, @c_ExternPOKey, StorerKey, POType, SellerName, LoadingDate FROM UploadC4POHeader (NOLOCK)
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup  --(Rick Liew01)
                  AND Mode = @c_mode  AND POKey = @c_POKey AND Status = '0'

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     UPDATE UploadC4POHeader
                     SET Status = 'E', Remarks = '65001 : ERROR INSERTING INTO PO'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey --(Rick Liew01)
                     AND Mode = @c_mode AND Status = '0'

                     -- IF insert into Header fails, fail the detail AS well
                     UPDATE UploadC4PODetail
                     SET Status = 'E', Remarks = '65001 :Insert into Header FaileD. Detail rejected'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey --(Rick Liew01)
                     AND Mode = @c_mode AND Status = '0'
                     -- SELECT @n_continue = 3
                     -- SELECT @n_err = 65001
                     -- SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting into PO (nspImportData)'
                  END
                  ELSE
                  BEGIN --insert successful, UPDATE the Status = '9'
                     UPDATE UploadC4POHeader
                     SET Status = '9', Remarks = ''
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey AND Mode = @c_mode  --(Rick Liew01)

                     -- insert the details
                     DECLARE CUR_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ExternPOKey, ExternLineNumber, Sku, POKey, POLineNumber
                        FROM UploadC4PODetail (NOLOCK)
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey --(Rick Liew01)
                        AND Mode = @c_mode AND POGroup = @c_POGroup
                        AND Status = '0' AND POKey = @c_POKey
                        ORDER BY POGroup, ExternPOKey, ExternLineNumber

                     OPEN CUR_DETAIL
                     WHILE (1 = 1)
                     BEGIN
                        FETCH NEXT FROM CUR_DETAIL INTO @c_detExternPOKey, @c_externLineNumber, @c_sku, @c_detpokey, @c_detLineNumber

                        IF @@FETCH_Status <> 0
                           BREAK

                        IF EXISTS ( SELECT 1
                                    FROM UploadC4PODetail UD (NOLOCK), Sku (NOLOCK)
                                    WHERE UD.Sku = Sku.Sku
                                    AND UD.StorerKey = Sku.StorerKey
                                    AND UD.Mode = @c_mode
                                    AND UD.Status = '0'
                                    AND UD.ExternPOKey = @c_detExternPOKey
                                    AND UD.ExternLineNumber = @c_externLineNumber
                                    AND UD.POGroup = @c_POGroup
                                    AND UD.POKey = @c_detpokey
                                    AND UD.POLineNumber = @c_detLineNumber
                                    AND UD.StorerKey = @c_StorerKey
                                    AND UD.Sku = @c_sku )
                        BEGIN
                           -- 25-Nov-2004 YTWan Xdock/FlowThrough Link - START
                           -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - START
                           INSERT INTO PODetail ( POKey, POLineNumber,  StorerKey,ExternPOKey, ExternLineNo,
                                                  Sku, SkuDescription, QtyOrdered, UOM, PackKey, UserDefine01, UserDefine02, UserDefine03 )
                           SELECT UD.POKey,
                                  UD.POLineNumber ,
                                  UD.StorerKey,
                                  @c_detExternPOKey,
                                  @c_externLineNumber,
                                  UD.Sku,
                                  Sku.Descr,
                                  UD.QtyOrdered,
                                  UD.UOM,
                                  Sku.PackKey,
                                  UD.Rff,
                                  UD.StoreOrderNo,
                                  UD.StoreID
                           FROM UploadC4PODetail UD (NOLOCK), Sku (NOLOCK)
                           WHERE UD.Sku = Sku.Sku
                           AND UD.StorerKey = Sku.StorerKey
                           AND UD.Mode = @c_mode
                           AND UD.Status = '0'
                           AND UD.ExternPOKey = @c_detExternPOKey
                           AND UD.ExternLineNumber = @c_externLineNumber
                           AND UD.POGroup = @c_POGroup
                           AND UD.POKey = @c_detpokey
                           AND UD.POLineNumber = @c_detLineNumber
                           AND UD.StorerKey = @c_StorerKey
                           AND UD.Sku = @c_sku
                           -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - END
                           -- 25-Nov-2004 YTWan Xdock/FlowThrough Link - END

                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0
                           BEGIN -- error occurred,
                              UPDATE UploadC4PODetail
                              SET Status = 'E', Remarks = '65003: ERROR INSERTING INTO PODetail'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_externLineNumber
                              AND POGroup = @c_POGroup
                              AND Status = '0' AND Mode = @c_mode
                              -- SELECT @n_continue = 3
                              -- SELECT @n_err = 65003
                              -- SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting into PODetail(nspImportData)'
                           END
                           ELSE
                           BEGIN -- no errors,
                              UPDATE UploadC4PODetail
                              SET Status = '9', Remarks = 'TYPE 1'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_externLineNumber
                              AND POGroup = @c_POGroup AND POKey = @c_detpokey AND poLineNumber = @c_detLineNumber
                              AND Status = '0' AND Mode = @c_mode
                           END
                        END -- if exists
                     END -- WHILE (for cursor detail)
                     CLOSE CUR_DETAIL
                     DEALLOCATE CUR_DETAIL

                     -- FBR 32746: Auto Populate PO to ASN

                     IF NOT EXISTS(SELECT 1 FROM CodeLkUp WITH (NOLOCK) WHERE ListName = 'NOAUTOASN' AND Code = @c_POType) -- (Rick Liew02)
                     BEGIN
                        IF EXISTS (SELECT 1 FROM PODetail (NOLOCK) WHERE POKey = @c_POKey)
                        BEGIN
                           -- Get ASN #
                           EXECUTE nspg_GetKey
                                    'RECEIPT',
                                    10,
                                    @c_receiptkey OUTPUT,
                                    @b_success    OUTPUT,
                                    @n_err        OUTPUT,
                                    @c_errmsg     OUTPUT

                           -- Insert ASN
                           INSERT INTO Receipt (Receiptkey,
                                                StorerKey,
                                                WarehouseReference,
                                                POKey,
                                                Facility,
                                                DocType,
                                                Rectype)
                           SELECT @c_receiptkey,
                                  PO.StorerKey,
                                  PO.ExternPOKey,
                                  PO.POKey,
                                  Storer.Facility,
                                  CASE WHEN MIN(ISNULL(RTRIM(PODetail.Userdefine01),'')) = ''
                                      THEN 'A'
                                      ELSE 'X'
                                  END,
                                  'XDOCK'
                           FROM PO (NOLOCK)
                           INNER JOIN PODetail (NOLOCK) ON (PODetail.POKey = PO.POKey)
                           INNER JOIN Storer (NOLOCK)   ON (Storer.StorerKey = PO.StorerKey)
                           WHERE PO.POKey = @c_POKey
                           GROUP BY PO.StorerKey,
                                    PO.ExternPOKey,
                                    PO.POKey,
                                    Storer.Facility

                           IF @@error <> 0
                           BEGIN
                              UPDATE UploadC4POHeader
                              SET Status = 'E', Remarks = '65021 : ERROR INSERTING INTO Receipt'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey  -- (RickLiew01)
                              AND Mode = @c_mode AND Status = '9'
                           END
                           ELSE
                           BEGIN
                              -- Insert ASN Detail
                              INSERT INTO ReceiptDetail (Receiptkey,
                                                         ReceiptLineNumber,
                                                         ExternReceiptkey,
                                                         ExternLineNo,
                                                         ExternPOKey,
                                                         POKey,
                                                         POLineNumber,
                                                         StorerKey,
                                                         Sku,
                                                         PackKey,
                                                         UOM,
                                                         QtyExpected,
                                                         Lottable01,
                                                         Lottable02,
                                                         Lottable03,
                                                         Lottable04,
                                                         ToLoc)
                              SELECT @c_receiptkey,
                                     PODetail.POLineNumber,
                                     PODetail.ExternPOKey,
                                     PODetail.ExternLineNo,
                                     PODetail.ExternPOKey,
                                     PODetail.POKey,
                                     PODetail.POLineNumber,
                                     PODetail.StorerKey,
                                     PODetail.Sku,
                                     PODetail.PackKey,
                                     PODetail.UOM,
                                     QtyOrdered,
                                     Lottable01,
                                     Lottable02,
                                     Lottable03,
                                     Lottable04,
                                     CASE WHEN ISNULL(RTRIM(PODetail.Userdefine01),'') = ''
                                         THEN 'C4STAGE'
                                         -- Start : SOS34830
                                         -- ELSE LOC.Loc
                                         ELSE XDLOC.Short
                                         -- End : SOS34830
                                     END
                              FROM PODetail (NOLOCK)
                              INNER JOIN PO (NOLOCK) ON (PODetail.POKey = PO.POKey)
                              INNER JOIN CodeLkUp (NOLOCK) ON (PO.POType = CodeLkUp.Code)
                                                          AND (CodeLkUp.ListName = 'POType')
                              -- Start : SOS34830
                              INNER JOIN CodeLkUp XDLOC (NOLOCK) ON (XDLOC.Code = dbo.fnc_RTrim(dbo.fnc_LTrim(CAST (CodeLkUp.NOTES AS NVARCHAR(10))))
                                                                 AND XDLOC.ListName = 'C4MYRECLOC')
                              -- INNER JOIN LOC (NOLOCK) ON (CAST(CodeLkUp.NOtes AS NVARCHAR(10)) = LOC.HostWHCode)
                              -- End : SOS34830
                              WHERE PODetail.POKey = @c_POKey

                              IF @@error <> 0
                              BEGIN
                                 UPDATE UploadC4POHeader
                                 SET Status = 'E', Remarks = '65021 : ERROR INSERTING INTO ReceiptDetail'
                                 WHERE ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey
                                 AND Mode = @c_mode AND Status = '9'
                              END
                           END
                        END
                        ELSE
                        BEGIN
                           -- NO PO populate to ASN
                           UPDATE UploadC4POHeader
                           SET Status = 'E', Remarks = '65001 : PO Inserted But PO NO Populate To ASN'
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND POKey = @c_POKey --(Rick Liew01)
                           AND Mode = @c_mode AND Status = '9'
                        END
                     END
                  END -- INsert PO Success
               END -- IF EXISTS
            END -- @c_mode = 1
            ELSE
            IF @c_mode = '2'
            BEGIN
               IF EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey)  --(Rick Liew01)
               BEGIN
                  UPDATE PO
                  SET SellerName = @c_sellername,
                      POType = @c_potype,
                      TrafficCop = NULL
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                  -- AND POGroup = @c_POGroup
                  AND ExternStatus <> '9' -- ( when Status = '9', it's automatically closed )

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN -- error updating POheader
                     UPDATE UploadC4POHeader
                     SET Status = 'E', Remarks = '65005 : Unable to UPDATE PO table'
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                     AND POGroup = @c_POGroup AND POKey = @c_POKey
                     AND Mode = @c_mode
                     AND Status = '0'
                  END
                  ELSE
                  BEGIN -- no error
                     UPDATE UploadC4POHeader
                     SET Status = '9', Remarks = ''
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                     AND POGroup = @c_POGroup AND POKey = @c_POKey
                     AND Mode = @c_mode
                     AND Status = '0'

                     -- if header successfully updated, try detail
                     DECLARE CUR_DETAILUPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ExternPOKey, ExternLineNumber, Sku, QtyOrdered, 'UOM' = ISNULL(UOM, 'EA')
                        FROM UploadC4PODetail (NOLOCK)
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey --(Rick Liew01)
                        AND Mode = @c_mode AND POGroup = @c_POGroup
                        AND Status = '0' AND POKey = @c_POKey
                        ORDER BY POGroup, ExternPOKey, ExternLineNumber

                     OPEN CUR_DETAILUPDATE
                     WHILE (1 = 1)
                     BEGIN
                        FETCH NEXT FROM CUR_DETAILUPDATE INTO @c_detExternPOKey, @c_externLineNumber, @c_sku, @n_QtyOrdered, @c_uom

                        IF @@FETCH_Status <> 0
                           BREAK

                        -- Check for PODetail Status, if qtyreceived > 0 , reject UPDATE
                        IF NOT EXISTS (SELECT 1 FROM PODetail (NOLOCK)
                                       WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey--(Rick Liew01)
                                       AND ExternLineNo = @c_externLineNumber
                                       AND QtyReceived > 0 )
                        BEGIN
                           SELECT @c_packkey = PackKey FROM Sku (NOLOCK) WHERE Sku = @c_sku AND StorerKey = @c_StorerKey

                           UPDATE PODetail
                           SET Sku = @c_sku,
                               QtyOrdered = @n_QtyOrdered,
                               UOM = @c_uom,
                               PackKey = @c_packkey
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey --(Rick Liew01)
                           AND ExternLineNo = @c_externLineNumber
                           AND QtyReceived = 0

                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0
                           BEGIN -- error occurred,
                              UPDATE UploadC4PODetail
                              SET Status = 'E', Remarks = '65006: ERROR UPDATING PODetail'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_externLineNumber
                              AND POGroup = @c_POGroup AND POKey = @c_POKey
                              AND Status = '0' AND Mode = @c_mode
                              -- SELECT @n_continue = 3
                              -- SELECT @n_err = 65003
                              -- SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting into PODetail(nspImportData)'
                           END
                           ELSE
                           BEGIN -- no errors,
                              UPDATE UploadC4PODetail
                              SET Status = '9', Remarks = 'TYPE 2'
                              WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                              AND ExternLineNumber = @c_externLineNumber
                              AND POGroup = @c_POGroup AND POKey = @c_POKey
                              AND Status = '0' AND Mode = @c_mode
                           END
                        END -- IF EXISTS
                     END -- WHILE (for cursor detail)
                     CLOSE CUR_DETAILUPDATE
                     DEALLOCATE CUR_DETAILUPDATE

                     --04-Mar-2005 YTWan FBR32746: Auto Populate PO to ASN
                     -- UPDATE ASN DETAIL
                     IF NOT EXISTS (SELECT 1 FROM CodeLkUp WITH (NOLOCK) WHERE ListName = 'NOAUTOASN' AND Code = @c_POType)   -- (Rick Liew02)
                     BEGIN
                        UPDATE ReceiptDetail
                           SET Sku = @c_sku,
                               QtyExpected = @n_QtyOrdered,
                               UOM = @c_uom,
                               PackKey = @c_packkey
                        FROM PODetail (NOLOCK), UploadC4PODetail (NOLOCK)
                        WHERE ReceiptDetail.ExternPOKey  = PODetail.ExternPOKey
                          AND ReceiptDetail.ExternLineNo = PODetail.ExternLineNo
                          AND ReceiptDetail.Lottable03   = PODetail.ExternPOKey
                          AND ReceiptDetail.QtyReceived  = 0
                          AND PODetail.ExternPOKey       = UploadC4PODetail.ExternPOKey
                          AND PODetail.ExternLineNo      = UploadC4PODetail.ExternLineNumber
                          AND UploadC4PODetail.POGroup   = @c_POGroup
                          AND UploadC4PODetail.POKey     = @c_POKey
                          AND UploadC4PODetail.Status    = '0'
                          AND UploadC4PODetail.Mode      = @c_mode

                        IF @@error <> 0
                        BEGIN
                           UPDATE UploadC4POHeader
                           SET Status = 'E', Remarks = 'UPDATE PODetail Successful but Error UPDATE ReceiptDetail'
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                           AND POGroup = @c_POGroup AND POKey = @c_POKey
                           AND Mode = @c_mode
                        END
                     END
                  END
               END -- IF EXISTS
               ELSE
               BEGIN
                  UPDATE UploadC4POHeader
                  SET Status = 'E', Remarks = 'ExternPOKey does not exists. UPDATE is not executed'
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                  AND POGroup = @c_POGroup AND POKey = @c_POKey
                  AND Mode = @c_mode

                  UPDATE UploadC4PODetail
                  SET Status = 'E', Remarks = 'ExternPOKey does not exists. UPDATE is not executed'
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                  AND POGroup = @c_POGroup AND POKey = @c_POKey
                  AND Mode = @c_mode
               END
            END -- c_mode = '2'
            ELSE
            IF @c_mode = '3'
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM PO (NOLOCK) WHERE ExternPOKey = @c_ExternPOKey AND ExternStatus = '9')
               BEGIN
                  -- for  Mode = 3 (DELETE), Delete the details first, AND if all details has been deleted, delete the header.
                  DECLARE CUR_DELETEDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT ExternPOKey, ExternLineNumber, POKey, POLineNumber
                     FROM UploadC4PODetail (NOLOCK)
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey  --(Rick Liew01)
                     AND POGroup = @c_POGroup
                     AND Mode = @c_mode
                     AND Status = '0'
                     AND POKey = @c_POKey
                     ORDER BY POGroup, ExternPOKey, ExternLineNumber

                  OPEN CUR_DELETEDETAIL
                  WHILE (1=1)
                  BEGIN
                     FETCH NEXT FROM CUR_DELETEDETAIL INTO @c_detExternPOKey, @c_externLineNumber, @c_detpokey,
                                                           @c_detLineNumber
                     IF @@FETCH_Status <> 0
                        BREAK

                     IF NOT EXISTS (SELECT 1 FROM PODetail (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                                    AND ExternLineNo = @c_externLineNumber
                                    AND QtyReceived > 0)
                     BEGIN
                        DELETE PODetail
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                        AND ExternLineNo = @c_externLineNumber
                        AND QtyReceived = 0

                        SELECT @n_err = @@ERROR
                        SELECT @n_cnt = @@ROWCOUNT

                        IF @n_cnt > 0 AND @n_err = 0
                        BEGIN
                           UPDATE UploadC4PODetail
                           SET Status = '9', Remarks = 'type 3'
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                           AND ExternLineNumber = @c_externLineNumber
                           AND POGroup = @c_POGroup AND POKey = @c_POKey
                           AND Mode = @c_mode
                           AND Status = '0'

                           DELETE ReceiptDetail
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey --(Rick Liew01)
                           AND ExternLineNo = @c_externLineNumber
                           AND QtyReceived = 0
                        END
                        ELSE
                        BEGIN
                           UPDATE UploadC4PODetail
                           SET Status = 'E', Remarks = '65009 : Unable to delete PODetail'
                           WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                           AND ExternLineNumber = @c_externLineNumber
                           AND POGroup = @c_POGroup AND POKey = @c_POKey
                           AND Mode = @c_mode
                           AND Status = '0'
                        END
                     END
                     ELSE
                     BEGIN
                        UPDATE UploadC4PODetail
                        SET Status = 'E', Remarks = '65010 : PODetail has QtyReceived > 0'
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey --(Rick Liew01)
                        AND ExternLineNumber = @c_externLineNumber
                        AND POGroup = @c_POGroup AND POKey = @c_POKey
                        AND Mode = @c_mode
                        AND Status = '0'
                     END
                  END -- End WHILE (CUR_DELETEDETAIL)
                  CLOSE CUR_DELETEDETAIL
                  DEALLOCATE CUR_DELETEDETAIL

                  -- after delete detail, count the balance of details, if no more detail lines, then delete the header
                  SELECT @count1 = COUNT(*) FROM PODetail (NOLOCK) WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_ExternPOKey --(Rick Liew01)

                  IF @count1 = 0
                  BEGIN
                     DELETE PO
                     WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)

                     SELECT @n_err = @@ERROR
                     SELECT @n_cnt = @@ROWCOUNT

                     IF @n_err = 0 AND @n_cnt > 0
                     BEGIN
                        UPDATE UploadC4POHeader
                        SET Status = '9', Remarks = ''
                        WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey--(Rick Liew01)
                        AND POGroup = @c_POGroup AND POKey = @c_detpokey
                        AND Mode = @c_mode
                        AND Status = '0'
                     END
                  END
               END -- if not exists
               ELSE
               BEGIN -- po has been closed
                  UPDATE UploadC4POHeader
                     SET Status = 'E', Remarks = '65012: PO has been CLOSED'
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                    AND POGroup = @c_POGroup AND POKey = @c_POKey
                    AND Mode = @c_mode
                    AND Status = '0'

                  UPDATE UploadC4PODetail
                     SET Status = 'E', Remarks = '65012: PO has been CLOSED'
                  WHERE StorerKey = @c_StorerKey AND ExternPOKey = @c_detExternPOKey  --(Rick Liew01)
                    AND POGroup = @c_POGroup AND POKey = @c_POKey
                    AND Mode = @c_mode
                    AND Status = '0'
               END -- po has been closed
            END -- for Mode = 3
            ELSE
            BEGIN -- everything fails
               UPDATE UploadC4POHeader
                  SET Status = 'E', Remarks = '65013 : Invalid Mode, ExternOrderKey or Status'
               WHERE StorerKey = @c_StorerKey AND ISNULL(RTRIM(ExternPOKey),'') = ''  --(Rick Liew01)
                  OR ISNULL(RTRIM(Status),'') = ''
                  OR ISNULL(RTRIM(Mode),'') = ''

               UPDATE UploadC4PODetail
                  SET Status = 'E', Remarks = '65014 : Invalid Mode, ExternOrderKey or Status'
               WHERE StorerKey = @c_StorerKey AND ISNULL(RTRIM(ExternPOKey),'') = ''  --(Rick Liew01)
                  OR ISNULL(RTRIM(Status),'') = ''
                  OR ISNULL(RTRIM(Mode),'') = ''
            END -- for all other reasons

            SELECT @count1 = COUNT(*) FROM UploadC4POHeader (NOLOCK) WHERE ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND Mode = @c_mode

            IF @count1 > 0
            BEGIN
               SELECT @n_counter = @n_counter + 1
            END

            --SELECT @count1  = COUNT(*) FROM UploadC4POHeader (NOLOCK) WHERE ExternPOKey = @c_ExternPOKey AND POGroup = @c_POGroup AND Mode = @c_mode

            --IF @count1 > 0
            --BEGIN
            --   SELECT @n_counter = @n_counter + 1
            --END
         END -- WHILE --modulename = 'PO', big LOOP
         CLOSE CUR_PO
         DEALLOCATE CUR_PO
   -- END -- modulename = 'PO'
   -- ------------------------------------------------------------------
   -- End of MODULENAME = 'PO'
   -- ------------------------------------------------------------------

   -- IF @c_modulename = 'Order'
   -- BEGIN
         -- Validation section
         -- start of wrong Sku & StorerKey combination.
         UPDATE UploadC4OrderDetail
         SET Status = 'E', Remarks = 'Wrong Sku & StorerKey Combination or Sku Does not exists'
         FROM UploadC4OrderDetail (NOLOCK)
         LEFT OUTER JOIN Sku (NOLOCK)  ON UploadC4OrderDetail.StorerKey = Sku.StorerKey
         AND UploadC4OrderDetail.Sku = Sku.Sku
         -- FBR42502
         -- AND UploadC4OrderDetail.Status = '0'
         -- AND UploadC4OrderDetail.StorerKey BETWEEN 'C4LG000000' AND 'C4LGZZZZZZ'
         WHERE ISNULL(RTRIM(Sku.Sku),'') = ''
         -- FBR42502
         AND UploadC4OrderDetail.Status = '0'
         AND UploadC4OrderDetail.StorerKey BETWEEN 'C4LG000000' AND 'C4LGZZZZZZ'

         UPDATE UploadC4OrderHeader
         SET Status = 'E', Remarks = 'Detail has Wrong Sku & StorerKey combination or Sku Does not exists'
         FROM UploadC4OrderHeader H (NOLOCK)
         INNER JOIN UploadC4OrderDetail D (NOLOCK) ON H.orderkey = D.orderkey
         AND H.StorerKey BETWEEN 'C4LG000000' AND 'C4LGZZZZZZ'
         AND D.Status = 'E'
         AND H.Status = '0'
         -- AND H.ExternPOKey = D.ExternPOKey
         -- end of wrong Sku & StorerKey combination.

         -- Start : SOS96737 - Remove Hardcoding of Type
         /*
         -- Added By SHONG, Assign the ExternPOKey Here
         UPDATE UploadC4OrderDetail
            SET ExternPOKey = PD.ExternPOKey
         FROM UploadC4OrderDetail UD (NOLOCK)
         INNER JOIN UploadC4OrderHeader H (NOLOCK) ON UD.Orderkey = H.OrderKey AND H.Status = '0'
         INNER JOIN PODetail PD (NOLOCK) ON SUBSTRING(UD.ExternOrderKey,1,12) = dbo.fnc_RTrim(PD.UserDefine02 + PD.UserDefine03)
                                        AND UD.Sku   = PD.Sku
         WHERE SUBSTRING(H.Type,1,1) = '8'
           AND UD.Status = '0'

         UPDATE UploadC4OrderDetail
            SET ExternPOKey = PD.ExternPOKey
         FROM UploadC4OrderDetail UD (NOLOCK)
         INNER JOIN UploadC4OrderHeader H (NOLOCK) ON UD.Orderkey = H.OrderKey AND H.Status = '0'
         INNER JOIN PODetail PD (NOLOCK) ON UD.Rff = PD.UserDefine01 AND UD.Sku  = PD.Sku
         WHERE SUBSTRING(H.Type,1,1) <> '8'
           AND UD.Status = '0'  */

         -- Flow Through Order
         UPDATE UploadC4OrderDetail
         SET ExternPOKey = PD.ExternPOKey
         FROM UploadC4OrderDetail UD (NOLOCK)
         INNER JOIN UploadC4OrderHeader H (NOLOCK) ON UD.Orderkey = H.OrderKey AND H.Status = '0'
         INNER JOIN PODetail PD (NOLOCK) ON SUBSTRING(UD.ExternOrderKey,1,12) = RTRIM(PD.UserDefine02 + PD.UserDefine03)
                                        AND UD.Sku = PD.Sku
         INNER JOIN CodeLkUp (NOLOCK) ON CodeLkUp.Code = H.Type AND CodeLkUp.ListName = 'ORDERTYPE'
         INNER JOIN CodeLkUp FLOWTHRU (NOLOCK) ON FLOWTHRU.Code = CodeLkUp.Code AND FLOWTHRU.ListName = 'FLOWTHRU'
         WHERE UD.Status = '0'

         -- NON Flow Through Order
         UPDATE UploadC4OrderDetail
            SET ExternPOKey = PD.ExternPOKey
         FROM UploadC4OrderDetail UD (NOLOCK)
         INNER JOIN UploadC4OrderHeader H (NOLOCK) ON UD.Orderkey = H.OrderKey AND H.Status = '0'
         INNER JOIN PODetail PD (NOLOCK) ON UD.Rff = PD.UserDefine01 AND UD.Sku  = PD.Sku
         INNER JOIN CodeLkUp (NOLOCK) ON CodeLkUp.Code = H.Type AND CodeLkUp.ListName = 'ORDERTYPE'
         LEFT OUTER JOIN CodeLkUp FLOWTHRU (NOLOCK) ON FLOWTHRU.Code = CodeLkUp.Code AND FLOWTHRU.ListName = 'FLOWTHRU'
         WHERE ISNULL(RTRIM(FLOWTHRU.Code),'') = '' -- SOS308367
           AND UD.Status = '0'
         -- End : SOS96737

         UPDATE UploadC4OrderHeader
            SET ExternPOKey = (SELECT MIN(UD.ExternPOKey) FROM UploadC4OrderDetail UD (NOLOCK)
         WHERE UD.Orderkey = H.OrderKey AND UD.Status = '0')
         FROM UploadC4OrderHeader H (NOLOCK)
         WHERE H.Status = '0'
         -- End

         -- do sequential processing,
         DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OrderKey, ExternOrderKey, OrderGroup, Mode, StorerKey, ConsigneeKey, OrderDate, ExternPOKey,
                   LEFT(Type, 1) AS Type
            FROM  UploadC4OrderHeader (NOLOCK)
            WHERE Status = '0'
              AND StorerKey BETWEEN 'C4LG000000' AND 'C4LGZZZZZZ'

         OPEN CUR_ORDER
         WHILE (1 = 1) -- modulename = 'Order' Big LoOP
         BEGIN
            NEXT_ORDERS:
            FETCH NEXT FROM CUR_ORDER INTO @c_Orderkey,  @c_ExternOrderKey , @c_OrderGroup, @c_mode,
                                           @c_StorerKey, @c_ConsigneeKey,    @d_OrderDate,  @c_ExternPOKey,
                                           @c_Type

            IF @@FETCH_Status <> 0
               BREAK

            -- SOS308367 (Start)
            IF ISNULL(RTRIM(@c_ExternPOKey),'') = ''
               AND @c_Type IN (SELECT Code FROM CodeLkUp WITH (NOLOCK) WHERE ListName IN ('FLOWTHRU','XDOCK'))
            BEGIN
               GOTO NEXT_ORDERS
            END
            -- SOS308367 (End)

            -- Mode = 1
            IF @c_mode = 1
            BEGIN
               IF EXISTS (SELECT 1 FROM Orders (NOLOCK)
                           WHERE ExternOrderKey = @c_ExternOrderKey
                             AND ConsigneeKey = @c_ConsigneeKey
                             AND OrderDate = @d_OrderDate)
               BEGIN --existing ExternOrderKey , we don't want to fail it, let processing continue.
                  UPDATE UploadC4OrderHeader
                  SET Status = 'E', Remarks = '65004 : ExternOrderKey Already exists'
                  WHERE OrderKey = @c_Orderkey
                     AND Status = '0'

                  -- UPDATE the detail AS well,
                  UPDATE UploadC4OrderDetail
                  SET Status = 'E', Remarks = '65004 : ExternOrderKey Already exists. Unable to insert into Detail'
                  WHERE Orderkey = @c_Orderkey
                     AND Status = '0'
               END
               ELSE
               BEGIN -- does not exists
                  -- Added By SHONG ON 13th Feb 2008
                  -- For Xdock AND FlowThru Order Type
                  -- IF @c_Type IN ('5', '6', '8') -- Modified by Rick Liew for SOS96737
                  IF @c_Type IN (SELECT Code FROM CodeLkUp WITH (NOLOCK) WHERE ListName IN ('FLOWTHRU','XDOCK'))
                  BEGIN
                     -- Do not Upload the Orders into Orders & OrderDetail if ExternPOKey is not properly updated yet
                     IF EXISTS( SELECT 1 FROM UploadC4OrderDetail (NOLOCK)
                                WHERE OrderKey = @c_Orderkey
                                AND ISNULL(RTRIM(ExternPOKey),'') = '' )
                     BEGIN
                        CONTINUE
                     END -- Blank ExternPOKey Found
                  END -- @c_Type IN ('5', '6', '8')

                  SET ROWCOUNT 0

                  INSERT INTO Orders ( Orderkey, ExternOrderKey, StorerKey, OrderDate, Deliverydate,
                                       Priority, c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3, c_address4,
                                       c_city, c_state, c_zip, buyerpo, notes,InvoiceNo,  notes2, pmtterm, invoiceamount ,
                                       ROUTE, Facility, Type, ConsigneeKey, ExternPOKey )
                  SELECT @c_Orderkey, @c_ExternOrderKey, UploadC4OrderHeader.StorerKey, OrderDate, Deliverydate,
                        --Priority -- SOS# 114709
                        UploadC4OrderHeader.ConsigneeKey, -- SOS# 114709
                        Storer.contact1, Storer.contact2, Storer.company, Storer.address1, Storer.address2,
                        Storer.address3, Storer.address4, Storer.city, Storer.state, Storer.zip, buyerpo, notes,
                        InvoiceNo, UploadC4OrderHeader.notes2, pmtterm, invoiceamount , ISNULL (ROUTE , '99'),
                        Storer.Facility, UploadC4OrderHeader.Type, UploadC4OrderHeader.ConsigneeKey, @c_ExternPOKey
                  FROM UploadC4OrderHeader (NOLOCK), Storer(NOLOCK)
                  WHERE OrderKey = @c_Orderkey
                    AND UploadC4OrderHeader.Status = '0'
                    AND UploadC4OrderHeader.StorerKey = Storer.StorerKey

                  -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - END
                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     UPDATE UploadC4OrderHeader
                        SET Status = 'E', Remarks = '65001 : ERROR INSERTING INTO Order'
                     WHERE ExternOrderKey = @c_ExternOrderKey AND OrderGroup = @c_OrderGroup
                       AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode AND Status = '0'

                     -- IF insert into Header fails, fail the detail AS well
                     UPDATE UploadC4OrderDetail
                        SET Status = 'E', Remarks = '65001 :Insert into Header FaileD. Detail rejected'
                     WHERE ExternOrderKey = @c_ExternOrderKey AND OrderGroup = @c_OrderGroup
                       AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode AND Status = '0'
                  END
                  ELSE
                  BEGIN --insert successful, UPDATE the Status = '9'
                     UPDATE UploadC4OrderHeader
                        SET Status = '9', Remarks = ''
                     WHERE ExternOrderKey = @c_ExternOrderKey
                       AND OrderGroup = @c_OrderGroup
                       AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode

                     SELECT @c_detLineNumber = ''

                     WHILE (2=2)
                     BEGIN
                        SET ROWCOUNT 1

                        SELECT @c_detLineNumber = OrderLineNumber,
                               @c_ExternPOKey   = ExternPOKey
                        FROM UploadC4OrderDetail (NOLOCK)
                        WHERE OrderLineNumber > @c_detLineNumber
                          AND orderkey = @c_orderkey
                        ORDER BY OrderLineNumber

                        IF @@ROWCOUNT = 0
                           BREAK

                        SET ROWCOUNT 0
                        -- SET ROWCOUNT 0
                        -- 17-Feb-2005 YTWan FBR32265: FlowThrough Link - END
                        -- 17-Mar-2005 YTWan FBR33101: Split Order. 1 Order to 1 PO

                        IF ISNULL(RTRIM(@c_ExternPOKey),'') = ''
                        BEGIN
                           SELECT @c_splitorderkey = @c_Orderkey
                           SELECT @c_orddetlineno = @c_detLineNumber
                        END
                        ELSE
                        BEGIN
                           SELECT @c_splitorderkey= '', @c_orddetlineno = '0'

                           SELECT @c_splitorderkey = MIN(Orders.Orderkey),
                                  @c_orddetlineno = ISNULL(MAX(OrderLineNumber), '0')
                           FROM Orders (NOLOCK)
                           LEFT OUTER JOIN OrderDetail (NOLOCK) ON (Orders.Orderkey = OrderDetail.Orderkey)
                           WHERE Orders.ExternPOKey = @c_ExternPOKey
                             AND Orders.ExternOrderKey = @c_ExternOrderKey
                           GROUP BY Orders.ExternOrderKey, Orders.ExternPOKey

                           IF ISNULL(RTRIM(@c_splitorderkey),'') = ''
                           BEGIN
                              EXECUTE nspg_GetKey
                                    'ORDER',
                                    10,
                                    @c_splitorderkey OUTPUT,
                                    @b_success       OUTPUT,
                                    @n_err           OUTPUT,
                                    @c_errmsg        OUTPUT

                              INSERT INTO Orders ( Orderkey, ExternOrderKey,UploadC4OrderHeader.StorerKey,OrderDate, Deliverydate,
                                                   Priority, c_contact1, c_contact2, c_company, c_address1, c_address2, c_address3,
                                                   c_address4, c_city, c_state, c_zip, buyerpo, notes,InvoiceNo,  notes2, pmtterm,
                                                   invoiceamount , ROUTE, Facility, Type, ConsigneeKey, ExternPOKey )
                              SELECT @c_splitorderkey, @c_ExternOrderKey, UploadC4OrderHeader.StorerKey, OrderDate, Deliverydate,
                                    --Priority --SOS # 114709
                                    UploadC4OrderHeader.ConsigneeKey, -- SOS# 114709
                                    Storer.contact1, Storer.contact2, Storer.company, Storer.address1, Storer.address2,
                                    Storer.address3, Storer.address4, Storer.city, Storer.state, Storer.zip, buyerpo, notes,
                                    InvoiceNo, UploadC4OrderHeader.notes2, pmtterm, invoiceamount , ISNULL (ROUTE , '99'),
                                    Storer.Facility, UploadC4OrderHeader.Type, UploadC4OrderHeader.ConsigneeKey, @c_ExternPOKey
                              FROM UploadC4OrderHeader (NOLOCK), Storer(NOLOCK)
                              WHERE OrderKey = @c_Orderkey
                                AND UploadC4OrderHeader.Status = '9'
                                AND UploadC4OrderHeader.StorerKey = Storer.StorerKey
                           END

                           SELECT @c_orddetlineno = RIGHT(dbo.fnc_RTrim('00000' + CAST(CAST(@c_orddetlineno AS INT) + 1 AS NVARCHAR(5))), 5)
                        END
                        -- 17-Mar-2005 YTWan FBR33101: Split Order. 1 Order to 1 PO

                        INSERT INTO OrderDetail ( Orderkey, OrderLineNumber, StorerKey, ExternOrderKey, ExternLineNo,
                                                  Sku, PackKey, Openqty,UOM, ExtendedPrice, UnitPrice, Facility, UserDefine01, ExternPOKey )
                        SELECT @c_splitorderkey, --UD.Orderkey,  -- 17-Mar-2005 YTWan FBR33101: Split Order. 1 Order to 1 PO
                               @c_orddetlineno,  --UD.OrderLineNumber , -- 17-Mar-2005 YTWan FBR33101: Split Order. 1 Order to 1 PO
                               UD.StorerKey,
                               UD.ExternOrderKey,
                               UD.ExternLineNo,
                               UD.Sku,
                               Sku.PackKey,
                               UD.OpenQty,
                               ISNULL(UD.UOM, 'EA'),
                               UD.ExtendedPrice,
                               UD.UnitPrice,
                               ISNULL (UD.Facility, ''),
                               Rff,
                               ExternPOKey
                        FROM UploadC4OrderDetail UD (NOLOCK), Sku (NOLOCK)
                        WHERE UD.Sku = Sku.Sku
                          AND UD.StorerKey = Sku.StorerKey
                          AND UD.Status = '0'
                          AND UD.Orderkey = @c_orderkey
                          AND UD.OrderLineNumber = @c_detLineNumber
                        -- 25-Nov-2004 YTWan Xdock/FlowThrough Link - END

                        SELECT @n_err = @@ERROR

                        IF @n_err <> 0
                        BEGIN -- error occurred,
                           UPDATE UploadC4OrderDetail
                              SET Status = 'E', Remarks = '65003: ERROR INSERTING INTO OrderDetail'
                           WHERE Orderkey = @c_orderkey
                             AND OrderLineNumber = @c_detLineNumber
                        END
                        ELSE
                        BEGIN -- no errors,
                           UPDATE UploadC4OrderDetail
                              SET Status = '9', Remarks = 'TYPE 1'
                           WHERE Orderkey = @c_orderkey
                             AND OrderLineNumber = @c_detLineNumber
                        END
                     END -- WHILE (2=2)

                     SET ROWCOUNT 0
                  END --insert successful, UPDATE the Status = '9'
               END -- does not exists
            END -- @c_mode = 1
            ELSE
            IF @c_mode = '2'
            BEGIN
               IF EXISTS (SELECT 1 FROM Orders (NOLOCK) WHERE ExternOrderKey = @c_ExternOrderKey)
               BEGIN
                  UPDATE Orders
                     SET Orders.OrderDate     = OH.OrderDate,
                         Orders.DeliveryDate  = OH.DeliveryDate,
                         Orders.Priority      = OH.Priority,
                         Orders.c_contact1    = OH.c_contact1,
                         Orders.c_contact2    = OH.c_contact2,
                         Orders.c_company     = OH.C_company,
                         Orders.c_address1    = OH.C_Address1,
                         Orders.c_address2    = OH.C_Address2,
                         Orders.c_address3    = OH.C_Address3,
                         Orders.c_address4    = OH.C_Address4,
                         Orders.c_city        = OH.C_city,
                         Orders.c_state       = ISNULL(OH.c_state,' '),
                         Orders.c_zip         = ISNULL(OH.c_zip,' '),
                         Orders.buyerPO       = ISNULL(OH.BuyerPO, ' '),
                         Orders.Notes         = ISNULL(OH.Notes, ' ' ),
                         Orders.InvoiceNo     = ISNULL(OH.InvoiceNo, ' ' ),
                         Orders.Notes2        = ISNULL(OH.Notes2, ' ' ),
                         Orders.pmtterm       = ISNULL(OH.pmtterm, ' '),
                         Orders.Invoiceamount = OH.Invoiceamount ,
                         Orders.Route         = ISNULL(OH.Route, '99'),
                         Orders.Facility      = (Storer.Facility),
                         TrafficCop           = NULL
                  FROM Orders (NOLOCK), UploadC4OrderHeader OH (NOLOCK), Storer(NOLOCK)
                  WHERE Orders.ExternOrderKey = OH.ExternOrderKey
                    AND Orders.ExternOrderKey = @c_ExternOrderKey
                    AND Orders.SOStatus <> '9' -- ( when Status = '9', it's automatically closed )
                    AND OH.ExternOrderKey = @c_ExternOrderKey
                    AND Storer.StorerKey = @c_StorerKey
                    AND OH.Status = '0'
                    AND OH.Mode = @c_mode
                    AND OH.OrderGroup = @c_OrderGroup

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN -- error updating Orderheader
                     UPDATE UploadC4OrderHeader
                        SET Status = 'E', Remarks = '65005 : Unable to UPDATE Order table'
                     WHERE ExternOrderKey = @c_ExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode
                       AND Status = '0'
                  END
                  ELSE
                  BEGIN -- no error
                     UPDATE UploadC4OrderHeader
                        SET Status = '9', Remarks = ''
                     WHERE ExternOrderKey = @c_ExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode
                       AND Status = '0'

                     -- if header successfully updated, try detail
                     DECLARE CUR_ORDERDETAILUPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ExternOrderKey, ExternLineNo, Sku, OPENQTY, 'UOM' = ISNULL(UOM, 'EA'), ExternPOKey
                        FROM UploadC4OrderDetail (NOLOCK)
                        WHERE ExternOrderKey = @c_ExternOrderKey
                          AND Mode = @c_mode AND OrderGroup = @c_OrderGroup
                          AND Status = '0' AND OrderKey = @c_Orderkey
                        ORDER BY OrderGroup, ExternOrderKey, ExternLineNo

                     OPEN CUR_ORDERDETAILUPDATE
                     WHILE (1 = 1)
                     BEGIN
                        FETCH NEXT FROM CUR_ORDERDETAILUPDATE INTO @c_detExternOrderKey,
                                                                   @c_ExternLineno, @c_sku, @n_QtyOrdered, @c_uom, @c_ExternPOKey
                        IF @@FETCH_Status <> 0
                           BREAK

                        -- Check for OrderDetail Status, if qtyreceived > 0 , reject UPDATE
                        IF NOT EXISTS (SELECT 1 FROM OrderDetail (NOLOCK)
                                       WHERE ExternOrderKey = @c_detExternOrderKey
                                         AND ExternLineNo = @c_ExternLineno
                                         AND Shippedqty > 0 )
                        BEGIN
                           SELECT @c_packkey = PackKey FROM Sku (NOLOCK) WHERE Sku = @c_sku AND StorerKey = @c_StorerKey

                           UPDATE OrderDetail
                              SET Sku = @c_sku,
                                  Openqty = @n_QtyOrdered,
                                  UOM = @c_uom,
                                  PackKey = @c_packkey
                           WHERE ExternOrderKey = @c_detExternOrderKey
                             AND ExternLineNo = @c_ExternLineno
                             AND ShippedQty = 0

                           SELECT @n_err = @@ERROR

                           IF @n_err <> 0
                           BEGIN -- error occurred,
                              UPDATE UploadC4OrderDetail
                                 SET Status = 'E', Remarks = '65006: ERROR UPDATING OrderDetail'
                              WHERE ExternOrderKey = @c_detExternOrderKey
                                AND ExternLineNo = @c_ExternLineno
                                AND OrderGroup = @c_OrderGroup AND OrderKey = @c_Orderkey
                                AND Status = '0' AND Mode = @c_mode
                           END
                           ELSE
                           BEGIN -- no errors,
                              UPDATE UploadC4OrderDetail
                                 SET Status = '9', Remarks = 'TYPE 2'
                              WHERE ExternOrderKey = @c_detExternOrderKey
                                AND ExternLineNo = @c_ExternLineno
                                AND OrderGroup = @c_OrderGroup AND OrderKey = @c_Orderkey
                                AND Status = '0' AND Mode = @c_mode
                           END
                        END -- IF EXISTS
                     END -- WHILE (for cursor detail)
                     CLOSE CUR_ORDERDETAILUPDATE
                     DEALLOCATE CUR_ORDERDETAILUPDATE
                  END
               END -- IF EXISTS
               ELSE
               BEGIN
                  -- Added By SHONG ON 13th Feb 2008
                  -- Do not Mark AS Error, if the Records still sit inside the UploadC4OrderHeader AND
                  -- UploadC4OrderDetail
                  IF NOT EXISTS(SELECT 1 FROM UploadC4OrderHeader WHERE ExternOrderKey = @c_ExternOrderKey
                                AND Status = '0' AND Orderkey < @c_Orderkey)
                  BEGIN
                     UPDATE UploadC4OrderHeader
                        SET Status = 'E', Remarks = 'ExternOrderKey does not exists. UPDATE is not executed'
                     WHERE ExternOrderKey = @c_ExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode

                     UPDATE UploadC4OrderDetail
                        SET Status = 'E', Remarks = 'ExternOrderKey does not exists. UPDATE is not executed'
                     WHERE ExternOrderKey = @c_ExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode
                  END -- Not Exists in Temp Table UploadC4OrderHeader
               END -- IF NOT EXISTS in Orders Table
            END -- c_mode = '2'
            ELSE
            IF @c_mode = '3'
            BEGIN
               -- Added By SHONG ON 13th Feb 2008
               -- Do not Proceed, if the Records still sit inside the UploadC4OrderHeader AND
               -- UploadC4OrderDetail
               IF NOT EXISTS(SELECT 1 FROM UploadC4OrderHeader WHERE ExternOrderKey = @c_ExternOrderKey
                             AND Status = '0' AND Orderkey < @c_Orderkey)
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM Orders (NOLOCK) WHERE ExternOrderKey = @c_ExternOrderKey AND SOStatus = '9')
                  BEGIN
                     -- for  Mode = 3 (DELETE), Delete the details first, AND if all details has been deleted, delete the header.
                     DECLARE CUR_DELORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT ExternOrderKey, ExternLineNo, Orderkey, OrderLineNumber
                        FROM UploadC4OrderDetail (NOLOCK)
                        WHERE ExternOrderKey = @c_ExternOrderKey
                          AND OrderGroup = @c_OrderGroup
                          AND Mode = @c_mode
                          AND Status = '0'
                          AND OrderKey = @c_Orderkey
                        ORDER BY OrderGroup, ExternOrderKey, ExternLineNo

                     OPEN CUR_DELORDERDETAIL
                     WHILE (1=1)
                     BEGIN
                        FETCH NEXT FROM CUR_DELORDERDETAIL INTO @c_detExternOrderKey, @c_ExternLineno, @c_detOrderkey, @c_detLineNumber

                        IF @@FETCH_Status <> 0
                           BREAK

                        IF NOT EXISTS (SELECT 1 FROM OrderDetail (NOLOCK) WHERE ExternOrderKey = @c_detExternOrderKey AND ExternLineNo = @c_ExternLineno
                                       AND ShippedQty > 0)
                        BEGIN
                           DELETE OrderDetail
                           WHERE ExternOrderKey = @c_detExternOrderKey
                              AND ExternLineNo = @c_ExternLineno
                              AND ShippedQty = 0

                           SELECT @n_err = @@ERROR
                           SELECT @n_cnt = @@ROWCOUNT

                           IF @n_cnt > 0 AND @n_err = 0
                           BEGIN
                              UPDATE UploadC4OrderDetail
                                 SET Status = '9', Remarks = 'type 3'
                              WHERE ExternOrderKey = @c_detExternOrderKey
                                AND ExternLineNo = @c_ExternLineno
                                AND OrderGroup = @c_OrderGroup AND OrderKey = @c_Orderkey
                                AND Mode = @c_mode
                                AND Status = '0'
                           END
                           ELSE
                           BEGIN
                              UPDATE UploadC4OrderDetail
                                 SET Status = 'E', Remarks = '65009 : Unable to delete OrderDetail'
                              WHERE ExternOrderKey = @c_detExternOrderKey
                                AND ExternLineNo = @c_ExternLineno
                                AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                                AND Mode = @c_mode
                                AND Status = '0'
                           END
                        END
                        ELSE
                        BEGIN
                           UPDATE UploadC4OrderDetail
                              SET Status = 'E', Remarks = '65010 : OrderDetail has QtyShipped > 0'
                           WHERE ExternOrderKey = @c_detExternOrderKey
                             AND ExternLineNo = @c_ExternLineno
                             AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                             AND Mode = @c_mode
                             AND Status = '0'
                        END
                     END -- End WHILE (CUR_DELORDERDETAIL)
                     CLOSE CUR_DELORDERDETAIL
                     DEALLOCATE CUR_DELORDERDETAIL

                     -- after delete detail, count the balance of details, if no more detail lines, then delete the header
                     SELECT @count1 = COUNT(*) FROM OrderDetail (NOLOCK) WHERE ExternOrderKey = @c_ExternOrderKey

                     IF @count1 = 0
                     BEGIN
                        DELETE Orders
                        WHERE ExternOrderKey = @c_detExternOrderKey

                        SELECT @n_err = @@ERROR
                        SELECT @n_cnt = @@ROWCOUNT

                        IF @n_err = 0 AND @n_cnt > 0
                        BEGIN
                           UPDATE UploadC4OrderHeader
                              SET Status = '9', Remarks = ''
                           WHERE ExternOrderKey = @c_detExternOrderKey
                             AND OrderGroup = @c_OrderGroup AND Orderkey = @c_detOrderkey
                             AND Mode = @c_mode
                             AND Status = '0'
                        END
                     END
                  END -- if not exists
                  ELSE
                  BEGIN -- Order has been closed
                     UPDATE UploadC4OrderHeader
                        SET Status = 'E', Remarks = '65012: Order has been CLOSED'
                     WHERE ExternOrderKey = @c_detExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode
                       AND Status = '0'

                     UPDATE UploadC4OrderDetail
                        SET Status = 'E', Remarks = '65012: Order has been CLOSED'
                     WHERE ExternOrderKey = @c_detExternOrderKey
                       AND OrderGroup = @c_OrderGroup AND Orderkey = @c_Orderkey
                       AND Mode = @c_mode
                       AND Status = '0'
                  END -- Order has been closed
               END -- Not Exists in Temp Table UploadC4OrderHeader
            END -- for Mode = 3
            ELSE
            BEGIN -- everything fails
               UPDATE UploadC4OrderHeader
                  SET Status = 'E', Remarks = '65013 : Invalid Mode ,  ExternOrderKey or Status'
               WHERE ISNULL(RTRIM(ExternOrderKey),'') = ''
                  OR ISNULL(RTRIM(Status),'') = ''
                  OR ISNULL(RTRIM(Mode),'') = ''

               UPDATE UploadC4OrderDetail
                  SET Status = 'E', Remarks = '65014 : Invalid Mode, ExternOrderKey or Status'
               WHERE ISNULL(RTRIM(ExternOrderKey),'') = ''
                  OR ISNULL(RTRIM(Status),'') = ''
                  OR ISNULL(RTRIM(Mode),'') = ''
            END -- for all other reasons

            SELECT @count1 = COUNT(*) FROM UploadC4OrderHeader (NOLOCK)
            WHERE ExternOrderKey = @c_ExternOrderKey
              AND OrderGroup = @c_OrderGroup
              AND Mode = @c_mode

            IF @count1 > 0
            BEGIN
               SELECT @n_counter = @n_counter + 1
            END

            --SELECT @count1  = COUNT(*)
            --FROM UploadC4OrderHeader (NOLOCK)
            --WHERE ExternOrderKey = @c_ExternOrderKey
            --  AND OrderGroup = @c_OrderGroup
            --  AND Mode = @c_mode

            --IF @count1 > 0
            --BEGIN
            --   SELECT @n_counter = @n_counter + 1
            --END
         END -- WHILE --modulename = 'Order', big LOOP
         CLOSE CUR_ORDER
         DEALLOCATE CUR_ORDER
   -- END -- modulename = 'Order'
   END -- @n_continue = 1
   -- ---------------  -- Records is processed sequentially based ON the running number
   -- ------------------------
   IF @n_continue = 3  -- Error Occured - Process and Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspImportData_C4MY'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
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