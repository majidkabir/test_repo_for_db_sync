SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc    : isp_PcsRcpt_GetDefaultLottables                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get Default Lottables Location                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author  Rev   Purposes                                  */
/* 26-Sep-2013  Shong   1.0   Created                                   */
/* 30-May-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/


CREATE PROC [dbo].[isp_PcsRcpt_GetDefaultLottables] (
   @c_ReceiptKey     NVARCHAR(10) = '', 
   @c_POKey          NVARCHAR(10) = '', 
   @c_ToID           NVARCHAR(18) = '',
   @c_StorerKey      NVARCHAR(15) = '',
   @c_SKU            NVARCHAR(20) = '',
   @c_Lottable01     NVARCHAR(18) = ''    OUTPUT,
   @c_Lottable02     NVARCHAR(18) = ''    OUTPUT,
   @c_Lottable03     NVARCHAR(18) = ''    OUTPUT,
   @d_Lottable04     DATETIME             OUTPUT,
   @d_Lottable05     DATETIME             OUTPUT,
   @c_Lottable06     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable07     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable08     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable09     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable10     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable11     NVARCHAR(30) = ''    OUTPUT,
   @c_Lottable12     NVARCHAR(30) = ''    OUTPUT,
   @d_Lottable13     DATETIME     = NULL  OUTPUT,
   @d_Lottable14     DATETIME     = NULL  OUTPUT,
   @d_Lottable15     DATETIME     = NULL  OUTPUT,
   @b_Success        INT = 1              OUTPUT,
   @n_Err            INT = 1              OUTPUT,
   @c_ErrMsg         NVARCHAR(215) = ''   OUTPUT
)   
AS 
BEGIN
   DECLARE 
       @c_Facility         NVARCHAR(10)
      ,@c_Authority        NVARCHAR(1)
      ,@c_ListName         NVARCHAR(10)
      ,@n_Count            INT
      ,@c_Short            NVARCHAR(10)
      ,@c_StoredProd       NVARCHAR(250)
      ,@c_LottableLabel    NVARCHAR(60)

      SELECT @c_Facility = Facility,
             @c_StorerKey = @c_StorerKey
      FROM RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @c_ReceiptKey
               
      -- Retrieve Lottables on ToID
      SET @c_Lottable01 = ''
      SET @c_Lottable02 = ''
      SET @c_Lottable03 = ''
      SET @d_Lottable04 = NULL

      EXEC nspGetRight
         @c_Facility = Facility,
         @c_StorerKey = @c_StorerKey,
         @c_sku = '',
         @c_ConfigKey = 'ReceiveByPieceDefLottableByID',
         @b_Success = @b_Success OUTPUT,
         @c_authority = @c_Authority OUTPUT,
         @n_err = @n_Err OUTPUT,
         @c_errmsg = @c_ErrMsg OUTPUT
          
      IF @b_Success = 1 AND @c_Authority = '1' AND ISNULL(RTRIM(@c_ToID),'') <> '' 
      BEGIN
         SELECT TOP 1
            @c_Lottable01 = Lottable01,
            @c_Lottable02 = Lottable02,
            @c_Lottable03 = Lottable03,
            @d_Lottable04 = Lottable04,
            @c_Lottable06 = Lottable06,
            @c_Lottable07 = Lottable07,
            @c_Lottable08 = Lottable08,
            @c_Lottable09 = Lottable09,
            @c_Lottable10 = Lottable10,
            @c_Lottable11 = Lottable11,
            @c_Lottable12 = Lottable12,
            @d_Lottable13 = Lottable13,
            @d_Lottable14 = Lottable14,
            @d_Lottable15 = Lottable15
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @c_ReceiptKey
            AND POKey = CASE WHEN @c_POKey = '' OR @c_POKey = 'NOPO' THEN POKey ELSE @c_POKey END
            AND ToID = @c_ToID
         ORDER BY ReceiptLineNumber
      END

      -- Retrieve pre Lottable values
      SET @n_Count = 1
      WHILE @n_Count <= 4
      BEGIN
         IF @n_Count =  1 SET @c_ListName = 'Lottable01'
         IF @n_Count =  2 SET @c_ListName = 'Lottable02'
         IF @n_Count =  3 SET @c_ListName = 'Lottable03'
         IF @n_Count =  4 SET @c_ListName = 'Lottable04'
         IF @n_Count =  6 SET @c_ListName = 'Lottable06'
         IF @n_Count =  7 SET @c_ListName = 'Lottable07'
         IF @n_Count =  8 SET @c_ListName = 'Lottable08'
         IF @n_Count =  9 SET @c_ListName = 'Lottable09'
         IF @n_Count = 10 SET @c_ListName = 'Lottable10'
         IF @n_Count = 11 SET @c_ListName = 'Lottable11'
         IF @n_Count = 12 SET @c_ListName = 'Lottable12'
         IF @n_Count = 13 SET @c_ListName = 'Lottable13'
         IF @n_Count = 14 SET @c_ListName = 'Lottable14'
         IF @n_Count = 15 SET @c_ListName = 'Lottable15'

         SET @c_Short = ''
         SET @c_StoredProd = ''
         SET @c_LottableLabel = ''

         -- Get PRE store procedure
         SELECT
            @c_Short = C.Short,
            @c_StoredProd = IsNULL( C.Long, ''),
            @c_LottableLabel = S.SValue
         FROM dbo.CodeLkUp C WITH (NOLOCK)
            JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey
         WHERE C.ListName = @c_ListName
            AND C.Code = S.SValue
            AND S.Storerkey = @c_StorerKey -- NOTE: storer level

         -- Execute PRE store procedure
         IF @c_Short = 'PRE' AND @c_StoredProd <> ''
         BEGIN
            EXEC dbo.ispLottableRule_Wrapper
               @c_SPName           = @c_StoredProd,
               @c_ListName          = @c_ListName,
               @c_Storerkey         = @c_StorerKey,
               @c_Sku               = @c_SKU,
               @c_LottableLabel     = @c_LottableLabel,
               @c_Lottable01Value   = '',
               @c_Lottable02Value   = '',
               @c_Lottable03Value   = '',
               @dt_Lottable04Value  = '',
               @dt_Lottable05Value  = '',
               @c_Lottable06Value   = '',
               @c_Lottable07Value   = '',
               @c_Lottable08Value   = '',
               @c_Lottable09Value   = '',
               @c_Lottable10Value   = '',
               @c_Lottable11Value   = '',
               @c_Lottable12Value   = '',
               @dt_Lottable13Value  = '',
               @dt_Lottable14Value  = '',
               @dt_Lottable15Value  = '',
               @c_Lottable01        = @c_Lottable01 OUTPUT,
               @c_Lottable02        = @c_Lottable02 OUTPUT,
               @c_Lottable03        = @c_Lottable03 OUTPUT,
               @dt_Lottable04       = @d_Lottable04 OUTPUT,
               @dt_Lottable05       = @d_Lottable05 OUTPUT,
               @c_Lottable06        = @c_Lottable06 OUTPUT,
               @c_Lottable07        = @c_Lottable07 OUTPUT,
               @c_Lottable08        = @c_Lottable08 OUTPUT,
               @c_Lottable09        = @c_Lottable09 OUTPUT,
               @c_Lottable10        = @c_Lottable10 OUTPUT,
               @c_Lottable11        = @c_Lottable11 OUTPUT,
               @c_Lottable12        = @c_Lottable12 OUTPUT,
               @dt_Lottable13       = @d_Lottable13 OUTPUT,
               @dt_Lottable14       = @d_Lottable14 OUTPUT,
               @dt_Lottable15       = @d_Lottable15 OUTPUT,
               @b_Success           = @b_Success    OUTPUT,
               @n_Err               = @n_Err        OUTPUT,
               @c_Errmsg            = @c_ErrMsg     OUTPUT,
               @c_Sourcekey         = @c_Receiptkey,
               @c_Sourcetype        = 'WS_PieceReceiving' -- NVARCHAR(20) only

               IF ISNULL(@c_ErrMsg, '') <> ''
               BEGIN
                  SET @c_ErrMsg = @c_ErrMsg 
                  SET @b_Success = 0 
                  BREAK
               END
         END
         SET @n_Count = @n_Count + 1
      END -- WHILE @n_Count <= 4

      -- Prep next screen var
      SET @c_Lottable01 = IsNULL( @c_Lottable01, '')
      SET @c_Lottable02 = IsNULL( @c_Lottable02, '')
      SET @c_Lottable03 = IsNULL( @c_Lottable03, '')
      SET @c_Lottable06 = IsNULL( @c_Lottable06, '')
      SET @c_Lottable07 = IsNULL( @c_Lottable07, '')
      SET @c_Lottable08 = IsNULL( @c_Lottable08, '')
      SET @c_Lottable09 = IsNULL( @c_Lottable09, '')
      SET @c_Lottable10 = IsNULL( @c_Lottable10, '')
      SET @c_Lottable11 = IsNULL( @c_Lottable11, '')
      SET @c_Lottable12 = IsNULL( @c_Lottable12, '')

END -- End Procedure 


GO