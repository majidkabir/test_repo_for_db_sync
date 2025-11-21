SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispITrnSerialNoWithdrawal                               */
/* Creation Date: 13-DEC-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3543 - CN_DYSON_Close serialno status_CR                */
/*        :                                                             */
/* Called By: ntrITRNAdd                                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-08-12  Wan01    1.1   LFWM-4446 - RG[GIT] Serial Number Solution*/
/*                            - Transfer by Serial Number               */
/************************************************************************/
CREATE   PROC [dbo].[ispITrnSerialNoWithdrawal]
     @c_ITrnKey      NVARCHAR(10)
   , @c_TranType     NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_Sku          NVARCHAR(20)
   , @n_Qty          INT
   , @c_SourceKey    NVARCHAR(20)
   , @c_SourceType   NVARCHAR(30)
   , @b_Success      INT            OUTPUT  
   , @n_Err          INT            OUTPUT  
   , @c_ErrMsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_PickDetailKey   NVARCHAR(10)
         , @c_SerialNoKey     NVARCHAR(10)
         , @c_SerialNo        NVARCHAR(30)

         , @n_PackSerialQty   INT

         , @c_TransferKey     NVARCHAR(10) = ''                                     --(Wan01)
         , @c_TransferLineNo  NVARCHAR(10) = ''                                     --(Wan01)

         , @c_Lot             NVARCHAR(10) = ''                                     --(Wan01)
         , @c_Loc             NVARCHAR(10) = ''                                     --(Wan01)
         , @c_ID              NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable01      NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable02      NVARCHAR(18) = ''                                     --(Wan01)
         , @c_lottable03      NVARCHAR(18) = ''                                     --(Wan01)
         , @d_lottable04      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable05      DATETIME     = NULL                                   --(Wan01)
         , @c_lottable06      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable07      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable08      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable09      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable10      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable11      NVARCHAR(30) = ''                                     --(Wan01)
         , @c_lottable12      NVARCHAR(30) = ''                                     --(Wan01)
         , @d_lottable13      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable14      DATETIME     = NULL                                   --(Wan01)
         , @d_lottable15      DATETIME     = NULL                                   --(Wan01)
         , @c_Status          NVARCHAR(10) = ''                                     --(Wan01)
         , @c_UCCNo           NVARCHAR(20) = ''                                     --(Wan01)

   DECLARE @CUR_SN            CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @c_SourceType IN ('ntrPickDetailAdd', 'ntrPickDetailUpdate')                  --(Wan01)
   BEGIN
      SET @c_PickDetailKey = @c_SourceKey

      SET @CUR_SN = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PSN.SerialNo
            ,PSN.Storerkey
            ,PSN.Sku
            ,PSN.Qty
      FROM  PACKSERIALNO PSN WITH (NOLOCK)
      WHERE PSN.PickDetailkey = @c_PickDetailKey
      ORDER BY PSN.PackSerialNoKey
   
      OPEN @CUR_SN
   
      FETCH NEXT FROM @CUR_SN INTO @c_SerialNo, @c_Storerkey, @c_Sku, @n_PackSerialQty
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_SerialNoKey = ''
         SET @c_Lot = ''                                                            --(Wan01)
         SET @c_ID  = ''                                                            --(Wan01)
         SET @c_Status = ''                                                         --(Wan01)
         SET @c_UCCNo  = ''                                                         --(Wan01)
         SELECT @c_SerialNoKey = SerialNoKey
               ,@c_Lot = Lot                                                        --(Wan01)
               ,@c_ID  = ID                                                         --(Wan01)
               ,@c_Status = [Status]                                                --(Wan01)
               ,@c_UCCNo  = UCCNo                                                   --(Wan01)
         FROM SERIALNO WITH (NOLOCK)
         WHERE SerialNo = @c_SerialNo
         AND   Storerkey= @c_Storerkey
         AND   Sku      = @c_Sku
         AND   Status   = '6'

         IF @c_SerialNoKey <> ''
         BEGIN
            UPDATE SerialNo WITH (ROWLOCK)
            SET   Status ='9'
            WHERE SerialNoKey = @c_SerialNoKey
            AND Status = '6'

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 71000
               SET @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) + ' UPDATE SerialNo Table fail (ispITrnSerialNoWithdrawal)'
               GOTO QUIT_SP
            END

            SET @n_PackSerialQty = @n_PackSerialQty * -1

            INSERT INTO ITrnSerialNo (ITrnKey, TranType, StorerKey, SKU, SerialNo, QTY, SourceKey, SourceType
                                     ,Lot, Loc, ID                                                              --(Wan01)
                                     ,Lottable01, Lottable02, Lottable03, Lottable04, Lottable05                --(Wan01)
                                     ,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10                --(Wan01)
                                     ,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                --(Wan01)
                                     ,Channel, Channel_ID, UCCNo
                                     --,[Status]
                                     )
            VALUES (@c_ITrnKey, @c_TranType, @c_StorerKey, @c_SKU, @c_SerialNo, @n_PackSerialQty, @c_SourceKey, @c_SourceType
                   ,@c_Lot, @c_Loc, @c_ID
                   ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                   ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                   ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                   ,'', 0, ''
                   --,@c_Status
                   )
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 71010
               SET @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) + ' Insert ITrnSerialNo fail (ispITrnSerialNoWithdrawal)'
               GOTO QUIT_SP
            END
         END
      
         FETCH NEXT FROM @CUR_SN INTO @c_SerialNo, @c_Storerkey, @c_Sku, @n_PackSerialQty
      END
   END
   ELSE IF @c_SourceType like 'ntrTransferDetail%'
   BEGIN
      SET @c_TransferKey   = LEFT(@c_Sourcekey,10)
      SET @c_TransferLineNo= SUBSTRING(@c_Sourcekey,11,5)

      SELECT @c_SerialNo = td.FromSerialNo
      FROM TRANSFERDETAIL td (NOLOCK)
      WHERE td.Transferkey = @c_TransferKey
      AND   td.TransferLineNumber = @c_TransferLineNo

      IF @c_SerialNo <> ''
      BEGIN
         SET @c_Status = 'CANC'

         SELECT @c_Lot = Lot
               ,@c_ID  = ID
               ,@c_Status = [Status]
               ,@c_UCCNo  = UCCNo
         FROM SERIALNO WITH (NOLOCK)
         WHERE Storerkey  = @c_Storerkey
         AND   SerialNo   = @c_SerialNo
         AND   [Status]   = '1'

      IF @c_Lot <> ''
      BEGIN
         SELECT  @c_lottable01 = la.lottable01
               , @c_lottable02 = la.lottable02
               , @c_lottable03 = la.lottable03
               , @d_lottable04 = la.lottable04
               , @d_lottable05 = la.lottable05
               , @c_lottable06 = la.lottable06
               , @c_lottable07 = la.lottable07
               , @c_lottable08 = la.lottable08
               , @c_lottable09 = la.lottable09
               , @c_lottable10 = la.lottable10
               , @c_lottable11 = la.lottable11
               , @c_lottable12 = la.lottable12
               , @d_lottable13 = la.lottable13
               , @d_lottable14 = la.lottable14
               , @d_lottable15 = la.lottable15
         FROM LOTATTRIBUTE la (NOLOCK)
         WHERE la.Lot = @c_lot
      END

      INSERT INTO ITrnSerialNo (ITrnKey, TranType, StorerKey, SKU, SerialNo, QTY, SourceKey, SourceType
                               ,Lot, Loc, ID                                                              --(Wan01)
                               ,Lottable01, Lottable02, Lottable03, Lottable04, Lottable05                --(Wan01)
                               ,Lottable06, Lottable07, Lottable08, Lottable09, Lottable10                --(Wan01)
                               ,Lottable11, Lottable12, Lottable13, Lottable14, Lottable15                --(Wan01)
                               ,Channel, Channel_ID, UCCNo
                               --,[Status]
                               )
      VALUES (@c_ITrnKey, @c_TranType, @c_StorerKey, @c_SKU, @c_SerialNo, @n_QTY, @c_SourceKey, @c_SourceType
             ,@c_Lot, @c_Loc, @c_ID
             ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
             ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
             ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
             ,'', 0, ''
            --,@c_Status
             )
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 71020
            SET @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) + ' Insert ITrnSerialNo fail (ispITrnSerialNoWithdrawal)'
            GOTO QUIT_SP
         END
      END
   END
   --(Wan01) - END
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispITrnSerialNoWithdrawal'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO