SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CancelOrdersWithTransferTrasmitLog             */
/* Creation Date: 24-FEB-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-12087_IN_HM_Bulk Cancellated order's stock Transfer     */
/*                                                                      */
/* Called By: backend cancer orders job                                 */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 08-Nov-2021  Leong    1.1  JSM-29716 - Bug fix.                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_CancelOrdersWithTransferTrasmitLog]
     @c_Orderkey       NVARCHAR(10)
   , @b_Success        INT           OUTPUT
   , @n_Err            INT           OUTPUT
   , @c_ErrMsg         NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue      INT
         , @n_StartTCnt     INT
         , @c_SPCode        NVARCHAR(10)
         , @c_Storerkey     NVARCHAR(15)
         , @c_SQL           NVARCHAR(MAX)

   DECLARE @c_ToStorerkey        NVARCHAR(15)
         , @c_FromSku            NVARCHAR(20)
         , @c_ToSku              NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @dt_Lottable04        DATETIME
         , @dt_Lottable05        DATETIME
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @dt_Lottable13        DATETIME
         , @dt_Lottable14        DATETIME
         , @dt_Lottable15        DATETIME
         , @c_ToFacility         NVARCHAR(5) = ''
         , @c_TransferLineNumber NVARCHAR(5)
         , @n_StartTranCount     INT
         , @n_LineNo             INT
         , @c_Type               NVARCHAR(12) = 'HM-344'
         , @c_Transferkey        NVARCHAR(10) = ''
         , @c_ReasonCode         NVARCHAR(10) = 'HM02'
         , @c_FromFacility       NVARCHAR(5)  = ''
         , @c_CustomerRefNo      NVARCHAR(20) = ''
         , @c_Remarks            NVARCHAR(200) = ''
         , @c_FromLot            NVARCHAR(10) = ''
         , @c_FromLoc            NVARCHAR(10) = ''
         , @c_FromID             NVARCHAR(18) = ''
         , @n_FromQty            INT          = 0
         , @n_ToQty              INT          = 0
         , @c_ToLot              NVARCHAR(10) = ''
         , @c_ToLoc              NVARCHAR(10) = ''
         , @c_ToID               NVARCHAR(18) = ''
         , @c_PickSlipno         NVARCHAR(20) = ''
         , @c_POrderkey          NVARCHAR(10) = ''
         , @c_Pickdetailkey      NVARCHAR(10) = ''

   DECLARE @c_ToLottable01       NVARCHAR(18) = ''
         , @c_ToLottable02       NVARCHAR(18) = ''
         , @c_ToLottable03       NVARCHAR(18) = ''
         , @dt_ToLottable04      DATETIME = NULL
         , @dt_ToLottable05      DATETIME = NULL
         , @c_ToLottable06       NVARCHAR(18) = ''
         , @c_ToLottable07       NVARCHAR(30) = ''
         , @c_ToLottable08       NVARCHAR(30) = ''
         , @c_ToLottable09       NVARCHAR(30) = ''
         , @c_ToLottable10       NVARCHAR(30) = ''
         , @c_ToLottable11       NVARCHAR(30) = ''
         , @c_ToLottable12       NVARCHAR(30) = ''
         , @dt_ToLottable13      DATETIME = NULL
         , @dt_ToLottable14      DATETIME = NULL
         , @dt_ToLottable15      DATETIME = NULL

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @c_SPCode     = ''
   SET @c_SQL        = ''
   SET @c_Storerkey  = ''

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_OrderKey

   SET @c_toStorerkey = @c_Storerkey

   BEGIN TRAN

   /*****************************************
   Create Transfer
   *****************************************/
   DECLARE CUR_Transfer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PD.Lot, PD.Loc, PD.Id
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PD.OrderKey
      WHERE PD.Orderkey = @c_Orderkey
      AND PD.Storerkey  = @c_Storerkey
      AND OH.[Status] < '9' AND OH.SOSTATUS <> 'CANC'
      ORDER BY PD.Lot, PD.Loc, PD.Id

   OPEN CUR_Transfer
   FETCH NEXT FROM CUR_Transfer INTO @c_fromlot, @c_fromloc, @c_fromid

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_FromFacility = ''
      SET @c_ToFacility = ''

      SET @c_ToLot = ''
      SET @c_ToLoc = ''
      SET @c_ToID = @c_FromID
      SET @c_Packkey = ''
      SET @c_UOM =  ''

      SELECT @c_FromFacility = LOC.Facility
      FROM LOC (NOLOCK)
      WHERE Loc = @c_fromloc

      SELECT TOP 1 @c_ToLoc = C.code
      FROM CODELKUP C WITH (NOLOCK)
      WHERE C.LISTNAME = 'CANCLOC'
      AND C.storerkey = @c_storerkey

      SET @c_ToFacility = @c_FromFacility

      SELECT @b_success = 0
      EXECUTE nspg_getkey
            'TRANSFER'
            , 10
            , @c_TransferKey OUTPUT
            , @b_success     OUTPUT
            , @n_err         OUTPUT
            , @c_errmsg      OUTPUT

      IF @b_success = 1
      BEGIN
         INSERT INTO TRANSFER (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, CustomerRefNo, Remarks, Facility, ToFacility)
         VALUES (@c_TransferKey, @c_Storerkey, @c_Storerkey, @c_Type, @c_ReasonCode, @c_OrderKey, @c_Remarks, @c_FromFacility, @c_ToFacility) -- JSM-29716

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63330
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Transfer Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63340
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Generate Transfer Key Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      DECLARE CUR_TransferDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PD.Sku--,SUM(qty)
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PD.OrderKey
         WHERE PD.Orderkey = @c_Orderkey
         AND PD.Storerkey  = @c_Storerkey
         AND PD.Loc        = @c_FromLoc
         AND PD.Lot        = @c_FromLot
         AND PD.ID         = @c_FromID
         AND OH.[Status] < '9' AND OH.SOSTATUS <> 'CANC'
         ORDER BY PD.sku

      OPEN CUR_TransferDetail
      FETCH NEXT FROM CUR_TransferDetail INTO @c_FromSku--,@n_fromqty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_fromqty = 0

         SELECT @c_Packkey = PACKKEY
         FROM SKU WITH (NOLOCK)
         WHERE SKU = @c_FromSku
         AND StorerKey = @c_Storerkey

         SELECT @c_UOM = PACK.PackUOM3
         FROM PACK WITH (NOLOCK)
         WHERE PACK.PackKey = @c_Packkey

         SELECT @n_fromqty = SUM(PD.qty)
         FROM PICKDETAIL PD WITH (NOLOCK)
         WHERE PD.orderkey = @c_Orderkey
         AND PD.sku = @c_FromSku
         AND PD.Storerkey = @c_Storerkey
         AND PD.Loc = @c_FromLoc
         AND PD.Lot = @c_FromLot
         AND PD.ID  = @c_FromID

         SET @c_ToSku = @c_FromSku
         SET @n_ToQty = @n_FromQty

         IF ISNULL(@c_fromlot,'') <> ''
         BEGIN
            SELECT @c_ToLottable01  = Lottable01,
                   @c_ToLottable02  = Lottable02,
                   @c_Lottable03    = Lottable03,
                   @dt_ToLottable04 = Lottable04,
                   @dt_ToLottable05 = Lottable05,
                   @c_ToLottable06  = Lottable06,
                   @c_ToLottable07  = Lottable07,
                   @c_ToLottable08  = Lottable08,
                   @c_ToLottable09  = Lottable09,
                   @c_ToLottable10  = Lottable10,
                   @c_ToLottable11  = Lottable11,
                   @c_ToLottable12  = Lottable12,
                   @dt_ToLottable13 = Lottable13,
                   @dt_ToLottable14 = Lottable14,
                   @dt_ToLottable15 = Lottable15
            FROM LOTATTRIBUTE WITH (NOLOCK)
            WHERE Lot     = @c_fromlot
            AND Storerkey = @c_Storerkey
            AND Sku       = @c_FromSku
         END

         SET @c_Lottable01   = @c_ToLottable01
         SET @c_Lottable02   = @c_ToLottable02
         SET @c_ToLottable03 = 'BLO'
         SET @dt_Lottable04  = @dt_ToLottable04
         SET @dt_Lottable05  = @dt_ToLottable05
         SET @c_Lottable06   = @c_ToLottable06
         SET @c_Lottable07   = @c_ToLottable07
         SET @c_Lottable08   = @c_ToLottable08
         SET @c_Lottable09   = @c_ToLottable09
         SET @c_Lottable10   = @c_ToLottable10
         SET @c_Lottable11   = @c_ToLottable11
         SET @c_Lottable12   = @c_ToLottable12
         SET @dt_Lottable13  = @dt_ToLottable13
         SET @dt_Lottable14  = @dt_ToLottable14
         SET @dt_Lottable15  = @dt_ToLottable15

         SELECT @n_LineNo = @n_LineNo + 1
         SELECT @c_TransferLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NChar(5))), 5)

         INSERT TRANSFERDETAIL (Transferkey, TransferLineNumber, FromStorerkey, FromSku, FromLot, FromLoc, FromID, FromQty, FromPackkey, FromUOM,
                                Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                                Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, ToStorerkey, ToSku, ToLot, ToLoc, ToID, ToQty, ToPackkey, ToUOM,
                                ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05, ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,
                                ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15)
         VALUES (@c_Transferkey, @c_TransferLineNumber, @c_Storerkey, @c_FromSku, @c_FromLot, @c_FromLoc, @c_FromID, @n_FromQty, @c_Packkey, @c_UOM,
                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                 @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15, @c_ToStorerkey, @c_ToSku, @c_ToLot, @c_ToLoc, @c_ToID, @n_ToQty, @c_Packkey, @c_UOM,
                 @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05, @c_ToLottable06, @c_ToLottable07, @c_ToLottable08, @c_ToLottable09, @c_ToLottable10,
                 @c_ToLottable11, @c_ToLottable12, @dt_ToLottable13, @dt_ToLottable14, @dt_ToLottable15)

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63350
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert TransferDetail Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_TransferDetail INTO @c_FromSku,@n_fromqty
      END
      CLOSE CUR_TransferDetail
      DEALLOCATE CUR_TransferDetail

      FETCH NEXT FROM CUR_Transfer INTO @c_fromlot,@c_fromloc,@c_fromid
   END
   CLOSE CUR_Transfer
   DEALLOCATE CUR_Transfer

   /*****************************************
   Unallocate Orders
   *****************************************/
   DECLARE cur_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT O.Orderkey, PH.PickSlipNo, O.Storerkey
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      WHERE PH.Orderkey = @c_Orderkey
      AND O.[Status] < '9' AND O.SOSTATUS <> 'CANC'

   OPEN cur_ORDER
   FETCH NEXT FROM cur_ORDER INTO @c_Orderkey, @c_PickSlipno, @c_Storerkey

   WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1, 2)
   BEGIN
      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = '0'
      WHERE ArchiveCop = NULL
      AND Pickslipno = @c_pickslipno

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63360
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE PACKHEADER Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      DELETE PACKDETAIL WHERE PickslipNo = @c_pickslipno

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63370
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKDETAIL Table. (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      FETCH NEXT FROM cur_ORDER INTO @c_Orderkey, @c_PickSlipno, @c_Storerkey
   END
   CLOSE cur_ORDER
   DEALLOCATE cur_ORDER

   DECLARE Pickdet_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Pickdetailkey
      FROM PICKDETAIL WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PICKDETAIL.OrderKey
      WHERE PICKDETAIL.OrderKey = @c_Orderkey
      AND OH.[Status] < '9' AND OH.SOSTATUS <> 'CANC'
      ORDER BY PICKDETAIL.Pickdetailkey

   OPEN Pickdet_Cur
   FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey

   WHILE @@FETCH_STATUS = 0  AND @n_continue IN (1, 2)
   BEGIN
      DELETE FROM PICKDETAIL
      WHERE Pickdetailkey = @c_Pickdetailkey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63380
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Delete PICKDETAIL Table. (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END

      FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey
   END
   CLOSE Pickdet_Cur
   DEALLOCATE Pickdet_Cur

   IF @n_continue IN (1, 2)
   BEGIN
      IF EXISTS ( SELECT 1 FROM LOADPLANDETAIL(NOLOCK) WHERE Orderkey = @c_Orderkey )
      BEGIN
         DELETE FROM LOADPLANDETAIL
         WHERE Orderkey = @c_Orderkey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63390
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Delete LOADPLANDETAIL Failed. (isp_CancelOrdersWithTransferTrasmitlo)' +
                               ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END

      IF EXISTS ( SELECT 1 FROM WAVEDETAIL(NOLOCK) WHERE Orderkey = @c_Orderkey )
      BEGIN
         DELETE FROM WAVEDETAIL
         WHERE Orderkey = @c_Orderkey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63400
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Delete WAVEDETAIL Failed. (ispCANPK01)' + ' ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END

      UPDATE ORDERS WITH (ROWLOCK)
      SET Status   = 'CANC',
          SOStatus = 'CANC'
      WHERE Orderkey = @c_Orderkey

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63410
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS Failed. (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END

   /*****************************************
   Finalize Transfer
   *****************************************/
   -- IF ISNULL(@c_Transferkey,'') <> ''
   -- BEGIN
   --    EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
   --
   --    IF @b_Success <> 1
   --    BEGIN
   --       SELECT @n_continue = 3
   --       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63420
   --       SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
   --                        + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   --       GOTO QUIT_SP
   --    END
   -- END

   -- JSM-29716
   SET @c_Transferkey = ''
   DECLARE Cur_Finalize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TransferKey
      FROM [Transfer] WITH (NOLOCK)
      WHERE [CustomerRefNo] = @c_Orderkey
      AND   [FromStorerKey] = @c_StorerKey
      AND   [Type]          = @c_Type
      AND   [Status]        = '0'
      ORDER BY TransferKey

   OPEN Cur_Finalize
   FETCH NEXT FROM Cur_Finalize INTO @c_Transferkey

   WHILE @@FETCH_STATUS = 0  AND @n_continue IN (1, 2)
   BEGIN
      SET @b_Success = 0
      EXEC ispFinalizeTransfer
           @c_Transferkey
         , @b_Success OUTPUT
         , @n_err     OUTPUT
         , @c_errmsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63420
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer Failed! (isp_CancelOrdersWithTransferTrasmitlog)' + ' ( '
                          + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      FETCH NEXT FROM Cur_Finalize INTO @c_Transferkey
   END
   CLOSE Cur_Finalize
   DEALLOCATE Cur_Finalize

   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_CancelOrdersWithTransferTrasmitlog'
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END
SET QUOTED_IDENTIFIER OFF

GO