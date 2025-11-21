SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Trigger: ntrReceiptDetailDelete                                      */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By: When delete records in ReceiptDetail                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2010-06-18   SHONG    1.1  Insert TableDeleteLog                     */
/* 28-Apr-2011  KHLim01  1.2  Insert Delete log                         */
/* 14-Jul-2011  KHLim02  1.3  GetRight for Delete log                   */
/* 08-Feb-2012  Shong    1.4  Reverse UCC.Status If ReceiptLine Deleted */
/* 26-Oct-2015  YTWan    1.5  SOS#353512 - Project Merlion - GW FRR     */
/*                            Suggested Putaway Location (Wan01)        */
/* 03-May-2017  NJOW01   1.6    WMS-1798 Allow config to call custom sp */
/* 22-Oct-2019  TLTING01 1.7  Blocking tuning                           */
/* 14-Oct-2021  KSChin   1.8  add tracker to DEL_ReceiptDetail table    */
/************************************************************************/  
CREATE TRIGGER [dbo].[ntrReceiptDetailDelete]
ON [dbo].[RECEIPTDETAIL]
FOR  DELETE
AS
BEGIN
    SET NOCOUNT ON  
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF  
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @b_debug INT  
    SELECT @b_debug = 0  
    IF @b_debug=1
    BEGIN
        SELECT 'DELETED ',*
        FROM   DELETED
    END  

    DECLARE @b_Success    INT	-- Populated by calls to stored procedures - was the proc successful?
           ,@n_err        INT	-- Error number returned by stored procedure or this trigger
           ,@c_errmsg     NVARCHAR(250)	-- Error message returned by stored procedure or this trigger
           ,@n_continue   INT	-- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           ,@n_starttcnt  INT	-- Holds the current transaction count
           ,@n_cnt        INT -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
           ,@c_authority  NVARCHAR(1)  -- KHLim02
    SELECT @n_continue = 1
          ,@n_starttcnt = @@TRANCOUNT 

   --(Wan01) - START
   DECLARE @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ReceiptKey         NVARCHAR(10)
         , @c_ReceiptLineNumber  NVARCHAR(5)
         , @c_ReservePAloc       NVARCHAR(10)
         , @c_Lot                NVARCHAR(10)
         , @c_PutawayLoc              NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)
         , @n_QtyReceived        INT
         , @n_UCC_RowRef         INT
   --(Wan01) - END 
    /* #INCLUDE <TRRDD1.SQL> */       
    IF (
           SELECT COUNT(*)
           FROM   DELETED
       )=(
           SELECT COUNT(*)
           FROM   DELETED
           WHERE  DELETED.ArchiveCop = '9'
       )
    BEGIN
        SELECT @n_continue = 4
    END  
    
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        IF EXISTS(
               SELECT *
               FROM   DELETED
               WHERE  QtyReceived>0
           )
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 64201 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Delete Trigger On Table RECEIPTDETAIL Failed - QtyReceived must be zero. (ntrReceiptDetailDelete)' 
                  +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
                  +' ) '
        END
    END  
    
    IF @n_continue=1
       OR @n_continue=2
    BEGIN
        DELETE CASEMANIFEST
        FROM   CASEMANIFEST
              ,DELETED
        WHERE  CASEMANIFEST.ExpectedReceiptKey = DELETED.ReceiptKey
               AND CASEMANIFEST.StorerKey = DELETED.StorerKey
               AND CASEMANIFEST.Sku = DELETED.Sku
               AND CASEMANIFEST.ExpectedPOKey = DELETED.POKey
               AND CASEMANIFEST.Status<>'9'
        
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 64203 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Delete Trigger On Table CASEMANIFEST Failed - QtyReceived must be zero. (ntrReceiptDetailDelete)' 
                  +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
                  +' ) '
        END
        ELSE 
        IF @b_debug=1
        BEGIN
            SELECT @n_cnt  
            SELECT ReceivedReceiptKey
                  ,StorerKey
                  ,Sku
                  ,ReceivedPOKey
            FROM   CASEMANIFEST
            
            SELECT ReceiptKey
                  ,StorerKey
                  ,Sku
                  ,POKey
            FROM   DELETED
        END
    END  

    --NJOW01
    IF @n_continue=1 or @n_continue=2          
    BEGIN   	  
       IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                  JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                  JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                  WHERE  s.configkey = 'ReceiptDetailTrigger_SP')   -----> Current table trigger storerconfig
       BEGIN        	  
          IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
             DROP TABLE #INSERTED
    
       	 SELECT * 
       	 INTO #INSERTED
       	 FROM INSERTED
           
          IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
             DROP TABLE #DELETED
    
       	 SELECT * 
       	 INTO #DELETED
       	 FROM DELETED
    
          EXECUTE dbo.isp_ReceiptDetailTrigger_Wrapper ----->wrapper for current table trigger
                    'DELETE'  -----> @c_Action can be INSERT, UPDATE, DELETE
                  , @b_Success  OUTPUT  
                  , @n_Err      OUTPUT   
                  , @c_ErrMsg   OUTPUT  
    
          IF @b_success <> 1  
          BEGIN  
             SELECT @n_continue = 3  
                   ,@c_errmsg = 'ntrReceiptDetailDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
          END  
          
          IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
             DROP TABLE #INSERTED
    
          IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
             DROP TABLE #DELETED
       END
    END      
    
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        DECLARE @n_deletedcount INT  
        SELECT @n_deletedcount = (
                   SELECT COUNT(*)
                   FROM   DELETED
               )
        
        IF @n_deletedcount=1
        BEGIN
            UPDATE RECEIPT
            SET    OpenQty = RECEIPT.OpenQty-(DELETED.QtyExpected- DELETED.QtyReceived)
            FROM   RECEIPT
                  ,DELETED
            WHERE  RECEIPT.ReceiptKey = DELETED.ReceiptKey
        END
        ELSE
        BEGIN
            UPDATE RECEIPT
            SET    RECEIPT.OpenQty = (
                       RECEIPT.Openqty 
                      -(
                           SELECT SUM(DELETED.QtyExpected- DELETED.QtyReceived)
                           FROM   DELETED
                           WHERE  DELETED.Receiptkey = RECEIPT.Receiptkey
                       )
                   )
            FROM   RECEIPT
                  ,DELETED
            WHERE  RECEIPT.Receiptkey IN (SELECT DISTINCT Receiptkey
                                          FROM   DELETED)
                   AND RECEIPT.Receiptkey = DELETED.Receiptkey
        END  
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 64205 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Insert failed on table RECEIPT. (ntrReceiptDetailDelete)' 
                  +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
                  +' ) '
        END
    END  
    
    IF @n_continue=1 OR @n_continue=2
    BEGIN
        DELETE LOTxIDDETAIL
        FROM   DELETED
        WHERE  DELETED.ReceiptKey = LOTxIDDETAIL.ReceiptKey
               AND DELETED.ReceiptLineNumber = LOTxIDDETAIL.ReceiptLineNumber
        
        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT
        
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
                  ,@n_err = 64206 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Delete failed on table LOTxIDDETAIL. (ntrReceiptDetailDelete)' 
                  +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
                  +' ) '
        END
    END 
    
    -- FOR UCC Tracking  
    IF @n_continue=1 OR @n_continue=2
    BEGIN
       -- TLTING01 Blocking tune
      DECLARE CUR_RCPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT    UCC.UCC_RowRef
      FROM   UCC   (NOLOCK)            
      JOIN DELETED ON  UCC.ReceiptKey = DELETED.ReceiptKey
               AND UCC.ReceiptLineNumber = DELETED.ReceiptLineNumber  
         

      OPEN CUR_RCPT

      FETCH NEXT FROM CUR_RCPT INTO @n_UCC_RowRef 
 
      WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         UPDATE UCC with (ROWLOCK)
           SET    ReceiptKey = ''
                 ,ReceiptLineNumber = ''
                 ,[Status] = CASE WHEN UCC.[Status] = '1' THEN '0' ELSE UCC.[Status] END  
          WHERE UCC_RowRef = @n_UCC_RowRef
        
           SELECT @n_err = @@ERROR 
        
           IF @n_err<>0
           BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
               SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                      ': Delete failed on table LOTxIDDETAIL. (ntrReceiptDetailDelete)' 
                     +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
                     +' ) '
           END
         FETCH NEXT FROM CUR_RCPT INTO @n_UCC_RowRef 
      END
      CLOSE CUR_RCPT
      DEALLOCATE CUR_RCPT

        --UPDATE UCC
        --SET    ReceiptKey = ''
        --      ,ReceiptLineNumber = ''
        --      ,[Status] = CASE WHEN UCC.[Status] = '1' THEN '0' ELSE UCC.[Status] END  
        --FROM   UCC               
        --JOIN DELETED ON  UCC.ReceiptKey = DELETED.ReceiptKey
        --             AND UCC.ReceiptLineNumber = DELETED.ReceiptLineNumber  
        
        --SELECT @n_err = @@ERROR
        --      ,@n_cnt = @@ROWCOUNT
        
        --IF @n_err<>0
        --BEGIN
        --    SELECT @n_continue = 3  
        --    SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)  
        --    SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
        --           ': Delete failed on table LOTxIDDETAIL. (ntrReceiptDetailDelete)' 
        --          +' ( '+' SQLSvr MESSAGE='+LTrim(RTrim(@c_errmsg)) 
        --          +' ) '
        --END
    END 

   --(Wan01) - START
   DECLARE CUR_RCPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT 
          RECEIPT.Facility
         ,RECEIPT.Storerkey
         ,RECEIPT.ReceiptKey
   FROM DELETED 
   JOIN RECEIPT WITH (NOLOCK) ON (RECEIPT.Receiptkey = DELETED.Receiptkey)
 
   OPEN CUR_RCPT

   FETCH NEXT FROM CUR_RCPT INTO @c_Facility
                              ,  @c_Storerkey
                              ,  @c_ReceiptKey
 
   WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SET @c_ReservePAloc = '0'
      EXECUTE nspGetRight
               @c_Facility       -- Facility
            ,  @c_StorerKey      -- Storer
            ,  NULL              -- Sku
            ,  'ReservePAloc'    -- ConfigKey
            ,  @b_success        OUTPUT 
            ,  @c_ReservePAloc   OUTPUT 
            ,  @n_err            OUTPUT 
            ,  @c_errmsg         OUTPUT

      IF @b_Success <> 1 
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(CHAR(250),@n_err)
         SET @n_err = 64207   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Retrieve Failed On GetRight - ReservePAloc. (ntrReceiptDetailDelete)' 
                      + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) '
      END

      IF @c_ReservePAloc = '1' AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         DECLARE CUR_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT ReceiptLineNumber
               ,PutawayLoc
               ,ToID
               ,QtyReceived
         FROM DELETED 
         WHERE Receiptkey = @c_ReceiptKey
         AND   QtyReceived > 0 
         AND   FinalizeFlag = 'Y'
         AND   ISNULL(PutawayLoc,'') <> ''
         ORDER BY ReceiptLineNumber
       
         OPEN CUR_DET

         FETCH NEXT FROM CUR_DET INTO @c_ReceiptLineNumber
                                    , @c_PutawayLoc
                                    , @c_ToID
                                    , @n_QtyReceived
          
         WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SET @c_Lot = ''
            SELECT @c_Lot = Lot
            FROM ITRN WITH (NOLOCK)
            WHERE Sourcekey = RTRIM(@c_ReceiptKey) + RTRIM(@c_ReceiptLineNumber)
            AND TranType = 'DP'
            AND SourceType IN ( 'ntrReceiptDetailAdd', 'ntrReceiptDetailUpdate' )
   
            IF @c_Lot <> ''
            BEGIN
               UPDATE LOTxLOCxID WITH (ROWLOCK)
               SET PendingMoveIn = PendingMoveIn - @n_QtyReceived
               WHERE Lot = @c_Lot
               AND   Loc = @c_PutawayLoc
               AND   ID  = @c_ToID

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(CHAR(250),@n_err)
                  SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) 
                      + ': Update failed on table LOTxLOCxID. (ntrReceiptDetailDelete)'
                      + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) ' 
               END
            END

            FETCH NEXT FROM CUR_DET INTO  @c_ReceiptLineNumber
                                       ,  @c_PutawayLoc
                                       ,  @c_ToID
                                       ,  @n_QtyReceived
         END
      END

      FETCH NEXT FROM CUR_RCPT INTO @c_Facility
                                 ,  @c_Storerkey
                                 ,  @c_ReceiptKey
   END
   CLOSE CUR_RCPT
   DEALLOCATE CUR_RCPT
   --(Wan01) - END
    
    /*INSERT INTO TableDeleteLog
    (
       TableName,   Col1,    Col2,    Col3,   Col4,  Col5, Remarks
    )
    SELECT 'RECEIPTDETAIL', RECEIPTKEY, RECEIPTLINENUMBER, STORERKEY, SKU, CAST(QtyExpected AS NVARCHAR(30)),
           ' PO# ' + ISNULL(POKey,'') + ' PO Line# ' + ISNULL(POLineNumber,'') 
    FROM   DELETED  */ 

   -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrReceiptDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.RECEIPTDETAIL_DELLOG ( ReceiptKey, ReceiptLineNumber )
         SELECT ReceiptKey, ReceiptLineNumber FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table RECEIPTDETAIL Failed. (ntrReceiptDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 
   -- Added by KS Chin 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN  
   IF EXISTS(SELECT 1 FROM DEL_RECEIPTDETAIL WITH (NOLOCK) 
               JOIN DELETED ON DELETED.ReceiptKey = DEL_RECEIPTDETAIL.ReceiptKey AND DELETED.ReceiptLineNumber=DEL_RECEIPTDETAIL.ReceiptLineNumber )
      BEGIN
         DELETE  DEL_RECEIPTDETAIL
         FROM   DEL_RECEIPTDETAIL
         JOIN   DELETED ON DELETED.ReceiptKey = DEL_RECEIPTDETAIL.ReceiptKey AND DELETED.ReceiptLineNumber=DEL_RECEIPTDETAIL.ReceiptLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete DEL_RECEIPTDETAIL Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END   
      INSERT INTO DEL_RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, POKey, 
            Sku, AltSku, Id, Status, DateReceived, QtyExpected, QtyAdjusted, QtyReceived, UOM,
            PackKey, VesselKey, VoyageKey, XdockKey, ContainerKey, ToLoc, ToLot, ToId, ConditionCode,
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, CaseCnt, InnerPack,
            Pallet, Cube, GrossWgt, NetWgt, OtherUnit1, OtherUnit2, UnitPrice, ExtendedPrice,
            EffectiveDate, AddDate, AddWho, EditDate, EditWho, TrafficCop, ArchiveCop, TariffKey,  
            FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode, FinalizeFlag, DuplicateFrom,
            BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag, POLineNumber, LoadKey,
            ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Lottable06,
	         Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13,
	         Lottable14, Lottable15, Channel, Channel_ID)
      SELECT ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, POKey, 
            Sku, AltSku, Id, Status, DateReceived, QtyExpected, QtyAdjusted, QtyReceived, UOM,
            PackKey, VesselKey, VoyageKey, XdockKey, ContainerKey, ToLoc, ToLot, ToId, ConditionCode,
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, CaseCnt, InnerPack,
            Pallet, Cube, GrossWgt, NetWgt, OtherUnit1, OtherUnit2, UnitPrice, ExtendedPrice,
            EffectiveDate, getdate(), suser_sname(), EditDate, EditWho, TrafficCop, ArchiveCop, TariffKey,  
            FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode, FinalizeFlag, DuplicateFrom,
            BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag, POLineNumber, LoadKey,
            ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, 
            UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, Lottable06,
	         Lottable07, Lottable08, Lottable09, Lottable10, Lottable11, Lottable12, Lottable13,
	         Lottable14, Lottable15, Channel, Channel_ID FROM DELETED 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62401   
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert DEL_RECEIPT Failed. (ntrOrderHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END    -- Added End by KS Chin

    /* #INCLUDE <TRRDD2.SQL> */  
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        IF @@TRANCOUNT=1
           AND @@TRANCOUNT>=@n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END 
        EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrReceiptDetailDelete' 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
        RETURN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END 
        RETURN
    END
END  


GO