SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispVFCNPostL02                                      */
/* Copyright: IDS                                                       */
/* Purpose: Default Lottable03 from ReceiptDetail                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-02   Ung       1.0   Created                                 */
/* 02-Jun-2014  TKLIM     1.1   Added Lottables 06-15                   */
/* 27-Feb-2017  TLTING    1.2   variable Nvarchar                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispVFCNPostL02]
   @c_Storerkey         NVARCHAR(15),
   @c_Sku               NVARCHAR(20),
   @c_Lottable01Value   NVARCHAR(18), 
   @c_Lottable02Value   NVARCHAR(18),
   @c_Lottable03Value   NVARCHAR(18),
   @dt_Lottable04Value  DATETIME,
   @dt_Lottable05Value  DATETIME,
   @c_Lottable01        NVARCHAR(18)                OUTPUT,
   @c_Lottable02        NVARCHAR(18)                OUTPUT,
   @c_Lottable03        NVARCHAR(18)                OUTPUT,
   @dt_Lottable04       DATETIME                OUTPUT,
   @dt_Lottable05       DATETIME                OUTPUT,
   @c_Lottable06        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable07        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable08        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable09        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable10        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable11        NVARCHAR(30)   = ''     OUTPUT, 
   @c_Lottable12        NVARCHAR(30)   = ''     OUTPUT, 
   @dt_Lottable13       DATETIME       = NULL   OUTPUT, 
   @dt_Lottable14       DATETIME       = NULL   OUTPUT, 
   @dt_Lottable15       DATETIME       = NULL   OUTPUT, 
   @b_Success           int            = 1      OUTPUT,
   @n_ErrNo             int            = 0      OUTPUT,
   @c_Errmsg            NVARCHAR(250)      = ''     OUTPUT,
   @c_Sourcekey         NVARCHAR(15)       = '',  
   @c_Sourcetype        NVARCHAR(20)       = '',  
   @c_LottableLabel     NVARCHAR(20)       = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @c_Lottable01Value <> ''
   BEGIN
      SET @b_Success = 0
      SET @n_ErrNo  = 83851
      SET @c_Errmsg = '83851^INVALID L01'
   END
END

GO