SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_RFReceiving                                    */
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
/* 06-Sep-2005  Shong     6.5 to 2000 compatibility conversion          */
/* 24-Feb-2010  Shong     SOS#161714 TBL hub PDA multiple PO in one ASN */
/*                        handling                                      */
/************************************************************************/
CREATE PROC [dbo].[nsp_RFReceiving](
                               @c_externpokey NVARCHAR(20)
                              ,@c_pokey NVARCHAR(10)
                              ,@c_storerkey NVARCHAR(15)
                              ,@c_muid NVARCHAR(18)
                              ,@c_uccno NVARCHAR(20)
                              ,@c_sku NVARCHAR(20)
                              ,@c_toloc NVARCHAR(10)
                              ,@n_qty INT
                              ,@c_lottable02 NVARCHAR(18)
                           ) 
AS
BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_continue       INT
           ,@n_starttcnt      INT
           ,@b_success        INT
           ,@n_err            INT
           ,@c_errmsg         NVARCHAR(255)
           ,@local_n_err      INT
           ,@local_c_errmsg   NVARCHAR(255)
           ,@n_cnt            INT
           ,@n_rowcnt         INT
           ,@c_receiptkey     NVARCHAR(15)
           ,@c_receiptlineno  NVARCHAR(20)
           ,@c_facility       NVARCHAR(15)
           ,@c_packkey        NVARCHAR(10)
           ,@c_uom            NVARCHAR(10)
           ,@c_recvloc        NVARCHAR(10)
           ,@n_ucc_qty        INT
           ,@n_ucc_found      INT
           ,@c_polinenumber   NVARCHAR(5)
    
    SELECT @n_starttcnt = @@trancount
          ,@n_continue = 1
          ,@b_success = 0
          ,@n_err = 0
          ,@c_errmsg = ''
          ,@local_n_err = 0
          ,@local_c_errmsg = ''
    
    SELECT @c_receiptlineno = '00001'
    SELECT @n_ucc_qty = 0
    
    IF RTrim(@c_pokey) IS NULL OR RTrim(@c_pokey)=''
        SELECT @c_pokey = ''
    
    IF EXISTS(
           SELECT 1
           FROM   UCC(NOLOCK)
           WHERE  UCCNo = @c_uccno
                  AND Storerkey = @c_storerkey
       )
    BEGIN
        SELECT @n_ucc_qty = qty
              ,@n_ucc_found = 1
        FROM   UCC(NOLOCK)
        WHERE  UCCNo = @c_uccno
               AND Storerkey = @c_storerkey
    END
    
    IF (@n_continue=1 OR @n_continue=2)
    BEGIN
        SELECT @c_packkey = PACK.Packkey
              ,@c_uom = PACK.PackUOM3
        FROM   SKU(NOLOCK)
              ,PACK(NOLOCK)
        WHERE  SKU.Packkey = PACK.Packkey
               AND SKU.Storerkey = @c_storerkey
               AND SKU.SKU = @c_sku
        
        SELECT @c_receiptkey = Receiptkey
              ,@c_receiptlineno = ReceiptLineNumber
              ,@c_recvloc = Toloc
        FROM   RECEIPTDETAIL(NOLOCK)
        WHERE  Storerkey = @c_storerkey
               AND SKU = @c_sku
               AND ExternReceiptKey = @c_externpokey
               AND POKey = @c_pokey
               AND Toid = @c_muid
               AND Lottable02 = @c_lottable02
               AND ExternLineNo = @c_uccno
        
        IF RTrim(@c_receiptkey)<>''
           AND RTrim(@c_receiptkey) IS NOT NULL
        BEGIN
            -- Check pallet id receives into the same loc
            IF @c_recvloc<>@c_toloc
            BEGIN
                SELECT @n_continue = 3
                SELECT @local_n_err = 77301
                SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                SELECT @local_c_errmsg = 
                       ': Pallet ID is received to different Location. (nsp_RFReceiving) ' 
                      +' ( '+
                       ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                      +')'
            END 
            
            IF (@n_continue=1 OR @n_continue=2)
            BEGIN
                UPDATE RECEIPTDETAIL
                SET    QtyExpected = QtyExpected+@n_ucc_qty
                      ,BeforeReceivedQty = BeforeReceivedQty+@n_qty
                      ,QtyAdjusted = 0
                WHERE  ReceiptKey = @c_receiptkey
                       AND ReceiptLineNumber = @c_receiptlineno 
                
                SELECT @local_n_err = @@error
                      ,@n_cnt = @@rowcount
                
                IF @local_n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77302
                    SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                    SELECT @local_c_errmsg = 
                           ': update of Receiptdetail table failed. (nsp_RFReceiving) ' 
                          +' ( '+
                           ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                          +')'
                END
            END
        END
        ELSE
        BEGIN
            --Check uccno exist in RECEIPT, if exists cannot create ASN / ASNDetail
            IF @c_externpokey<>'RETURN'
            BEGIN
                SELECT @c_receiptkey = RECEIPTDETAIL.ReceiptKey
                FROM   RECEIPTDETAIL(NOLOCK)
                WHERE  StorerKey = @c_storerkey -- Added by SHONG (Performance reason)
                       AND ExternLineNo = @c_uccno
                
                IF RTrim(@c_receiptkey)<>''
                   AND @c_receiptkey IS NOT NULL
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77307
                    SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                    SELECT @local_c_errmsg = 
                           ': UCC is received to different PalletID or Loc or Lottable02. (nsp_RFReceiving) ' 
                          +' ( '+
                           ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                          +')'
                END
            END
            
            IF (@n_continue=1 OR @n_continue=2)
            BEGIN
                SELECT @c_facility = Facility
                FROM   LOC(NOLOCK)
                WHERE  LOC = @c_toloc
                
                -- Check received data are the same externpokey and pokey and received to same facility
                -- If no, create a new ASN
                SELECT TOP 1 @c_receiptkey = RECEIPTDETAIL.ReceiptKey
                FROM   RECEIPTDETAIL(NOLOCK)
                      ,RECEIPT(NOLOCK)
                WHERE  RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey
                       AND RECEIPTDETAIL.Storerkey = @c_storerkey
                       AND RECEIPTDETAIL.ExternReceiptKey = @c_externpokey
                       AND RECEIPTDETAIL.POKey = @c_pokey
                       AND RECEIPT.Facility = @c_facility
                       AND RECEIPT.Status = '0'
                       AND RECEIPT.ASNStatus = '0'
                
                IF RTrim(@c_receiptkey)=''
                   OR @c_receiptkey IS NULL 
                BEGIN
                    EXECUTE nspg_getkey
                    "Receipt" ,
                    10 ,
                    @c_receiptkey OUTPUT ,
                    @b_success=@b_success OUTPUT,
                    @n_err=@n_err OUTPUT,
                    @c_errmsg=@c_errmsg OUTPUT
                    
                    IF NOT @b_success=1
                    BEGIN
                        SELECT @n_continue = 3
                    END
                    
                    IF (@n_continue=1 OR @n_continue=2)
                    BEGIN
                        IF @c_externpokey<>'RETURN'
                            INSERT INTO RECEIPT
                              (
                                Receiptkey, Storerkey, Facility, 
                                ExternReceiptKey
                              )
                            VALUES
                              (
                                @c_receiptkey, @c_storerkey, @c_Facility, @c_externpokey
                              )
                        ELSE
                            INSERT INTO RECEIPT
                              (
                                Receiptkey, Storerkey, Facility, 
                                ExternReceiptKey, DocType
                              )
                            VALUES
                              (
                                @c_receiptkey, @c_storerkey, @c_Facility, @c_externpokey, 
                                'R'
                              )
                        
                        SELECT @local_n_err = @@error
                              ,@n_cnt = @@rowcount
                        
                        IF @local_n_err<>0
                        BEGIN
                            SELECT @n_continue = 3
                            SELECT @local_n_err = 77303
                            SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                            SELECT @local_c_errmsg = 
                                   ': Insert of Receipt table failed. (nsp_RFReceiving) ' 
                                  +' ( '+
                                   ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                                  +')'
                        END
                    END
                END
                ELSE
                BEGIN
                    SELECT @c_receiptlineno = MAX(ReceiptLineNumber)
                    FROM   RECEIPTDETAIL(NOLOCK)
                    WHERE  ReceiptKey = @c_receiptkey
                    
                    SELECT @c_receiptlineno = RIGHT(
                               RTrim('00000'+CONVERT(CHAR(5) ,CONVERT(INT ,@c_receiptlineno+1)))
                              ,5
                           )
                END 
                
                
                IF (@n_continue=1 OR @n_continue=2)
                BEGIN
                    -- get polinenumber
                    SELECT @c_polinenumber = polinenumber
                    FROM   PODETAIL(NOLOCK)
                    WHERE  pokey = @c_pokey
                           AND externlineno = @c_uccno
                           AND sku = @c_sku
                    
                    IF RTrim(@c_polinenumber) IS NULL
                       OR RTrim(@c_polinenumber)=''
                    BEGIN
                       -- SOS#161714 TBL hub PDA multiple PO in one ASN handling
                       IF LEFT(@c_uccno,1) = 'G' 
                       BEGIN
                           SELECT TOP 1 @c_polinenumber = polinenumber
                           FROM   PODETAIL(NOLOCK)
                           WHERE  pokey = @c_pokey
                                  AND sku = @c_sku
                                  AND MarksContainer = SUBSTRING(@c_uccno, 2, 6)                          
                       END
                       
                       IF ISNULL(RTrim(@c_polinenumber),'')=''
                       BEGIN
                           -- invalid UCC from podetail : match by pokey and sku
                           SELECT @c_polinenumber = MIN(polinenumber)
                           FROM   PODETAIL(NOLOCK)
                           WHERE  pokey = @c_pokey
                                  AND sku = @c_sku                          
                       END
                    END
                    
                    INSERT INTO RECEIPTDETAIL
                      (
                        Receiptkey, ReceiptLineNumber, ExternLineNo, 
                        POLineNumber, Storerkey, Sku, Packkey, UOM, QtyExpected, 
                        QtyAdjusted, BeforeReceivedQty, ExternReceiptKey, POKey, 
                        Toid, ToLoc, Lottable02, Lottable05, Tariffkey
                      )
                    VALUES
                      (
                        @c_receiptkey, @c_receiptlineno, CASE @c_externpokey
                                                              WHEN 'RETURN' THEN 
                                                                   ''
                                                              ELSE @c_uccno
                                                         END, 	-- externlineno
                        @c_polinenumber, @c_storerkey, @c_sku, @c_packkey, @c_uom, 
                        @n_ucc_qty, 	   -- qtyexpected
                        0, 	            -- qtyadjusted
                        @n_qty, 	         -- beforereceivedqty
                        @c_externpokey, 	-- externreceiptkey
                        CASE @c_externpokey
                             WHEN 'NOPO' THEN ''
                             ELSE @c_pokey
                        END, 	-- pokey
                        @c_muid, @c_toloc, @c_lottable02, CONVERT(CHAR(10) ,GETDATE() ,102), 
                        'XXXXXXXXXX'
                      )
                    
                    SELECT @local_n_err = @@error
                          ,@n_cnt = @@rowcount
                    
                    IF @local_n_err<>0
                    BEGIN
                        SELECT @n_continue = 3
                        SELECT @local_n_err = 77304
                        SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                        SELECT @local_c_errmsg = 
                               ': Insert of Receiptdetail table failed. (nsp_RFReceiving) ' 
                              +' ( '+
                               ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                              +')'
                    END
                END
            END
        END -- Insert or Update Receipt
        
        IF (@n_continue=1 OR @n_continue=2)
           AND @c_externpokey<>'RETURN'
        BEGIN
            IF @n_ucc_found=1
            BEGIN
                UPDATE UCC
                SET    ReceiptKey = @c_receiptkey
                      ,ReceiptLineNumber = @c_receiptlineno
                       --              Qty               = @n_qty
                WHERE  UCCNo = @c_uccno
                       AND Storerkey = @c_storerkey
                
                SELECT @local_n_err = @@error
                      ,@n_cnt = @@rowcount
                
                IF @local_n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77305
                    SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                    SELECT @local_c_errmsg = 
                           ': Insert of UCC table failed. (nsp_RFReceiving) '+
                           ' ( '+
                           ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                          +')'
                END
            END
            ELSE
            BEGIN
                INSERT INTO UCC
                  (
                    UCCNo, Storerkey, Sku, Qty, STATUS, ExternKey, Receiptkey, 
                    ReceiptLineNumber
                  )
                VALUES
                  (
                    @c_uccno, @c_storerkey, @c_sku, @n_qty, '0', @c_externpokey, 
                    @c_receiptkey, @c_receiptlineno
                  )
                
                SELECT @local_n_err = @@error
                      ,@n_cnt = @@rowcount
                
                IF @local_n_err<>0
                BEGIN
                    SELECT @n_continue = 3
                    SELECT @local_n_err = 77306
                    SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                    SELECT @local_c_errmsg = 
                           ': Insert of UCC table failed. (nsp_RFReceiving) '+
                           ' ( '+
                           ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                          +')'
                END
            END
        END-- Insert or Update UCC
    END
    
    -- Start : SOS31211 - Raise Error if Receiptdetail or UCC not successfully inserted
    IF (@n_continue=1 OR @n_continue=2)
       AND @c_externpokey<>'RETURN'
    BEGIN
        IF NOT EXISTS (
               SELECT 1
               FROM   RECEIPTDETAIL(NOLOCK)
               WHERE  Receiptkey = @c_receiptkey
                      AND ReceiptLineNumber = @c_receiptlineno
                      AND ExternLineNo = @c_uccno
           )
        BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err = 77307
            SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
            SELECT @local_c_errmsg = 
                   ': Insert of ReceiptDetail table failed. (nsp_rfreceiving) ' 
                  +' ( '+
                   ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                  +')'
        END
        
        IF NOT EXISTS (
               SELECT 1
               FROM   UCC(NOLOCK)
               WHERE  UccNo = @c_uccno
                      AND Storerkey = @c_storerkey
           )
        BEGIN
            SELECT @n_continue = 3
            SELECT @local_n_err = 77308
            SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
            SELECT @local_c_errmsg = 
                   ': Insert of UCC table failed. (nsp_rfreceiving) '+' ( '+
                   ' sqlsvr message = '+LTrim(RTrim(@local_c_errmsg)) 
                  +')'
        END
    END
    -- End : SOS31211 
    
    
    IF @n_continue=3 -- error occured - process and return
    BEGIN
        SELECT @b_success = 0
        IF @@trancount=1
           AND @@trancount>@n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@trancount>@n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END
        
        SELECT @n_err = @local_n_err
        SELECT @c_errmsg = @local_c_errmsg
        EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_RFReceiving"
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
    END
    ELSE
    BEGIN
        SELECT @b_success = 1
        WHILE @@trancount>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END
        RETURN
    END
END

GO