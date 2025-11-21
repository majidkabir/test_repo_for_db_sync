SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: nspItrnAddWithdrawalCheck                            */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by:                                                            */
/*                                                                        */
/* Purpose:                                                               */
/*                                                                        */
/* Called By:                                                             */
/*                                                                        */
/* PVCS Version: 1.8                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author        Purposes                                    */
/* 06/11/2002   Leo Ng        Program rewrite for IDS version 5           */
/* 07-Sep-2006  MaryVong      Add in RDT compatible error messages        */
/* 25-Jun-2013  TLTING01      Deadlock Tuning - reduce update to ID       */
/* 25-Apr-2014  CSCHONG       Add Lottable06-15 (CS01)                    */
/* 06-Feb-2018  SWT02     1.2 Added Channel Management Logic              */
/*                        1.2.1 Handle QtyOnHold For Channel Mgmt         */
/* 23-JUL-2019  Wan01     1.3 WMS - 9914 [MY] JDSPORTSMY - Channel        */
/*                            Inventory Ignore QtyOnHold - CR             */
/* 26-SEP-2019  Wan02     1.7 WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for   */
/*                            Channel                                     */
/* 26-Sep-2019  Leong     1.7 INC0871401 - Revise error message.          */
/* 10-Jun-2020  Wan03     1.8 WMS-13117 - [CN] Sephora_WMS_ITRN_Add_UCC_CR*/
/* 04-Jan-2021  Leong     1.9 INC1362763 - Revise error message.          */
/* 09-Aug-2022  NJOW01    2.0 Fix channel date format compatible with     */
/*                            format in isp_ChannelGetID                  */
/* 09-Aug-20200 NJOW01    2.0 DEVOPS Combine Script                       */
/* 12-Aug-2024  Wan04     2.1 LFWM-4446 - RG[GIT] Serial Number Solution  */
/*                            - Transfer by Serial Number                 */
/**************************************************************************/

