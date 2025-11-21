SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispGenlottable02pre01                                      */
/* Creation Date: 25-Nov-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#294725:TW - FAL Populate 77-Code to Receiptdetail      */
/*           Lottable02. Generate Receiptdetail Lottable02 From SKU     */ 
/*           BUSR6                                                      */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 21-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenlottable02pre01]
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
   , @n_Err                int            = 0      OUTPUT
   , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT
   , @c_Sourcekey          NVARCHAR(15)   = ''  
   , @c_Sourcetype         NVARCHAR(20)   = ''   
   , @c_LottableLabel      NVARCHAR(20)   = ''    

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT
         , @b_debug        INT

         , @c_Busr6        NVARCHAR(30)

   SET @n_continue   = 1
   SET @b_debug      = 0
   SET @b_success    = 1
   SET @n_Err        = 0

   SET @c_Lottable02 = ''
   SET @c_Busr6      = ''

   IF @c_Sourcetype NOT IN ( 'TRADERETURN' , 'RECEIPTFINALIZE' )
   BEGIN
      GOTO QUIT
   END

   IF EXISTS (SELECT 1
              FROM RECEIPT WITH (NOLOCK)
              WHERE Receiptkey = SUBSTRING(@c_Sourcekey,1,10) 
              AND DocType <> 'R')
   BEGIN
      GOTO QUIT
   END

   IF NOT EXISTS (SELECT 1 
                  FROM  CODELKUP (NOLOCK)
                  WHERE LISTNAME = 'LOTTABLE02'
                  AND   CODE = @c_LottableLabel
                  AND   Storerkey = @c_Storerkey)
   BEGIN
      GOTO QUIT
   END

   SELECT @c_Busr6 = ISNULL(RTRIM(SKU.BUSR6),'')
   FROM SKU WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Sku       = @c_Sku

   SET @c_Lottable02 = @c_Busr6

QUIT:

END -- End Procedure

GO