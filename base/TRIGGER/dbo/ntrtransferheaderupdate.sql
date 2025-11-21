SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Name     : ntrTransferHeaderUpdate                                   */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:                                                             */
/* Transfer table, update trigger                                       */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Exceed version: 6.0                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 05-Aug-2002  Admin     1.0   Initial revision                        */
/* 06-Nov-2002  Leo Ng    1.0   Program rewrite for IDS version 5       */
/* 21-Apr-2003  wjtan     1.0   TBL HK - FBR10621                       */
/* 26-Apr-2003  YokeBeen  1.0   Changed on TransmitLogKey2 for IDSHK TBL*/
/* 20-May-2003  YokeBeen  1.0   Changed by YokeBeen - Sent from Jeffrey */
/*                              for IDSHK TBL                           */
/* 18-Nov-2003  YokeBeen  1.0   For NSC Project                         */
/* 16-Feb-2004  YokeBeen  1.0   For NSC Project - SOS#20000             */
/* 24-Feb-2004  YokeBeen  1.0   For SOS#20000 NSC Project               */
/* 12-Jul-2004  wtshong   1.0   Only certain Reason Code require for    */
/*                              interface                               */
/* 17-Jan-2005  mvong     1.0   Merged SOS25798 C4 Interface            */
/* 06-Jun-2005  mvong     1.0   SOS32152 Export Finalized Transfer      */
/*                              (check-in for Wan)                      */
/* 04-Jul-2005  dhung     1.0   Added TXFLOG interface                  */
/* 08-Jul-2005  Vicky     1.0   Added TRFLOG as Configkey for Interface */
/*                              with transmitlog3.key2 = ReasonCode     */
/* 2006-06-08   Vicky     1.0   SOS#51627 - Insertion of CIBATRF only   */
/*                              when Codelkup.Listname = 'TRANTYPE' and */
/*                              Codelkup.Long = 'CV'                    */
/* 2007-02-22   June      1.0   SOS68834 - Add configkey 'INVTRFITF'	*/
/* 2008-08-19   Leong     1.0   SOS114421 - change StorerKey to 'C4TH'  */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()     */
/* 03-Nov-2010  YokeBeen  1.2   FBR#195034 - Added new trigger point    */
/*                              for WITRON interface with               */
/*                              Configkey = "WTNTRFLOG". - (YokeBeen01) */
/* 25 May2012   TLTING02  1.3   DM integrity - add update editdate B4   */
/*                              TrafficCop                              */
/* 28-Oct-2013  TLTING    1.4   Review Editdate column update           */
/* 22-Apr-2014  YokeBeen  1.5   Revised and moved the trigger points to */
/*                              a Sub-SP - isp_ITF_ntrTransfer.         */
/*                              - (YokeBeen02)                          */
/* 07-MAY-2014  YTWan     1.5   Add New RCM to Cancel Transfer in Exceed*/
/*                              Front end. (Wan01)                      */
/* 01-JUL-2014  YTWan     1.5   SOS#314107 - ANF RetailDTC Finalize     */
/*                              Transfer with zero qty transfer. (Wan02)*/
/* 18-Aug-2015  MCTang    1.6   Add New Trigger SOS#336465 (MC01)       */
/* 21-Feb-2015  TLTING03  1.6   Block update finalised Transfer         */
/* 01-Mar-2022  NJOW01    1.7   WMS-19042 update diffrent value for     */
/*                              TRFLOG transmitlog by config            */
/* 01-Mar-2022  NJOW01    1.7   DEVOPS combine script                   */
/* 07-Apr-2022  CLVN01    1.8   JSM-61467 Fix Missed Deployment         */
/************************************************************************/

