SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: ispITrnSerialNoDeposit                                    */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Insert into ITrnSerialNo                                          */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2017-05-15 1.0  Ung         WMS-1817 Add serial no                         */
/* 2024-08-12 1.1  Wan01       LFWM-4446 - RG[GIT] Serial Number Solution     */
/*                             - Transfer by Serial Number                    */
/******************************************************************************/

CREATE   PROCEDURE dbo.ispITrnSerialNoDeposit (
     @c_ITrnKey      NVARCHAR(10) = ''                                              --(Wan01)
   , @c_TranType     NVARCHAR(10)
   , @c_StorerKey    NVARCHAR(15)
   , @c_SKU          NVARCHAR(20)
   , @c_SerialNo     NVARCHAR(30)
   , @n_QTY          INT
   , @c_SourceKey    NVARCHAR(20)
   , @c_SourceType   NVARCHAR(30)
   , @b_Success      INT            OUTPUT  
   , @n_Err          INT            OUTPUT  
   , @c_ErrMsg       NVARCHAR(250)  OUTPUT
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lot             NVARCHAR(10) = ''                                     --(Wan01)
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

   --DECLARE @c_ITrnKey NVARCHAR( 10)                                               --(Wan01)
   SET @c_ITrnKey = ISNULL(@c_ITrnKey,'')                                           --(Wan01)
   
   SET @b_Success = 0 -- False
   IF @c_ITrnKey = ''                                                               --(Wan01)
   BEGIN
      -- Get ITrn info
      SELECT @c_ITrnKey = ITrnKey
      FROM ITrn WITH (NOLOCK)
      WHERE TranType = 'DP'
         AND StorerKey = @c_StorerKey
         AND SKU = @c_SKU
         AND SourceKey = @c_SourceKey
      
      IF @@ROWCOUNT <> 1
      BEGIN
         SELECT @n_err = 109251
         SELECT @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) + ' ITrn deposit record not found (ispITrnSerialNoDeposit)'
         GOTO Quit
      END
   END

   SELECT @c_Lot = Lot                                                              --(Wan01) - START
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
   END                                                                              --(Wan01) - END

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
                           ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05  --(Wan01)
                           ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10  --(Wan01)
                           ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15  --(Wan01)
                           ,'', 0, @c_UCCNo
                           --,@c_Status
                           )

   IF @@ERROR <> 0
   BEGIN
      SELECT @n_err = 109252
      SELECT @c_errmsg = 'NSQL' + CAST( @n_err AS NVARCHAR(6)) + ' Insert ITrnSerialNo fail (ispITrnSerialNoDeposit)'
      GOTO Quit
   END
   
   SET @b_Success = 1 -- True
   
Quit:


GO