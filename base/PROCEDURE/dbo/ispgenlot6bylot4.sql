SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispGenLot6bylot4                                            */
/* Creation Date: 326-Feb-2016                                          */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  Generate Receiptdetail Lottable06                          */
/*            when finalize ASN (SOS#364463)                            */
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
/* 25-Apr-2016  CSCHONG  1.0  fix adjustmant and transfer by line (CS01)*/
/* 20-Jun-2017  Ung      1.1  WMS-2232 RDT compatible                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenLot6bylot4]
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
           @c_DOCType           NVARCHAR(1),
           @dt_lottable04_Find   Datetime,
           @c_susr2             NVARCHAR(18)

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
      SELECT @c_DOCType = R.DOCType    
      FROM RECEIPT R (NOLOCK) 
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
      JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
     -- LEFT JOIN PO (NOLOCK) ON RD.POKey = PO.POKey
      WHERE RD.Receiptkey = LEFT(@c_Sourcekey,10)
      AND RD.ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)

      IF ISNULL(@c_DOCType,'') NOT IN ('A','R')
        GOTO QUIT
   END


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),''),
             @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),''),
             @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),''),  
             @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),''),
             @c_susr2           = ISNULL(RTRIM(Susr2),'')  
      FROM SKU (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND Sku = @c_Sku 
    

      IF @c_LottableLabel NOT IN(@c_Lottable04Label)
         GOTO QUIT

      IF @c_Lottable04Label = 'EXP-DATE'  
      BEGIN
         SELECT @n_continue = 1
      END
      ELSE
      BEGIN
         SET @n_continue = 3
        

         IF @c_Lottable04Label <> 'EXP-DATE'  
         BEGIN
            SET @n_ErrNo = 31329
            SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_ErrNo) + ' Invalid Lottable04Label Setup.  (ispGenLot6bylot4)'
         END
         GOTO QUIT
      END
   END
    
    IF @n_continue = 1 OR @n_continue = 2

    BEGIN  
      IF @c_Sourcetype = '598' -- Container receive
         SET @dt_lottable04_Find  = @dt_Lottable04Value
         
      ELSE IF @c_Sourcetype in ('RECEIPT','RECEIPTFINALIZE','TRADERETURN','XDOCK')
      BEGIN
          
         SELECT @dt_lottable04_Find  = Lottable04
         FROM RECEIPTDETAIL RD WITH (NOLOCK)
         WHERE RD.Receiptkey = LEFT(@c_Sourcekey,10)
         AND RD.ReceiptLineNumber = SUBSTRING(@c_Sourcekey,11,5)
      END
      ELSE IF @c_Sourcetype in ('TRANSFER','TRANSFERFINALIZE')
      BEGIN
        
        SELECT @dt_lottable04_Find  = toLottable04
        FROM TRANSFERDETAIL TD WITH (NOLOCK)
        WHERE TD.Transferkey = LEFT(@c_Sourcekey,10)
        AND TD.TransferLineNumber = SUBSTRING(@c_Sourcekey,11,5)    --(CS01)
      END
      ELSE IF @c_Sourcetype IN ('ADJ','ADJFINALIZE')
      BEGIN
        SELECT @dt_lottable04_Find  = Lottable04
        FROM ADJUSTMENTDETAIL AD WITH (NOLOCK)
        WHERE AD.Adjustmentkey = LEFT(@c_Sourcekey,10)
        AND AD.AdjustmentLineNumber = SUBSTRING(@c_Sourcekey,11,5)    --(CS01)

       
      END

        SET @c_Lottable06 = convert(nvarchar(10),(@dt_lottable04_Find - CAST(@c_susr2 as int)) ,111)

    END    
QUIT:
END -- End Procedure

GO