CREATE    TRIGGER [dbo].[ntrTransferHeaderUpdate]
ON  [dbo].[TRANSFER]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success               int         -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                   int         -- Error number returned by stored procedure or this trigger
         , @n_err2                  int         -- For Additional Error Detection
         , @c_errmsg                NVARCHAR(250)   -- Error message returned by stored procedure or this trigger
         , @n_continue              int
         , @n_starttcnt             int         -- Holds the current transaction count
         , @c_preprocess            NVARCHAR(250)   -- preprocess
         , @c_pstprocess            NVARCHAR(250)   -- post process
         , @n_cnt                   int
         , @c_transferkey           NVARCHAR(10)
         , @c_authority             NVARCHAR(1)

   DECLARE @c_storerkey             NVARCHAR(10)
         , @c_trmlogkey             NVARCHAR(10)
         , @c_TBLHKITF              NVARCHAR(1)
         , @c_NIKEREGITF            NVARCHAR(1)
         , @c_C4ITF                 NVARCHAR(1)    -- Added by MaryVong on 23-Aug-2004 (SOS25798-C4)
         , @c_CibaITF               NVARCHAR(1)    -- Added by YTWan on 24-Feb-2005 (SOS32152)
         , @c_TRFLOG                NVARCHAR(1)
         , @c_trantype              NVARCHAR(12)   -- Added by Vicky on 08-June-2006 (SOS#51627)
         , @c_INVTRFITF             NVARCHAR(1)    -- Added by June on 22-Feb-2007 (SOS68834)
         , @c_authority_wtntrfitf   NVARCHAR(1)    -- (YokeBeen01)
         , @c_MSFTRFITF             NVARCHAR(1)    -- (MC01)
         , @c_TransferType          NVARCHAR(12)   -- NJOW01
         , @c_CustomerRefno         NVARCHAR(20)   -- NJOW01
         , @c_TRFLOG_Opt5           NVARCHAR(4000) -- NJOW01
         , @c_PickRequest_TrfType   NVARCHAR(30)   -- NJOW01

   --(YokeBeen02) - START
   DECLARE @c_FromStorerKey         nvarchar(15)
         , @c_ToStorerKey           nvarchar(15)
         , @c_TriggerName           nvarchar(120)
         , @c_SourceTable           nvarchar(60)
         , @c_Status                nvarchar(10)

   SET @c_TriggerName = 'ntrTransferHeaderUpdate'
   SET @c_SourceTable = 'TRANSFER'
   --(YokeBeen02) - END

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   -- tlting01
   IF  EXISTS ( SELECT 1 FROM INSERTED, DELETED
                Where INSERTED.TransferKey = DELETED.TransferKey
                AND (( INSERTED.[Status] < '9' OR DELETED.[Status] < '9' )  OR      --(Wan01)
                     ( INSERTED.[Status] = 'CANC' OR DELETED.[Status] = 'CANC' )))  --(Wan01)
          AND ( @n_continue=1 or @n_continue=2 )
          AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE TRANSFER
      SET EditDate = GETDATE(),
      EditWho     = Suser_Sname(),
      TrafficCop  = NULL
      FROM TRANSFER, INSERTED, DELETED
      WHERE TRANSFER.TransferKey = INSERTED.TransferKey
      AND   INSERTED.TransferKey = DELETED.TransferKey
      AND (( INSERTED.[Status] < '9' OR DELETED.[Status] < '9' ) OR              --(Wan01)
           ( INSERTED.[Status] = 'CANC' OR DELETED.[Status] = 'CANC' ))          --(Wan01)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TRANSFER. (ntrTransferHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   --(Wan01) - START
   IF ( @n_continue = 1 or @n_continue=2 )
   BEGIN
      IF UPDATE(Status)
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM INSERTED
                     WHERE INSERTED.Status = 'CANC'
                   )
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM DELETED WHERE DELETED.Status = '0')
            BEGIN
               SET @n_continue = 3
               SET @n_err=50005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Transfer is in progress/cancelled/finalized. Cancelled reject (ntrTransferHeaderUpdate)'
               GOTO QUIT_TR
            END

            UPDATE TRANSFERDETAIL WITH (ROWLOCK)
            SET Trafficcop = NULL
               ,EditDate   = GETDATE()
               ,EditWho    = SUSER_NAME()
               ,Status     = 'CANC'
            FROM INSERTED
            JOIN DELETED ON (INSERTED.TransferKey = DELETED.TransferKey)
            JOIN TRANSFERDETAIL ON (INSERTED.TransferKey = TRANSFERDETAIL.TransferKey)
            WHERE INSERTED.Status = 'CANC'
            AND   DELETED.Status = '0'
            AND   TRANSFERDETAIL.Status = '0'

            SET @n_err = @@ERROR
            SET @n_cnt = @@ROWCOUNT

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(CHAR(250),@n_err)
               SET @n_err=50006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Update Failed On Table TRANSFERDETAIL. (ntrTransferHeaderUpdate) ( SQLSvr MESSAGE='
                             + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            GOTO QUIT_TR
         END
      END
   END
   --(Wan01) - END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED  WHERE   DELETED.STATUS = '9' ) AND NOT UPDATE(CustomerRefNo)	--CLVN01
                    -- TLTING03
      BEGIN
         SET @n_continue = 3
         SET @n_err=50025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                       + ': Transfer is finalized. Update rejected (ntrTransferHeaderUpdate)'
         GOTO QUIT_TR
      END
   END

   /* #INCLUDE <TRTHU1.SQL> */
   /* modification history
   End of modification history */
   -- 10.8.99 WALLY
   -- set ReasonCode as mandatory field
   -- BEGIN
   DECLARE @c_ReasonCode NVARCHAR(10)

   SELECT @c_ReasonCode = ISNULL(INSERTED.ReasonCode, '')
   FROM  INSERTED, DELETED
   WHERE INSERTED.transferkey = DELETED.transferkey

   IF LEN(@c_ReasonCode) = 0
   BEGIN
      SELECT @n_continue = 3, @n_err = 50000
      SELECT @c_errmsg = 'VALIDATION ERROR: Reason Code Required.'
   END

   -- END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         UPDATE TRANSFER
            SET Status = '0'
           FROM TRANSFER WITH (NOLOCK),
                INSERTED,
                DELETED
          WHERE TRANSFER.TransferKey = INSERTED.TransferKey
            AND INSERTED.TransferKey = DELETED.TransferKey
            AND INSERTED.OpenQty > 0
            AND DELETED.Status = '9'
            AND INSERTED.Status <> 'CANC'    --(Wan01)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Update Failed On Table TRANSFER. (ntrTransferHeaderUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END

      IF @n_continue = 1 or @n_continue=2
      BEGIN
         --(Wan02) - START
         DECLARE @t_TRFZero TABLE (
               Transferkey       NVARCHAR(10)
            ,  AllowTRFZeroQty   NVARCHAR(10)
            ,  OpenStatusCnt     INT
            )

         INSERT INTO @t_TRFZero (Transferkey, AllowTRFZeroQty, OpenStatusCnt)
         SELECT INSERTED.Transferkey
               ,ISNULL(SC.SValue,'0')
               ,ISNULL(SUM(CASE WHEN TD.Status = '9' THEN 0 ELSE 1 END),1)
         FROM INSERTED
         JOIN TRANSFERDETAIL      TD WITH (NOLOCK) ON (INSERTED.TransferKey = TD.transferkey)
         LEFT JOIN STORERCONFIG   SC WITH (NOLOCK) ON (INSERTED.FromStorerkey = SC.Storerkey)
                                                   AND((INSERTED.Facility  = SC.Facility) OR
                                                        ISNULL(RTRIM(SC.Facility),'') = '')
                                                   AND(SC.Configkey = 'AllowTransferZeroQty')
         WHERE INSERTED.OpenQty <= 0
           AND INSERTED.Status <> 'CANC'
         GROUP BY INSERTED.Transferkey
               ,  INSERTED.FromStorerkey
               ,  ISNULL(SC.SValue,'0')
         --(Wan02) - END

         UPDATE TRANSFER
            SET Status = '9'
           FROM TRANSFER WITH (NOLOCK),
                INSERTED,
                DELETED
                ,@t_TRFZero TZ                                       --(Wan02)
          WHERE TRANSFER.TransferKey = INSERTED.TransferKey
            AND INSERTED.TransferKey = DELETED.TransferKey
            AND INSERTED.Transferkey = TZ.Transferkey                --(Wan02)
            AND INSERTED.OpenQty <= 0
            AND INSERTED.Status <> 'CANC'    --(Wan01)
         AND( TZ.AllowTRFZeroQty= '0' OR                             --(Wan02)
             (TZ.AllowTRFZeroQty= '1' AND TZ.OpenStatusCnt = 0) )    --(Wan02)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Update Failed On Table TRANSFER. (ntrTransferHeaderUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END

      IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
      BEGIN
         UPDATE TRANSFER
            SET EditDate = GETDATE(),
                EditWho = SUSER_SNAME(),
                TrafficCop = NULL
           FROM TRANSFER WITH (NOLOCK),
                INSERTED
          WHERE TRANSFER.TransferKey = INSERTED.TransferKey
          AND (TRANSFER.[Status] = '9'              -- tlting01, (Wan01)
          OR   TRANSFER.[Status] = 'CANC')          --(Wan01)
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)
                             + ': Update Failed On Table TRANSFER. (ntrTransferHeaderUpdate) ( SQLSvr MESSAGE='
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

   -- Start IDSHK TBL - Outbound PIX Export
   -- Added by June 11.APR.2003
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM Transfer WITH (NOLOCK), INSERTED
                  WHERE Transfer.Transferkey = INSERTED.Transferkey AND Transfer.STATUS = '9')
      BEGIN
         SELECT @c_storerkey = INSERTED.FromStorerkey FROM INSERTED
         SELECT @c_TBLHKITF = '0'

         EXECUTE nspGetRight null,	-- facility
                  @c_storerkey, 				-- Storerkey
                  null,							-- Sku
                  'TBLHKITF',		   	-- Configkey
                  @b_success output,
                  @c_TBLHKITF output,
                  @n_err output,
                  @c_errmsg output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrPOHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_TBLHKITF = '1'
         BEGIN
            SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

            -- Receipt Transfer
            IF EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.CustomerRefNo IN (SELECT RECEIPTKEY FROM RECEIPT (NOLOCK)))
            BEGIN
               EXEC ispGenTransmitLog2 'TBLTRF', @c_transferkey, '', '', ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50004   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                   + ': Unable To Obtain Transmitlogkey2. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- TBLTRF
