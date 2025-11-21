SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGenDefaultLot3                                  */
/* Creation Date: 19-July-2010                                          */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: Get Lottable03 from Codelkup                                */
/*                                                                      */
/* Called By: RDT Lottable_Wrapper                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 2010-01-14   ChewKP    SOS#200717 Changes to cater to different      */
/*                        Storer (ChewKP01)                             */
/* 2012-04-17   SPChin    SOS241329 - Change to get default value when  */
/*                                    Lottable03 is blank               */
/* 2013-09-11   ChewKP    SOS#289137 - Default Lot3 for TBLTW (ChewKP02)*/
/* 2013-12-03   ChewKP    SOS#296907 - PreLottable of TBLTW (ChewKP03)  */
/* 2014-05-21   TKLIM     Added Lottables 06-15                         */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenDefaultLot3]
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

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT,
           @b_debug        INT,
           @c_ReceiptKey   NVARCHAR(10), -- (ChewKP01)
           @c_ReceiptLineNo NVARCHAR(5)  -- (ChewKP01)



--   SELECT @c_Lottable03 = Long From dbo.CodeLKUP (NOLOCK)
--   WHERE LISTNAME = 'DLOTTABLE'
--   AND CODE = 'LOTTABLE03'
--   AND Short = @c_Storerkey

   IF @c_StorerKey <> 'TBLTW' -- (ChewKP02)
   BEGIN
      -- (ChewKP01)
      IF ISNULL(@c_Lottable03Value,'') = '' --SOS241329
      BEGIN
         SELECT @c_Lottable03 = Long From dbo.CodeLKUP (NOLOCK)
         WHERE LISTNAME = 'DLOTTABLE3'
         AND CODE = @c_Storerkey
         AND Short = 'Lottable03'
      END
   END
   ELSE
   BEGIN  
      -- (ChewKP02) 
      SET @c_ReceiptKey    = LEFT(@c_SourceKey,10) 
      SET @c_ReceiptLineNo = RIGHT(@c_SourceKey,5) 
      
      SELECT TOP 1 
              @c_Lottable02= ISNULL(Lottable02,'')  
            , @c_Lottable03 = ISNULL(Lottable03,'')  
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE StorerKey      = @c_Storerkey
            AND ReceiptKey = @c_ReceiptKey
            --AND SKU        = @c_Sku -- (ChewKP03)  
 
            
   END
   
END -- End Procedure


GO