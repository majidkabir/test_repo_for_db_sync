SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGenLot2_TH02                                             */
/* Creation Date: 31-Jan-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable02                          */
/*           By running# when finalize ASN (SOS#269879)                 */
/*                                                                      */
/* Called By: ispFinalizeReceipt                                        */
/*            storerconfig: ASNFinalizeLottableRules                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 21-May-2014  TKLIM    1.1  Added Lottables 06-15                     */
/* 14-Jan-2015  CSCHONG  1.2  Add new input parameter (CS01)            */
/* 01-Sep-2015  YTWan    1.3  SOS#351413 - TH-MJN enhance auto generate */
/*                            SAP Batch No (Wan01)                      */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot2_TH02]
     @c_Storerkey          NVARCHAR(15)
   , @c_Sku                NVARCHAR(20)
   , @c_Lottable01Value    NVARCHAR(18)
   , @c_Lottable02Value    NVARCHAR(18)
   , @c_Lottable03Value    NVARCHAR(18)
   , @dt_Lottable04Value   DATETIME
   , @dt_Lottable05Value   DATETIME
   , @c_Lottable06Value    NVARCHAR(30)   = ''
   , @c_Lottable07Value    NVARCHAR(30)   = ''
   , @c_Lottable08Value    NVARCHAR(30)   = ''
   , @c_Lottable09Value    NVARCHAR(30)   = ''
   , @c_Lottable10Value    NVARCHAR(30)   = ''
   , @c_Lottable11Value    NVARCHAR(30)   = ''
   , @c_Lottable12Value    NVARCHAR(30)   = ''
   , @dt_Lottable13Value   DATETIME       = NULL
   , @dt_Lottable14Value   DATETIME       = NULL
   , @dt_Lottable15Value   DATETIME       = NULL
   , @c_Lottable01         NVARCHAR(18)            OUTPUT
   , @c_Lottable02         NVARCHAR(18)            OUTPUT
   , @c_Lottable03         NVARCHAR(18)            OUTPUT
   , @dt_Lottable04        DATETIME                OUTPUT
   , @dt_Lottable05        DATETIME                OUTPUT
   , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT
   , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT
   , @dt_Lottable13        DATETIME       = NULL   OUTPUT
   , @dt_Lottable14        DATETIME       = NULL   OUTPUT
   , @dt_Lottable15        DATETIME       = NULL   OUTPUT
   , @b_Success            int            = 1      OUTPUT
   , @n_ErrNo              int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''  
   , @c_Sourcetype         NVARCHAR(20)   = ''   
   , @c_LottableLabel      NVARCHAR(20)   = '' 
   , @c_type               NVARCHAR(10)   = ''     --(CS01)

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Lottable01Label   NVARCHAR(20),
           @c_Lottable02Label   NVARCHAR(20),
           @c_Lottable03Label   NVARCHAR(20),  
           @c_Lottable04Label   NVARCHAR(20),  
           @c_RECType           NVARCHAR(10),
           @c_CarrierKey        NVARCHAR(15),
           @c_Lottable02_Seq    NVARCHAR(5),
           @c_Lottable02_Find   NVARCHAR(18),
           @c_POGroup           NVARCHAR(20),
           @dt_Lottable05_Find  DATETIME

   DECLARE @n_continue     INT,
           @b_debug        INT
           
   SELECT @n_continue = 1, @b_success = 1, @n_ErrNo = 0, @b_debug = 0

   SELECT @c_Lottable01  = '',
          @c_Lottable02  = '',
          @c_Lottable03  = '',
          @dt_Lottable04 = NULL,
          @dt_Lottable05 = NULL

   IF @c_Sourcetype = 'RECEIPTFINALIZE' 
   BEGIN
      SELECT @c_RECType = R.RECType, @c_CarrierKey = R.CarrierKey, @c_POGroup = PO.POGroup     
      FROM RECEIPT R (NOLOCK) 
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
      JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
      LEFT JOIN PO (NOLOCK) ON RD.POKey = PO.POKey
      WHERE RD.Receiptkey = LEFT(@c_Sourcekey,10)
      AND RD.ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)
      AND R.RECType = 'NORMAL'
      AND SKU.Busr3 IN('RAW','PAC','HAL')

      IF ISNULL(@c_RECType,'') <> 'NORMAL'
         GOTO QUIT
   END
   ELSE
   BEGIN
      GOTO QUIT
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),''),
             @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),''),
             @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),''),  
             @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),'')   
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   SKU = @c_Sku

      IF @c_LottableLabel NOT IN( @c_Lottable02Label, @c_Lottable03Label )
         GOTO QUIT

      IF @c_Lottable01Label = 'STOCKTYPE' AND @c_Lottable02Label = 'SAPBATCH'
         AND @c_Lottable03Label = 'VENDORBATCH' AND @c_Lottable04Label = 'EXP_DATE'  
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE
      BEGIN
         SET @n_continue = 3
         --SET @b_Success = 0

         IF @c_Lottable01Label <> 'STOCKTYPE'
         BEGIN
            SET @n_ErrNo = 31326
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable01Label Setup.  (ispGenLot2_TH02)'
         END
         ELSE IF @c_Lottable02Label <> 'SAPBATCH'
         BEGIN
            SET @n_ErrNo = 31327
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable02Label Setup.  (ispGenLot2_TH02)'
         END
         ELSE IF @c_Lottable03Label <> 'VENDORBATCH' 
         BEGIN
            SET @n_ErrNo = 31328
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable03Label Setup.  (ispGenLot2_TH02)'
         END
         ELSE IF @c_Lottable04Label <> 'EXP_DATE'  
         BEGIN
            SET @n_ErrNo = 31329
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispGenLot2_TH02)'
         END
         GOTO QUIT
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @dt_Lottable05Value IS NULL OR YEAR(@dt_Lottable05Value) IN(1900,2000)
      BEGIN
          SELECT @dt_Lottable05_Find = GETDATE() 
      END
      ELSE
      BEGIN
           SELECT @dt_Lottable05_Find = @dt_Lottable05Value 
      END
      
      SELECT @c_Lottable02_Find  = Lottable02
      FROM RECEIPTDETAIL(NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND Sku = @c_Sku
      AND RTRIM(receiptkey)+ReceiptLineNumber <> @c_Sourcekey
      AND Lottable03 = @c_Lottable03Value 
      AND DATEDIFF(Day, Lottable05, @dt_Lottable05_Find) = 0
      AND LEFT(Lottable02,2) = 'LF'
      --(Wan01) - START
      AND EXISTS (SELECT 1
                  FROM RECEIPT WITH (NOLOCK)
                  WHERE RECEIPT.ReceiptKey = RECEIPTDETAIL.Receiptkey
                  AND RECType <> 'GRN')
      --(Wan01) - END
      
      IF ISNULL(@c_Lottable02_Find,'') = '' 
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_getkey
               'MJNSAPBATCH'
               , 5
               , @c_Lottable02_Seq OUTPUT
               , @b_Success OUTPUT
               , @n_ErrNo OUTPUT
               , @c_Errmsg OUTPUT        

         IF @b_success = 1
         BEGIN         
            IF @c_POGroup = 'K'
               SET @c_Lottable02 = 'LF' + RTRIM(@c_Lottable02_Seq) + '/' + RTRIM(LTRIM(ISNULL(@c_CarrierKey,'')))
            ELSE
               SET @c_Lottable02 = 'LF' + RTRIM(@c_Lottable02_Seq) 
         END
      END      
      ELSE
      BEGIN
         SET @c_Lottable02 = @c_Lottable02_Find
      END
   END

QUIT:
END -- End Procedure

GO