/*
            -- Regular Transfer
            IF  EXISTS (SELECT 1 FROM INSERTED WHERE INSERTED.CustomerRefNo NOT IN (SELECT RECEIPTKEY FROM RECEIPT (NOLOCK))
            AND NOT EXISTS (SELECT 1 FROM transmitlog2 WHERE key1 = @c_transferkey AND TABLENAME = 'TBLREGTRF'))
            BEGIN
               -- Alloc to Non-Alloc or Vice versa
               DECLARE @c_FrLotStat NVARCHAR(10), @c_ToLotStat NVARCHAR(10), @c_FrIDStat NVARCHAR(10), @c_ToIDStat NVARCHAR(10)
               DECLARE @c_key NVARCHAR(15), @c_trfline NVARCHAR(5)
               DECLARE @n_FrFlag int, @n_ToFlag int , @n_FrOnhold int, @n_ToOnhold int, @nSKUFlag int
               SELECT @c_key = SPACE(15)

               WHILE (1=1)
               BEGIN
                  SET ROWCOUNT 1

                  SELECT @c_trfline = dbo.fnc_RTrim(TRANSFERDETAIL.TransferLineNumber)
                       , @n_FrFlag = CASE WHEN FrLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1
                                          WHEN FrLoc.Status = "HOLD" THEN 1
                                          WHEN MIN(FrLot.Status) = "HOLD" THEN 1
                                          WHEN MIN(FrID.Status) = "HOLD" THEN 1
                                          WHEN SUM(FrLot.QtyOnhold) > 0 THEN 1 ELSE 0 END
                       , @n_ToFlag = CASE WHEN ToLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1
                                          WHEN ToLoc.Status = "HOLD" THEN 1
                                          WHEN MIN(ToLot.Status) = "HOLD" THEN 1
                                          WHEN MIN(ToID.Status) = "HOLD" THEN 1
                                          WHEN SUM(ToLot.QtyOnhold) > 0 THEN 1 ELSE 0 END
                       , @nSKUFlag = CASE WHEN FromSKU <> ToSKU THEN 1 ElSE 0 END
                  FROM TRANSFER, TRANSFERDETAIL (NOLOCK), LOC FrLoc (NOLOCK), LOC ToLoc (NOLOCK)
                  , LOTATTRIBUTE ToAtt (NOLOCK)
                  , LOT FrLot (NOLOCK), LOT ToLot (NOLOCK)
                  , ID FrID (NOLOCK), ID ToID (NOLOCK)
                  WHERE TRANSFER.Transferkey = TRANSFERDETAIL.Transferkey
                  AND  TRANSFERDETAIL.FromLoc = FrLoc.Loc
                  AND  TRANSFERDETAIL.ToLoc = ToLoc.Loc
                  AND  TRANSFERDETAIL.FromLot = FrLot.Lot
                  AND  TRANSFERDETAIL.ToStorerkey = ToAtt.Storerkey
                  AND  TRANSFERDETAIL.ToSku = ToAtt.Sku
                  AND  TRANSFERDETAIL.ToLottable01 = ToAtt.Lottable01
                  AND  TRANSFERDETAIL.ToLottable02 = ToAtt.Lottable02
                  AND  TRANSFERDETAIL.ToLottable03 = ToAtt.Lottable03
                  --AND  TRANSFERDETAIL.ToLottable04 = ToAtt.Lottable04
                  AND  convert(datetime, TRANSFERDETAIL.ToLottable05, 106) = convert(datetime, ToAtt.Lottable05, 106)
                  AND  ToAtt.Lot = ToLot.Lot
                  AND  TRANSFERDETAIL.FromID *= FrID.ID
                  AND  TRANSFERDETAIL.ToID *= TOID.ID
                  AND  TRANSFER.CustomerRefNo NOT IN (SELECT RECEIPTKEY FROM RECEIPT (NOLOCK))
                  AND  TRANSFER.Transferkey = @c_transferkey
                  AND  TRANSFER.Transferkey + dbo.fnc_RTrim(TRANSFERDETAIL.TransferLineNumber) > @c_key
                  GROUP BY FrLoc.Locationflag, ToLoc.Locationflag, FrLoc.Status, ToLoc.Status,
                           TRANSFERDETAIL.TransferLineNumber, FromSKU, TOSku

                  If @@ROWCOUNT = 0
                  Begin
                     SET ROWCOUNT 0
                  BREAK
                  End

                  SELECT @c_key = @c_transferkey + @c_trfline

                  IF (@nSKUFlag = 1) OR (@n_FrFlag <> @n_ToFlag )
                  BEGIN
                     SELECT @b_success = 1
                     EXECUTE nspg_getkey
                           'transmitlogkey2'		-- Modified by YokeBeen on 26-Apr-2003
                           , 10
                           , @c_trmlogkey output
                           , @b_success output
                           , @n_err output
                           , @c_errmsg output

                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = convert(char(250),@n_err), @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.
                        SELECT @c_errmsg = "nsql" + convert(char(5),@n_err) + ": Unable To Obtain Transmitlogkey. (ntrReceiptHeaderUpdate)" + " ( " + " sqlsvr message=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                     ELSE
                     BEGIN
                        INSERT transmitlog2 (transmitlogkey, tablename, key1, key2, transmitflag)
                        VALUES (@c_trmlogkey, 'TBLREGTRF', @c_transferkey, @c_trfline, '0')
                     END
                  END -- Alloc to Non-Alloc or Vice versa
               END -- While
               SET ROWCOUNT 0
            END -- TBLREGTRF
*/
         END -- TBLHKITF
      END -- Status = '9'
   END
   -- End IDSHK TBL - Outbound PIX Export