CREATE   PROC  [dbo].[nspItrnAddWithdrawalCheck]
                @c_itrnkey      NVARCHAR(10)
 ,              @c_StorerKey    NVARCHAR(15)
 ,              @c_SKU          NVARCHAR(20)
 ,              @c_LOT          NVARCHAR(10)
 ,              @c_ToLoc        NVARCHAR(10)
 ,              @c_ToID         NVARCHAR(18)
 ,              @c_packkey      NVARCHAR(10)
 ,              @c_Status       NVARCHAR(10)
 ,              @n_CaseCnt      int
 ,              @n_InnerPack    int
 ,              @n_Qty          int
 ,              @n_Pallet       int
 ,              @f_cube         float
 ,              @f_GrossWgt     float
 ,              @f_NetWgt       float
 ,              @f_otherunit1   float
 ,              @f_otherunit2   float
 ,              @c_Lottable01   NVARCHAR(18) = ''
 ,              @c_Lottable02   NVARCHAR(18) = ''
 ,              @c_Lottable03   NVARCHAR(18) = ''
 ,              @d_Lottable04   datetime = NULL
 ,              @d_Lottable05   datetime = NULL
 ,              @c_Lottable06   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable07   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable08   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable09   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable10   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable11   NVARCHAR(30) = ''     --(CS01)
 ,              @c_Lottable12   NVARCHAR(30) = ''     --(CS01)
 ,              @d_Lottable13   datetime = NULL       --(CS01)
 ,              @d_Lottable14   datetime = NULL       --(CS01)
 ,              @d_Lottable15   datetime = NULL       --(CS01)
 ,              @c_sourcekey    NVARCHAR(20)
 ,              @c_sourcetype   NVARCHAR(30)
 ,              @b_Success      int        OUTPUT
 ,              @n_Err          int        OUTPUT
 ,              @c_ErrMsg       NVARCHAR(250)  OUTPUT
 ,              @c_Channel      NVARCHAR(20) = '' --(SWT02)
 ,              @n_Channel_ID   BIGINT = 0 OUTPUT --(SWT02)
 AS
 SET NOCOUNT ON
 SET ANSI_NULLS OFF
 SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_debug int
 SELECT @b_debug = 0
 DECLARE   @c_SKUdefallowed NVARCHAR(18)
 ,      @n_continue int
 ,      @n_Err2 int
 ,      @c_preprocess NVARCHAR(250)
 ,      @c_pstprocess NVARCHAR(250)
 ,      @n_cnt int

 IF @n_continue=1 or @n_continue=2
 BEGIN
     IF @d_Lottable04 = ''
     BEGIN
         SELECT @d_Lottable04 = NULL
     END
     IF @d_Lottable05 = ''
     BEGIN
         SELECT @d_Lottable05 = NULL
     END
 END
 SELECT @n_continue=1, @b_success=0, @n_Err = 1,@c_ErrMsg=''

 DECLARE @c_allowidqtyupdate NVARCHAR(1)
       , @c_ChannelInventoryMgmt  NVARCHAR(10) = '0' -- (SWT02)

      /* #INCLUDE <SPIAWC1.SQL> */
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
     SELECT @c_allowidqtyupdate = IsNull (NSQLValue, '0')
     FROM NSQLCONFIG (NOLOCK)
     WHERE CONFIGKEY = 'ALLOWIDQTYUPDATE'
 END

  -- (SWT02)
 DECLARE @c_Facility NVARCHAR(10)

 SELECT @c_Facility = Facility
 FROM LOC WITH (NOLOCK)
 WHERE LOC = @c_ToLoc

 SET @c_ChannelInventoryMgmt = '0'
 If @n_continue = 1 or @n_continue = 2
 Begin
    Select @b_success = 0
    Execute nspGetRight2 @c_Facility,
    @c_StorerKey,          -- Storer
    @c_SKU,                   -- Sku
    'ChannelInventoryMgmt',  -- ConfigKey
    @b_success    output,
    @c_ChannelInventoryMgmt  output,
    @n_Err        output,
    @c_ErrMsg     output
    If @b_success <> 1
    Begin
       Select @n_continue = 3, @n_Err = 61961, @c_ErrMsg = 'nspItrnAddWithdrawalCheck:' + ISNULL(RTRIM(@c_ErrMsg),'')
    End
 END

 IF @n_continue =1 or @n_continue=2
 BEGIN
     IF @n_continue=1 or @n_continue=2
     BEGIN
         IF (@c_StorerKey = '') OR (@c_StorerKey IS NULL)
         BEGIN
             SELECT @c_StorerKey=( SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
             FROM NSQLCONFIG (NOLOCK)
             WHERE NSQLCONFIG.ConfigKey = 'gc_storerdef')
             IF @c_StorerKey IS NULL
             BEGIN
                 SELECT @n_continue = 3 , @n_Err = 61911 --61300
                 SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Storerkey is blank or null - not allowed! (nspItrnAddWithdrawalCheck)'
             END
             ELSE BEGIN
                 UPDATE Itrn SET StorerKey = @c_StorerKey WHERE Itrn.ItrnKey = @c_ItrnKey
                 SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
                 IF @n_Err <> 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_Err = 61912 --61301
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Insert Trigger On ITRN Failed Because An Attempt To Update StorerKey Failed. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
                 END
                 ELSE IF @n_cnt = 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_Err = 61913 --61323
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
                 END
             END
        END
     END
     IF @n_continue=1 or @n_continue=2
     BEGIN
     IF   (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_SKU)) IS NULL)
     BEGIN
         SELECT @c_SKUDefAllowed =( SELECT dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
         FROM NSQLCONFIG (NOLOCK)
         WHERE ConfigKey = 'gb_skudefallowed' )
         IF @c_SKUDefAllowed = 'TRUE'
         BEGIN
             SELECT @c_SKU=(SELECT NSQLVALUE FROM NSQLCONFIG (NOLOCK) WHERE NSQLCONFIG.Configkey='gc_skudef')
             IF @c_SKU IS NULL
             BEGIN
                 SELECT @n_continue = 3 , @n_Err = 61914 --61302
                 SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Storerkey is blank or null - not allowed! (nspItrnAddWithdrawalCheck)'
             END
             ELSE BEGIN
                 UPDATE ITrn SET sku = @c_SKU WHERE itrnkey = @c_itrnkey
                 SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
                 IF @n_Err <> 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_Err = 61915 --61303
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Insert Trigger On ITRN Failed Because An Attempt To Update SKU Failed. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
                 END
                 ELSE IF @n_cnt = 0
                 BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_Err = 61916 --61324
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table ITRN Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
                 END
             END
         END
         ELSE BEGIN
             SELECT @n_continue = 3 , @n_Err = 61917 --61304
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Default SKU Is Not Allowed And SKU Passed Is Blank! (nspItrnAddWithdrawalCheck)'
         END
     END
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
     IF ISNULL(RTRIM(@c_LOT),'') = ''
     BEGIN
         DECLARE @b_isok int
         SELECT @b_isok=0
         EXECUTE nsp_LOTLookUp @c_StorerKey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
             @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, @c_Lottable10, @c_Lottable11, @c_Lottable12,
             @d_Lottable13, @d_Lottable14, @d_Lottable15, --(CS01)
             @c_LOT OUTPUT, @b_isOK OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
         IF @b_isok = 1
         BEGIN
             IF ISNULL(RTRIM(@c_LOT),'') = ''
             BEGIN
                 SELECT @n_continue = 3 , @n_Err = 61918 --61305
                 SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Lot Number Does Not Exist In The LOTATTRIBUTE Table! (nspItrnAddWithdrawalCheck)'
             END
         END
         ELSE BEGIN
             SELECT @n_continue=3
         END
     END
     ELSE BEGIN
         DECLARE @c_verifysku NVARCHAR(20)
         SELECT @c_verifysku=SKU FROM LOTATTRIBUTE (NOLOCK) WHERE LOT=@c_lot
         IF @@rowcount <> 1
         BEGIN
             SELECT @n_continue = 3 , @n_Err = 61919 --61306
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Lot Number Is Not Unique Or Does Not Exist In The LOTATTRIBUTE Table! (nspItrnAddWithdrawalCheck)'
         END
         ELSE BEGIN
             IF @c_SKU <> @c_verifysku
             BEGIN
                 SELECT @n_continue = 3 , @n_Err = 61920 --61307
                 SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)
                                  + ': Lot Number: ' + ISNULL(RTRIM(@c_lot),'')
                                  + ', Sku In LotAttribute: ' + ISNULL(RTRIM(@c_verifysku),'')
                                  + ', Sku Passed In: ' + ISNULL(RTRIM(@c_SKU),'')
                                  + ' - Do Not Matched with LOTATTRIBUTE.(nspItrnAddWithdrawalCheck)' -- INC0871401
             END
         END
     END
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
     DECLARE @n_rcnt int,@n_curCaseCnt int, @n_curInnerPack int , @n_curqty int, @c_curstatus NVARCHAR(10), @n_curPallet int,
             @f_curcube float, @f_curGrossWgt float, @f_curNetWgt float, @f_curotherunit1 float, @f_curotherunit2 float
     SELECT @n_curCaseCnt=CaseCnt,  @n_curInnerPack=InnerPack,  @n_curqty=Qty,  @n_curPallet=Pallet,  @f_curcube=cube,
            @f_curGrossWgt=GrossWgt,  @f_curNetWgt=NetWgt,  @f_curotherunit1=otherunit1,  @f_curotherunit2=otherunit2
     FROM LOT (NOLOCK) WHERE LOT = @c_lot
     SELECT @n_rcnt=@@ROWCOUNT
     IF @n_rcnt=1
     BEGIN
         UPDATE LOT
         SET   CaseCnt=CaseCnt+@n_CaseCnt, InnerPack=InnerPack+@n_InnerPack, QTY = QTY+@n_qty, Pallet=Pallet+@n_Pallet,
               CUBE=CUBE+@f_cube, GrossWgt=(CASE WHEN (GrossWgt+@f_GrossWgt) > 0 THEN (GrossWgt+@f_GrossWgt) ELSE 0 END ),
               NetWgt=(CASE WHEN (NetWgt+@f_NetWgt) > 0 THEN (NetWgt+@f_NetWgt) ELSE 0 END ),
               OTHERUNIT1=OTHERUNIT1+@f_otherunit1, OTHERUNIT2=OTHERUNIT2+@f_otherunit2
         WHERE LOT=@c_LOT
         SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61921 --61308
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table LOT. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
         ELSE IF @n_cnt = 0
         BEGIN
             SELECT @n_continue = 3, @n_Err = 61922 --61325
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table LOT Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
         END
     END
     ELSE BEGIN
         SELECT @n_continue = 3, @n_Err = 61923 --61309
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Lot Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddWithdrawalCheck)'
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Lot Table ' + ISNULL(RTRIM(@c_lot),'') + ' Did Not Return Expected Unique Row In Response To Query. (nspItrnAddWithdrawalCheck)'  --INC1362763
     END
 END

 IF @n_continue=1 or @n_continue=2
 BEGIN
     SELECT @n_rcnt=NULL, @n_curqty=NULL, @c_curstatus=NULL

     SELECT @n_curqty=Qty, @c_curstatus=Status
     FROM ID (NOLOCK)
     WHERE ID = @c_toid

     SELECT @n_rcnt=@@ROWCOUNT
     IF @n_rcnt=1
     BEGIN
         IF ISNULL(RTRIM(@c_Status),'') = ''
         BEGIN
             SELECT @c_Status = @c_curstatus
         END
         IF @c_allowidqtyupdate = '1'
         BEGIN
            IF ISNULL(RTRIM(@c_toid),'') <> ''
            BEGIN
               UPDATE ID with (ROWLOCK) SET QTY = QTY+@n_qty, Status = @c_Status WHERE ID=@c_toid
            END
            ELSE
            BEGIN
               SELECT @n_cnt = 1
            END
         END
         ELSE
         BEGIN
            --tlting01
            SET @n_cnt = 0
            SELECT @n_cnt = COUNT(1) FROM  ID with (NOLOCK) WHERE ID = @c_toid

            IF EXISTS ( SELECT 1 FROM  ID with (NOLOCK) WHERE ID = @c_toid AND [Status] <> @c_Status )
            BEGIN
               UPDATE ID with (ROWLOCK) SET Status = @c_Status WHERE ID=@c_toid
            END
         END
         SELECT @n_Err = @@ERROR--, @n_cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61924 --61312
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table ID. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
         --ELSE IF @n_cnt = 0
         IF @n_cnt = 0 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61925 --61327
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table ID Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
         END
     END
     ELSE BEGIN
         SELECT @n_continue = 3 , @n_Err = 61926 --61313
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': ID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddWithdrawalCheck)'
     END
     IF (@n_rcnt = 1 or @n_rcnt = 0) and (@n_continue =1 or @n_continue=2)
     BEGIN
         IF dbo.fnc_RTrim(@c_toid) IS NOT NULL
         BEGIN
             DECLARE @n_ti int, @n_hi int, @n_totalqty int, @c_currentpackkey NVARCHAR(10)
             SELECT @n_ti = 0, @n_hi = 0, @n_totalqty = 0
             SELECT @n_totalqty = QTY,@c_currentpackkey = PACKKEY FROM ID (NOLOCK) WHERE ID = @c_toid
             IF ISNULL(RTRIM(@c_currentpackkey),'') <> ''
             BEGIN
                 SELECT @n_hi = Ceiling(@n_totalqty / CaseCnt / PalletTI), @n_ti = PalletTI
                 FROM PACK (NOLOCK)
                 WHERE PACKKEY = @c_currentpackkey AND PalletTI > 0 AND CaseCnt > 0
                 IF @n_ti > 0 or @n_hi > 0
                 BEGIN
                     UPDATE ID with (ROWLOCK) SET PutawayTI = @n_ti, PutawayHI = @n_hi WHERE ID = @c_toid
                     SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_Err <> 0
                     BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_Err = 61927 --61339
                         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table ID Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
                     END
                 END
             END
         END
     END
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
     SELECT @n_rcnt=NULL, @n_curqty=NULL
     SELECT  @n_curqty=Qty FROM SKUxLOC (NOLOCK) WHERE STORERKEY = @c_StorerKey and SKU = @c_SKU and LOC = @c_toloc
     SELECT @n_rcnt=@@ROWCOUNT
     IF @n_rcnt=1
     BEGIN
         UPDATE SKUxLOC SET QTY = QTY+@n_qty WHERE STORERKEY = @c_StorerKey and SKU = @c_SKU and LOC=@c_toloc
         SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61928 --61333
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table SKUxLOC. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
         ELSE IF @n_cnt = 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61929 --61334
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table SKUxLOC Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
         END
     END
     ELSE BEGIN
         SELECT @n_continue = 3 , @n_Err = 61930 --61335
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': SKUxLOC Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddWithdrawalCheck)'
     END
 END
 IF @n_continue=1 or @n_continue=2
 BEGIN
     SELECT @n_rcnt=NULL, @n_curqty=NULL
     SELECT  @n_curqty=Qty FROM LOTxLOCxID (NOLOCK) WHERE LOT=@c_LOT and LOC=@c_toloc and ID=@c_toid
     SELECT @n_rcnt=@@ROWCOUNT
     IF @n_rcnt=1
     BEGIN
         UPDATE LOTxLOCxID SET QTY=QTY+@n_qty WHERE LOT=@c_LOT and LOC=@c_toloc and ID=@c_toid
         SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_Err <> 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61931 --61320
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table LOTxLOCxID. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
         END
         ELSE IF @n_cnt = 0
         BEGIN
             SELECT @n_continue = 3
             SELECT @n_Err = 61932 --61331
             SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update To Table LOTxLOCxID Returned Zero Rows Affected. (nspItrnAddWithdrawalCheck)'
         END
     END
     ELSE BEGIN
         SELECT @n_continue = 3 , @n_Err = 61933 --61321
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': LOTxLOCxID Table Did Not Return Expected Unique Row In Response To Query. (nspItrnAddDepositCheck)'
     END
 END
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
     IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_toid and STATUS <> 'OK')
     OR EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_toloc and (STATUS <> 'OK' OR LOCATIONFLAG = 'HOLD' or LOCATIONFLAG = 'DAMAGE'))
     BEGIN
         -- 12.16.99 BY WALLY
         -- to avoid negative qtyonhold
         IF (SELECT qtyonhold FROM LOT (NOLOCK) WHERE LOT = @c_lot) < ABS(@n_qty )
             UPDATE LOT SET QTYONHOLD = 0 WHERE LOT = @c_lot
         ELSE
             UPDATE LOT SET QTYONHOLD = QTYONHOLD + @n_qty WHERE LOT = @c_lot
             SELECT @n_Err = @@ERROR, @n_cnt = @@ROWCOUNT
             IF @n_Err <> 0
             BEGIN
                 SELECT @n_continue = 3
                 SELECT @n_Err = 61934 --61337
                 SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table LOT. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
             END
     END
 END
    -- (SWT02) Channel Management
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @c_ChannelInventoryMgmt = '1'
      BEGIN
         IF ISNULL(RTRIM(@c_Channel), '') <> ''  AND
            ISNULL(@n_Channel_ID,0) = 0
         BEGIN
            SET @n_Channel_ID = 0

            BEGIN TRY
               EXEC isp_ChannelGetID
                   @c_StorerKey   = @c_StorerKey
                  ,@c_Sku         = @c_SKU
                  ,@c_Facility    = @c_Facility
                  ,@c_Channel     = @c_Channel
                  ,@c_LOT         = @c_LOT
                  ,@n_Channel_ID  = @n_Channel_ID OUTPUT
                  ,@b_Success     = @b_Success OUTPUT
                  ,@n_ErrNo       = @n_Err     OUTPUT
                  ,@c_ErrMsg      = @c_ErrMsg  OUTPUT
            END TRY
            BEGIN CATCH
                  SELECT @n_err = ERROR_NUMBER(),
                         @c_ErrMsg = ERROR_MESSAGE()

                  SELECT @n_continue = 3
                  SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (nspItrnAddWithdrawalCheck)'
            END CATCH
         END

         IF @n_Channel_ID > 0
         BEGIN
            --(Wan02) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - START
            DECLARE @b_UpdateChannel      BIT         = 1
                  , @n_ToChannel_ID       BIGINT      = 0
                  , @c_ToChannel          NVARCHAR(20)= ''

                  , @c_TransferKey        NVARCHAR(10)= ''
                  , @c_TransferLineNumber NVARCHAR(5) = ''
                  , @c_ToFacility         NVARCHAR(5) = ''
                  , @c_ToStorerKey        NVARCHAR(15)= ''
                  , @c_ToSku              NVARCHAR(20)= ''
                  , @c_C_AttributeLbl01   NVARCHAR(30)= ''
                  , @c_C_AttributeLbl02   NVARCHAR(30)= ''
                  , @c_C_AttributeLbl03   NVARCHAR(30)= ''
                  , @c_C_AttributeLbl04   NVARCHAR(30)= ''
                  , @c_C_AttributeLbl05   NVARCHAR(30)= ''
                  , @c_C_Attribute01      NVARCHAR(30)= ''
                  , @c_C_Attribute02      NVARCHAR(30)= ''
                  , @c_C_Attribute03      NVARCHAR(30)= ''
                  , @c_C_Attribute04      NVARCHAR(30)= ''
                  , @c_C_Attribute05      NVARCHAR(30)= ''
                  , @c_ToLottable01       NVARCHAR(30)= ''
                  , @c_ToLottable02       NVARCHAR(30)= ''
                  , @c_ToLottable03       NVARCHAR(30)= ''
                  , @d_ToLottable04       DATETIME
                  , @d_ToLottable05       DATETIME
                  , @c_ToLottable06       NVARCHAR(30)=''
                  , @c_ToLottable07       NVARCHAR(30)=''
                  , @c_ToLottable08       NVARCHAR(30)=''
                  , @c_ToLottable09       NVARCHAR(30)=''
                  , @c_ToLottable10       NVARCHAR(30)=''
                  , @c_ToLottable11       NVARCHAR(30)=''
                  , @c_ToLottable12       NVARCHAR(30)=''
                  , @d_ToLottable13       DATETIME
                  , @d_ToLottable14       DATETIME
                  , @d_ToLottable15       DATETIME
                  , @c_ToLottable04       NVARCHAR(30) --NJOW01
                  , @c_ToLottable05       NVARCHAR(30)
                  , @c_ToLottable13       NVARCHAR(30)
                  , @c_ToLottable14       NVARCHAR(30)
                  , @c_ToLottable15       NVARCHAR(30)


                  , @c_ToChannelInventoryMgmt   NVARCHAR(10) = ''

            SET @b_UpdateChannel = 1

            IF @c_SourceType LIKE 'ntrTransferDetail%'
            BEGIN
               SET @c_TransferKey = SUBSTRING(@c_SourceKey, 1, 10)
               SET @c_TransferLineNumber = SUBSTRING(@c_SourceKey, 11, 5)

               SET @n_ToChannel_ID = 0
               SELECT
                     @c_ToFacility   = TFH.ToFacility
                   , @c_ToStorerkey  = TFH.ToStorerkey
                   , @c_ToSku        = TFD.ToSku
                   , @c_ToChannel    = TFD.ToChannel
                   , @n_ToChannel_ID = TFD.ToChannel_ID
                   , @c_ToLottable01 = TFD.ToLottable01
                   , @c_ToLottable02 = TFD.ToLottable02
                   , @c_ToLottable03 = TFD.ToLottable03
                   , @d_ToLottable04 = TFD.ToLottable04
                   , @d_ToLottable05 = TFD.ToLottable05
                   , @c_ToLottable06 = TFD.ToLottable06
                   , @c_ToLottable07 = TFD.ToLottable07
                   , @c_ToLottable08 = TFD.ToLottable08
                   , @c_ToLottable09 = TFD.ToLottable09
                   , @c_ToLottable10 = TFD.ToLottable10
                   , @c_ToLottable11 = TFD.ToLottable11
                   , @c_ToLottable12 = TFD.ToLottable12
                   , @d_ToLottable13 = TFD.ToLottable13
                   , @d_ToLottable14 = TFD.ToLottable14
                   , @d_ToLottable15 = TFD.ToLottable15
               FROM  TRANSFER       TFH WITH (NOLOCK)
               JOIN  TRANSFERDETAIL TFD WITH (NOLOCK) ON TFH.Transferkey = TFD.Transferkey
               WHERE TFD.TransferKey = @c_TransferKey
               AND   TFD.TransferLineNumber = @c_TransferLineNumber

               IF @n_ToChannel_ID = 0
               BEGIN
                   SET @b_success = 0
                   Execute nspGetRight2
                        @c_ToFacility
                      , @c_ToStorerKey             -- Storer
                      , @c_ToSKU                   -- Sku
                      , 'ChannelInventoryMgmt'     -- ConfigKey
                      , @b_success                 OUTPUT
                      , @c_ToChannelInventoryMgmt  OUTPUT
                      , @n_Err                     OUTPUT
                      , @c_ErrMsg                  OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 61962
                     SET @c_ErrMsg = 'nspItrnAddWithdrawalCheck:' + ISNULL(RTRIM(@c_ErrMsg),'')
                  END

                  IF @c_ToChannelInventoryMgmt = '1'
                  BEGIN

                     SELECT @n_Cnt = 1
                           ,@c_C_AttributeLbl01 = cac.C_AttributeLabel01
                           ,@c_C_AttributeLbl02 = cac.C_AttributeLabel02
                           ,@c_C_AttributeLbl03 = cac.C_AttributeLabel03
                           ,@c_C_AttributeLbl04 = cac.C_AttributeLabel04
                           ,@c_C_AttributeLbl05 = cac.C_AttributeLabel05
                     FROM   ChannelAttributeConfig AS cac WITH(NOLOCK)
                     WHERE  cac.StorerKey = @c_ToStorerKey
                     
                     --NJOW01
                     SET @c_ToLottable04 = @d_ToLottable04 
                     SET @c_ToLottable05 = @d_ToLottable05 
                     SET @c_ToLottable13 = @d_ToLottable13 
                     SET @c_ToLottable14 = @d_ToLottable14 
                     SET @c_ToLottable15 = @d_ToLottable15 

                     SET @c_C_Attribute01 = CASE @c_C_AttributeLbl01
                                             WHEN 'Lottable01' THEN @c_ToLottable01
                                             WHEN 'Lottable02' THEN @c_ToLottable02
                                             WHEN 'Lottable03' THEN @c_ToLottable03
                                             WHEN 'Lottable04' THEN @c_ToLottable04 --CONVERT(NVARCHAR(10), @d_ToLottable04, 121) --NJOW01
                                             WHEN 'Lottable05' THEN @c_ToLottable05 --CONVERT(NVARCHAR(10), @d_ToLottable05, 121)
                                             WHEN 'Lottable06' THEN @c_ToLottable06
                                             WHEN 'Lottable07' THEN @c_ToLottable07
                                             WHEN 'Lottable08' THEN @c_ToLottable08
                                             WHEN 'Lottable09' THEN @c_ToLottable09
                                             WHEN 'Lottable10' THEN @c_ToLottable10
                                             WHEN 'Lottable11' THEN @c_ToLottable11
                                             WHEN 'Lottable12' THEN @c_ToLottable12
                                             WHEN 'Lottable13' THEN @c_ToLottable13 --CONVERT(NVARCHAR(10), @d_ToLottable13, 121)
                                             WHEN 'Lottable14' THEN @c_ToLottable14 --CONVERT(NVARCHAR(10), @d_ToLottable14, 121)
                                             WHEN 'Lottable15' THEN @c_ToLottable15 --CONVERT(NVARCHAR(10), @d_ToLottable15, 121)
                                             ELSE ''
                                             END

                     SET @c_C_Attribute02 = CASE @c_C_AttributeLbl02
                                             WHEN 'Lottable01' THEN @c_ToLottable01
                                             WHEN 'Lottable02' THEN @c_ToLottable02
                                             WHEN 'Lottable03' THEN @c_ToLottable03
                                             WHEN 'Lottable04' THEN @c_ToLottable04 --CONVERT(NVARCHAR(10), @d_ToLottable04, 121)
                                             WHEN 'Lottable05' THEN @c_ToLottable05 --CONVERT(NVARCHAR(10), @d_ToLottable05, 121)
                                             WHEN 'Lottable06' THEN @c_ToLottable06
                                             WHEN 'Lottable07' THEN @c_ToLottable07
                                             WHEN 'Lottable08' THEN @c_ToLottable08
                                             WHEN 'Lottable09' THEN @c_ToLottable09
                                             WHEN 'Lottable10' THEN @c_ToLottable10
                                             WHEN 'Lottable11' THEN @c_ToLottable11
                                             WHEN 'Lottable12' THEN @c_ToLottable12
                                             WHEN 'Lottable13' THEN @c_ToLottable13 --CONVERT(NVARCHAR(10), @d_ToLottable13, 121)
                                             WHEN 'Lottable14' THEN @c_ToLottable14 --CONVERT(NVARCHAR(10), @d_ToLottable14, 121)
                                             WHEN 'Lottable15' THEN @c_ToLottable15 --CONVERT(NVARCHAR(10), @d_ToLottable15, 121)
                                             ELSE ''
                                             END

                     SET @c_C_Attribute03 = CASE @c_C_AttributeLbl03
                                             WHEN 'Lottable01' THEN @c_ToLottable01
                                             WHEN 'Lottable02' THEN @c_ToLottable02
                                             WHEN 'Lottable03' THEN @c_ToLottable03
                                             WHEN 'Lottable04' THEN @c_ToLottable04 --CONVERT(NVARCHAR(10), @d_ToLottable04, 121)
                                             WHEN 'Lottable05' THEN @c_ToLottable05 --CONVERT(NVARCHAR(10), @d_ToLottable05, 121)
                                             WHEN 'Lottable06' THEN @c_ToLottable06
                                             WHEN 'Lottable07' THEN @c_ToLottable07
                                             WHEN 'Lottable08' THEN @c_ToLottable08
                                             WHEN 'Lottable09' THEN @c_ToLottable09
                                             WHEN 'Lottable10' THEN @c_ToLottable10
                                             WHEN 'Lottable11' THEN @c_ToLottable11
                                             WHEN 'Lottable12' THEN @c_ToLottable12
                                             WHEN 'Lottable13' THEN @c_ToLottable13 --CONVERT(NVARCHAR(10), @d_ToLottable13, 121)
                                             WHEN 'Lottable14' THEN @c_ToLottable14 --CONVERT(NVARCHAR(10), @d_ToLottable14, 121)
                                             WHEN 'Lottable15' THEN @c_ToLottable15 --CONVERT(NVARCHAR(10), @d_ToLottable15, 121)
                                             ELSE ''
                                             END

                     SET @c_C_Attribute04 = CASE @c_C_AttributeLbl04
                                             WHEN 'Lottable01' THEN @c_ToLottable01
                                             WHEN 'Lottable02' THEN @c_ToLottable02
                                             WHEN 'Lottable03' THEN @c_ToLottable03
                                             WHEN 'Lottable04' THEN @c_ToLottable04 --CONVERT(NVARCHAR(10), @d_ToLottable04, 121)
                                             WHEN 'Lottable05' THEN @c_ToLottable05 --CONVERT(NVARCHAR(10), @d_ToLottable05, 121)
                                             WHEN 'Lottable06' THEN @c_ToLottable06
                                             WHEN 'Lottable07' THEN @c_ToLottable07
                                             WHEN 'Lottable08' THEN @c_ToLottable08
                                             WHEN 'Lottable09' THEN @c_ToLottable09
                                             WHEN 'Lottable10' THEN @c_ToLottable10
                                             WHEN 'Lottable11' THEN @c_ToLottable11
                                             WHEN 'Lottable12' THEN @c_ToLottable12
                                             WHEN 'Lottable13' THEN @c_ToLottable13 --CONVERT(NVARCHAR(10), @d_ToLottable13, 121)
                                             WHEN 'Lottable14' THEN @c_ToLottable14 --CONVERT(NVARCHAR(10), @d_ToLottable14, 121)
                                             WHEN 'Lottable15' THEN @c_ToLottable15 --CONVERT(NVARCHAR(10), @d_ToLottable15, 121)
                                             ELSE ''
                                             END

                     SET @c_C_Attribute05 = CASE @c_C_AttributeLbl05
                                             WHEN 'Lottable01' THEN @c_ToLottable01
                                             WHEN 'Lottable02' THEN @c_ToLottable02
                                             WHEN 'Lottable03' THEN @c_ToLottable03
                                             WHEN 'Lottable04' THEN @c_ToLottable04 --CONVERT(NVARCHAR(10), @d_ToLottable04, 121)
                                             WHEN 'Lottable05' THEN @c_ToLottable05 --CONVERT(NVARCHAR(10), @d_ToLottable05, 121)
                                             WHEN 'Lottable06' THEN @c_ToLottable06
                                             WHEN 'Lottable07' THEN @c_ToLottable07
                                             WHEN 'Lottable08' THEN @c_ToLottable08
                                             WHEN 'Lottable09' THEN @c_ToLottable09
                                             WHEN 'Lottable10' THEN @c_ToLottable10
                                             WHEN 'Lottable11' THEN @c_ToLottable11
                                             WHEN 'Lottable12' THEN @c_ToLottable12
                                             WHEN 'Lottable13' THEN @c_ToLottable13 --CONVERT(NVARCHAR(10), @d_ToLottable13, 121)
                                             WHEN 'Lottable14' THEN @c_ToLottable14 --CONVERT(NVARCHAR(10), @d_ToLottable14, 121)
                                             WHEN 'Lottable15' THEN @c_ToLottable15 --CONVERT(NVARCHAR(10), @d_ToLottable15, 121)
                                             ELSE ''
                                             END
                                             
                     SET @n_ToChannel_ID = 0
                     SELECT @n_ToChannel_ID = ci.Channel_ID
                     FROM ChannelInv AS ci WITH(NOLOCK)
                     WHERE ci.StorerKey = @c_ToStorerKey
                     AND   ci.SKU = @c_ToSku
                     AND   ci.Facility = @c_ToFacility
                     AND   ci.Channel = @c_ToChannel
                     AND   ci.C_Attribute01 = @c_C_Attribute01
                     AND   ci.C_Attribute02 = @c_C_Attribute02
                     AND   ci.C_Attribute03 = @c_C_Attribute03
                     AND   ci.C_Attribute04 = @c_C_Attribute04
                     AND   ci.C_Attribute05 = @c_C_Attribute05

                  END
               END

               IF @n_ToChannel_ID = @n_Channel_ID
               BEGIN
                  SET @b_UpdateChannel = 0
               END
            END
            --(Wan02) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - END
            --(Wan01) - START: Use Channel InventoryHold to Hold Instead
            --IF EXISTS(SELECT 1 FROM LOC WITH (NOLOCK)
            --            WHERE Loc = @c_ToLoc
            --            AND ( LocationFlag IN ('DAMAGE','HOLD') OR LOC.[Status]  ='HOLD' ))
            --            AND @c_ChannelZeroLocHold = '0'
            --BEGIN
            -- UPDATE ChannelInv WITH (ROWLOCK)
            --    SET Qty = Qty + @n_Qty,
            --          QtyOnHold = QtyOnHold + @n_Qty,
            --          EditDate = GETDATE(),
            --          EditWho  = SUSER_SNAME()
            -- WHERE Channel_ID = @n_Channel_ID
            --SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            --END
            --ELSE
            --(Wan01) - END
            --(Wan02) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - START
            IF @b_UpdateChannel = 1
            BEGIN
                UPDATE ChannelInv WITH (ROWLOCK)
                   SET Qty = Qty + @n_qty,
                       EditDate = GETDATE(),
                       EditWho  = SUSER_SNAME()
                WHERE Channel_ID = @n_Channel_ID
                SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 61992
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)
                  +': Update Failed on Table ChannelInv. (nspItrnAddWithdrawalCheck)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            --(Wan02) - Allow Tranfer if from/to Channel ID are same and even if has qtyallocated & qtyonhold - END
         END
      END
      ELSE
      BEGIN
         SET @n_Channel_ID = 0
      END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE Itrn WITH (ROWLOCK)
      SET TrafficCop = NULL,
            StorerKey = @c_StorerKey,
            Sku = @c_SKU,
            Lot = @c_Lot,
            ToId = @c_ToId,
            ToLoc = @c_ToLoc,
            Lottable04 = @d_Lottable04,
            Lottable05 = @d_Lottable05,
            Status = @c_Status,
            Channel_ID = @n_Channel_ID, -- (SWT02)
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
      WHERE ItrnKey = @c_itrnkey
   END
   --(Wan03) - START
   IF @n_continue IN (1,2) AND @c_SourceType IN ('ntrPickDetailAdd', 'ntrPickDetailUpdate')
   BEGIN
      DECLARE @c_UCC          NVARCHAR(30) = ''
            , @c_UCCTracking  NVARCHAR(30) = ''

      SET @b_success = 0
      SET @c_UCC = ''
      Execute nspGetRight
         @c_facility = @c_facility
      ,  @c_StorerKey= @c_StorerKey                   -- Storer
      ,  @c_Sku      = ''                             -- Sku
      ,  @c_ConfigKey= 'UCC'                          -- ConfigKey
      ,  @b_success  = @b_success         OUTPUT
      ,  @c_authority= @c_UCC             OUTPUT
      ,  @n_err      = @n_err             OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 62710
         SET @c_ErrMsg = 'nspItrnAddWithdrawalCheck:' + ISNULL(RTRIM(@c_ErrMsg),'')
      END

      IF @n_continue IN (1,2)
      BEGIN
         SET @b_success = 0
         SET @c_UCCTracking = ''
         Execute nspGetRight
            @c_facility = @c_facility
         ,  @c_StorerKey= @c_StorerKey                   -- Storer
         ,  @c_Sku      = ''                             -- Sku
         ,  @c_ConfigKey= 'UCCTracking'                  -- ConfigKey
         ,  @b_success  = @b_success         OUTPUT
         ,  @c_authority= @c_UCCTracking     OUTPUT
         ,  @n_err      = @n_err             OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 62711
            SET @c_ErrMsg = 'nspItrnAddWithdrawalCheck:' + ISNULL(RTRIM(@c_ErrMsg),'')
         END
      END

      IF @n_continue IN (1,2) AND (@c_UCC = '1' OR @c_UCCTracking = '1')
      BEGIN
         EXEC isp_ItrnUCCAdd
           @c_Storerkey       = @c_StorerKey
         , @c_UCCNo           = ''
         , @c_Sku             = @c_Sku
         , @c_UCCStatus       = ''
         , @c_SourceKey       = @c_Sourcekey
         , @c_ItrnSourceType  = @c_SourceType
         , @c_ToStorerkey     = ''
         , @c_ToUCCNo         = ''
         , @c_ToSku           = ''
         , @c_ToUCCStatus     = ''
         , @b_Success         = @b_Success          OUTPUT
         , @n_Err             = @n_Err              OUTPUT
         , @c_ErrMsg          = @c_ErrMsg           OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62712
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Add ITRN UCC Fail. (isp_FinalizeADJ)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
         END
      END
   END
   --(Wan03) - END

   --(Wan04) - START
   IF @n_continue IN (1,2) AND @c_SourceType IN ('ntrTransferDetailAdd', 'ntrTransferDetailUpdate')
   BEGIN
      EXEC ispITrnSerialNoWithdrawal
           @c_ITrnKey      = @c_ITrnKey
         , @c_TranType     = 'WD'
         , @c_StorerKey    = @c_StorerKey
         , @c_Sku          = @c_Sku
         , @n_Qty          = @n_Qty
         , @c_SourceKey    = @c_SourceKey
         , @c_SourceType   = @c_SourceType
         , @b_Success      = @b_Success   OUTPUT
         , @n_Err          = @n_Err       OUTPUT
         , @c_ErrMsg       = @c_ErrMsg    OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3 /* Other Error flags Set By nspItrnAddWithDrawalCheck */
      END
   END
   --(Wan04) - END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF (SELECT NSQLValue FROM NSQLConfig (NOLOCK) WHERE ConfigKey = 'WAREHOUSEBILLING') = '1'
      BEGIN
         EXECUTE nspItrnAddDWBill 'W',  @c_itrnkey,  @c_StorerKey,  @c_SKU,  @c_Lot,  @c_ToLoc,  @c_ToID,  @c_Status,  @n_CaseCnt,
            @n_InnerPack,  @n_Qty,  @n_Pallet,  @f_cube,  @f_GrossWgt,  @f_NetWgt,  @f_otherunit1,  @f_otherunit2,  @c_Lottable01,
            @c_Lottable02,  @c_Lottable03,  @d_Lottable04,  @d_Lottable05,  @c_sourcekey,  @c_sourcetype,
            @b_Success OUTPUT,    @n_Err OUTPUT,    @c_ErrMsg OUTPUT
         IF @b_Success = 0
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END
END

/* #INCLUDE <SPIAWC2.SQL> */
IF @n_continue = 3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT = 1
   BEGIN
      -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
      -- Instead we commit and raise an error back to parent, let the parent decide

      -- Commit until the level we begin with
      -- Notes: Original codes do not have COMMIT TRAN, error will be handled by parent
      -- WHILE @@TRANCOUNT > @n_starttcnt
      --    COMMIT TRAN

      -- Raise error with severity = 10, instead of the default severity 16.
      -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
      RAISERROR (@n_Err, 10, 1) WITH SETERROR

      -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
   END
   ELSE
   BEGIN
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'nspItrnAddWithdrawalCheck'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END
ELSE
BEGIN
   SELECT @b_success = 1
   RETURN
END

GO