-- Added By YokeBeen on 17-Oct-2003 For NIKE Regional (NSC) Project - (SOS#15352)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         SELECT @c_NIKEREGITF = '0'
         SELECT @c_storerkey = INSERTED.FromStorerkey,
                @c_ReasonCode = INSERTED.ReasonCode
           FROM INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'NIKEREGITF',		-- Configkey
                  @b_success		OUTPUT,
                  @c_NIKEREGITF		OUTPUT,
                  @n_err			OUTPUT,
                  @c_errmsg		OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_NIKEREGITF = '1'
         BEGIN
            -- Added By SHONG on 12-Jul-2004
            -- Only certain Reason Code require for interface
            IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'TRNReason' AND
                                                                 Code = @c_ReasonCode AND Short = 'NSC')
            BEGIN
               SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

               -- Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
               -- Changed to trigger records into NSCLog table with 'NSCKEY'.
               EXEC ispGenNSCLog 'NIKEREGTRF', @c_transferkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50005   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                   + ': Unable To Obtain NSClogkey. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               -- End Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
            END -- ReasonCode require for interface
         END -- @c_NIKEREGITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
-- Ended by YokeBeen on 17-Oct-2003 - (SOS#15352)

   -- Added by MaryVong on 29Sept04 (SOS25798-C4) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         SELECT @c_C4ITF = '0'
         SELECT @c_storerkey = INSERTED.FromStorerkey,
                @c_ReasonCode = INSERTED.ReasonCode
           FROM INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'C4ITF',		      -- Configkey
                  @b_success			OUTPUT,
                  @c_C4ITF		   OUTPUT,
                  @n_err				OUTPUT,
                  @c_errmsg			OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_C4ITF = '1'
         BEGIN
            IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'TRNReason' AND
                                                                 Code = @c_ReasonCode AND Long = 'C4TH') -- SOS114421
                                                                 -- Code = @c_ReasonCode AND Long = 'C4LGTH') -- SOS114421
            BEGIN
               SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

               EXEC ispGenTransmitLog2 'C4TRF', @c_transferkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50006   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                   + ': Unable To Obtain TransmitLogkey2. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- @c_C4ITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added by MaryVong on 29Sept04 (SOS25798-C4) - End

   -- Added by dhung on 2005-04-14 (TXFLOG interface) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
 IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         DECLARE @c_TXFLOG NVARCHAR( 1)
         SELECT @c_TXFLOG = '0'
         SELECT @c_storerkey = INSERTED.FromStorerkey,
                @c_ReasonCode = INSERTED.ReasonCode
           FROM INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'TXFLOG',		      -- Configkey
                  @b_success			OUTPUT,
                  @c_TXFLOG		   OUTPUT,
                  @n_err				OUTPUT,
                  @c_errmsg			OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_TXFLOG = '1'
         BEGIN
            SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

            EXEC ispGenTransmitLog3 'TXFLOG', @c_transferkey, '', @c_storerkey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50007   -- should be set to the sql errmessage but i don't know how to do so.
               SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                + ': Unable To Obtain TransmitLogkey2. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- @c_TXFLOG = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added by dhung on 2005-04-14 (TXFLOG interface) - End

   -- Added by Vicky on 08-July-2005  - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         SELECT @c_TRFLOG = '0'
         SELECT @c_storerkey = INSERTED.ToStorerkey,
                @c_ReasonCode = INSERTED.ReasonCode
         FROM INSERTED

         EXECUTE nspGetRight                                
                @c_Facility   = NULL,                     
                @c_StorerKey  = @c_StorerKey,                    
                @c_sku        = NULL,                          
                @c_ConfigKey  = 'TRFLOG', -- Configkey         
                @b_Success    = @b_success     OUTPUT,             
                @c_authority  = @c_TRFLOG      OUTPUT,             
                @n_err        = @n_err         OUTPUT,             
                @c_errmsg     = @c_errmsg      OUTPUT,             
                @c_Option5    = @c_TRFLOG_opt5 OUTPUT   --NJOW01             
   
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_TRFLOG = '1'
         BEGIN
            SELECT @c_transferkey = Transferkey, 
                   @c_TransferType = INSERTED.Type,  --NJOW01
                   @c_CustomerRefNo = INSERTED.CustomerRefNo  --NJOW01
            FROM INSERTED (NOLOCK)
            
            --NJOW01 S
            SELECT @c_PickRequest_TrfType = dbo.fnc_GetParamValueFromString('@c_PickRequest_TrfType', @c_TRFLOG_opt5, @c_PickRequest_TrfType)

            IF ISNULL(@c_PickRequest_TrfType,'') = @c_TransferType
            BEGIN
               EXEC ispGenTransmitLog3 'TRFLOG', @c_transferkey, @c_ReasonCode, @c_storerkey, @c_CustomerRefNo
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
               
               IF @b_success = 1
               BEGIN
                  UPDATE TRANSMITLOG3 WITH (ROWLOCK)
                  SET transmitflag = 'H'
                  WHERE Tablename = 'TRFLOG'
                  AND Key1 = @c_Transferkey
                  AND Key2 = @c_ReasonCode
                  AND Key3 = @c_Storerkey
               END                  
            END  --NJOW01 E
            ELSE
            BEGIN           
               EXEC ispGenTransmitLog3 'TRFLOG', @c_transferkey, @c_ReasonCode, @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
            END

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50008   -- should be set to the sql errmessage but i don't know how to do so.
               SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                + ': Unable To Obtain TransmitLogkey3. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- TRFLOG = '1'

         -- (YokeBeen01) - Start
         SELECT @b_success = 0
              , @c_authority_wtntrfitf = '0'

         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_storerkey,         -- Storer
                  '',         -- Sku
                  'WTNTRFLOG',          -- ConfigKey
                  @b_success               OUTPUT,
                  @c_authority_wtntrfitf   OUTPUT,
                  @n_err                   OUTPUT,
                  @c_errmsg                OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50009
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Retrieve of Right (WTNTRFLOG) Failed (ntrTransferHeaderUpdate) ( SQLSvr MESSAGE='
                             + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
         ELSE
         BEGIN
            IF @c_authority_wtntrfitf = '1'
            BEGIN
               SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

               EXEC dbo.ispGenWitronLog 'WTNTRFLOG', @c_transferkey, @c_ReasonCode, @c_storerkey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_wtntrfitf = '1'
         END -- IF @b_success = 1
         -- (YokeBeen01) - End
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added by Vicky End

   --MC01 - S
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      IF  EXISTS ( SELECT 1 FROM INSERTED, DELETED
                   Where INSERTED.TransferKey = DELETED.TransferKey
                   And INSERTED.CustomerRefNo <> DELETED.CustomerRefNo
                   AND INSERTED.CustomerRefNo <> ''
                   AND DELETED.CustomerRefNo = '' )
      BEGIN
         SELECT @c_MSFTRFITF = '0'
         SELECT @c_storerkey = INSERTED.FromStorerkey,
                @c_trantype = INSERTED.Type
         FROM   INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'MSFTRFITF',		-- Configkey
                  @b_success			OUTPUT,
                  @c_MSFTRFITF      OUTPUT,
                  @n_err				OUTPUT,
                  @c_errmsg			OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_MSFTRFITF = '1'
         BEGIN
            IF (SELECT Short FROM CODELKUP WITH (NOLOCK) WHERE ListName ='TranType'
                   AND Code = @c_trantype) = 'MSFITF'
            BEGIN
               SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

               EXEC ispGenTransmitLog3 'MSFTRFITF', @c_transferkey, '', @c_storerkey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50010   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                   + ': Unable To Obtain TransmitLogkey3. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- If Exists
         END --IF @c_MSFTRFITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   --MC01 - E

   -- Added by YTWAN on 24-Feb-2005 (SOS32152) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         SELECT @c_CibaITF = '0'
         SELECT @c_storerkey = INSERTED.FromStorerkey,
                @c_trantype = INSERTED.Type -- Added by Vicky on 08-June-2006 (SOS#51627)
           FROM INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'CIBAITF',		      -- Configkey
                  @b_success			OUTPUT,
                  @c_CibaITF		   OUTPUT,
                  @n_err				OUTPUT,
                  @c_errmsg			OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_CibaITF = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'TRANTYPE' AND CODE = dbo.fnc_RTrim(@c_trantype)
                          AND Long = 'CV') -- Added by Vicky on 08-June-2006 (SOS#51627)
            BEGIN
               SELECT @c_transferkey = Transferkey FROM INSERTED (NOLOCK)

               EXEC ispGenTransmitLog2 'CIBATRF', @c_transferkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50010   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                   + ': Unable To Obtain TransmitLogkey2. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- If Exists
         END -- @c_CIBAITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added by YTWAN on 24-Feb-2005 (SOS32152) - End

   -- Added by June on 22-Feb-2007 (SOS68834) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM TRANSFER WITH (NOLOCK), INSERTED
                  WHERE TRANSFER.Transferkey = INSERTED.Transferkey AND TRANSFER.STATUS = '9')
      BEGIN
         SELECT @c_INVTRFITF = '0'
         SELECT @c_storerkey  = INSERTED.FromStorerkey,
                @c_trantype   = INSERTED.Type,
                @c_ReasonCode = INSERTED.ReasonCode
           FROM INSERTED

         EXECUTE nspGetRight
                  NULL,					-- facility
                  @c_storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'INVTRFITF',		-- Configkey
                  @b_success			OUTPUT,
                  @c_INVTRFITF		OUTPUT,
                  @n_err				OUTPUT,
                  @c_errmsg			OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrTransferHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_INVTRFITF = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
                        WHERE Listname = 'TRNReason' AND CODE = dbo.fnc_RTrim(@c_ReasonCode) AND Upper(Short) = 'TRIGGERITF')
            BEGIN
               IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'TRFCOPYL3' AND CODE = dbo.fnc_RTrim(@c_trantype))
               BEGIN
                  SELECT @c_transferkey = Transferkey
                  FROM   INSERTED (NOLOCK)

                  EXEC ispGenTransmitLog3 'INVTRFITF', @c_transferkey, '', @c_storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=50011   -- should be set to the sql errmessage but i don't know how to do so.
                     SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err)
                                      + ': Unable To Obtain TransmitLogkey3. (ntrTransferHeaderUpdate) ( sqlsvr message='
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- If Exists  - TRFCOPYL3
            END -- If Exists  - TRNReason
         END -- @c_INVTRFITF = '1'
      END -- Status = '9'
   END -- IF @n_continue = 1
   -- Added by June on 22-Feb-2007 (SOS68834) - End


/* IDSV5 - Leo */
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED, DELETED
                  WHERE INSERTED.Transferkey = DELETED.Transferkey
                    AND INSERTED.STATUS = '9'
                    AND DELETED.STATUS <> '9')
      BEGIN
         SELECT @c_transferkey = ''
         DECLARE @c_primarykey NVARCHAR(10)

         WHILE 1 = 1
         BEGIN
            SET ROWCOUNT 1
            SELECT @c_transferkey = INSERTED.TransferKey
              FROM INSERTED, DELETED
             WHERE INSERTED.TransferKey = DELETED.TransferKey
               AND INSERTED.Status = '9'
               AND DELETED.Status <> '9'
               AND INSERTED.TransferKey > @c_transferkey

            If @@ROWCOUNT = 0
            BEGIN
               SET ROWCOUNT 0
               BREAK
            END

            SET ROWCOUNT 0
            EXECUTE nspGetRight null,         -- Facility
                     null,         -- Storer
                     null,         -- Sku
                     'TRANSFERHDR INTERFACE - ALL',      -- ConfigKey
                     @b_success    output,
                     @c_authority  output,
                     @n_err        output,
                     @c_errmsg     output

            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = 'ntrTransferHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
               BREAK
            END
            ELSE
            BEGIN
               IF @c_authority = '1'
               BEGIN
                  EXECUTE nsp_TransferHeaderInterface_ALL
                           @c_transferkey,
                           @b_success output,
                           @n_err     output,
                           @c_errmsg  output

                  IF @b_success <> 1
                  BEGIN
                     SELECT @c_errmsg = 'ntrTransferHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
                     BREAK
                  END
               END -- interface turn on
            END -- Getright OK
         END
      END
   END


/********************************************************/
/* Interface Trigger Points Calling Process - (Start)   */
/********************************************************/
   -- (YokeBeen02) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
--			SELECT INSERTED.[Status], * FROM INSERTED
--			SELECT DELETED.[Status], * FROM DELETED
--			SELECT TRANSFER.[Status], TRANSFER.* FROM TRANSFER WITH(NOLOCK) JOIN INSERTED ON TRANSFER.Transferkey = INSERTED.Transferkey

      IF EXISTS (SELECT 1 FROM INSERTED
                   JOIN TRANSFER WITH (NOLOCK) ON (INSERTED.Transferkey = TRANSFER.Transferkey)
                  WHERE INSERTED.STATUS <> '9'
                    AND TRANSFER.STATUS = '9')
      BEGIN
         DECLARE Cur_Transfer_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         -- Extract values for required variables
          SELECT INSERTED.FromStorerkey
               , INSERTED.ToStorerkey
               , INSERTED.Transferkey
               , INSERTED.Type
               , INSERTED.ReasonCode
               , INSERTED.Status
            FROM INSERTED
            JOIN TRANSFER WITH (NOLOCK) ON (INSERTED.Transferkey = TRANSFER.Transferkey)
           WHERE INSERTED.Status <> '9'
             AND TRANSFER.Status = '9'

         OPEN Cur_Transfer_TriggerPoints
         FETCH NEXT FROM Cur_Transfer_TriggerPoints INTO @c_FromStorerKey, @c_ToStorerKey, @c_TransferKey
                                                       , @c_TranType, @c_ReasonCode, @c_Status

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Execute SP - isp_ITF_ntrTransfer
            EXECUTE dbo.isp_ITF_ntrTransfer
                     @c_TriggerName
                   , @c_SourceTable
                   , @c_FromStorerKey
                   , @c_ToStorerKey
                   , @c_TransferKey
                   , @b_Success  OUTPUT
                   , @n_err      OUTPUT
                   , @c_errmsg   OUTPUT

            FETCH NEXT FROM Cur_Transfer_TriggerPoints INTO @c_FromStorerKey, @c_ToStorerKey, @c_TransferKey
                                                          , @c_TranType, @c_ReasonCode, @c_Status
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE Cur_Transfer_TriggerPoints
         DEALLOCATE Cur_Transfer_TriggerPoints
      END -- IF EXISTS (SELECT 1 FROM INSERTED, DELETED)
   END -- IF @n_continue = 1 OR @n_continue = 2
   -- (YokeBeen02) - End
/********************************************************/
/* Interface Trigger Points Calling Process - (End)     */
/********************************************************/

   QUIT_TR:                      ---(wan01)
   /* #INCLUDE <TRTHU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrTransferHeaderUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End PROC



GO