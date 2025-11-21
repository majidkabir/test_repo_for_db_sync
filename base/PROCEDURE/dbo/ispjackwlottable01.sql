SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger:  ispJACKWLottable01                                         */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose:  SOS#315958 Get 1st Lottable01 & 03 value based on SKU      */  
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
/* 22-Jul-2014  James     1.0   SOS315958 Created                       */
/* 18-Nov-2014  CSCHONG   1.1   Added Lottables 06-15 (CS01)            */
/************************************************************************/  
                   
CREATE PROCEDURE [dbo].[ispJACKWLottable01]  
   @c_Storerkey        NVARCHAR(15),  
   @c_Sku              NVARCHAR(20),  
   @c_Lottable01Value  NVARCHAR(18),  
   @c_Lottable02Value  NVARCHAR(18),  
   @c_Lottable03Value  NVARCHAR(18),  
   @dt_Lottable04Value datetime,  
   @dt_Lottable05Value datetime,  
   @c_Lottable06Value  NVARCHAR(30),  --(CS01)
   @c_Lottable07Value  NVARCHAR(30),  --(CS01)
   @c_Lottable08Value  NVARCHAR(30),  --(CS01)
   @c_Lottable09Value  NVARCHAR(30),  --(CS01)
   @c_Lottable10Value  NVARCHAR(30),  --(CS01)
   @c_Lottable11Value  NVARCHAR(30),  --(CS01)
   @c_Lottable12Value  NVARCHAR(30),  --(CS01)
   @dt_Lottable13Value datetime,      --(CS01)
   @dt_Lottable14Value datetime,      --(CS01)
   @dt_Lottable15Value datetime,      --(CS01)  
   @c_Lottable01       NVARCHAR(18) OUTPUT,  
   @c_Lottable02       NVARCHAR(18) OUTPUT,  
   @c_Lottable03       NVARCHAR(18) OUTPUT,  
   @dt_Lottable04      datetime OUTPUT,  
   @dt_Lottable05      datetime OUTPUT,  
   @c_Lottable06       NVARCHAR(30) OUTPUT,     --(CS01)
   @c_Lottable07       NVARCHAR(30) OUTPUT,     --(CS01)
   @c_Lottable08       NVARCHAR(30) OUTPUT,     --(CS01)
   @c_Lottable09       NVARCHAR(30) OUTPUT,     --(CS01)
   @c_Lottable10       NVARCHAR(30) OUTPUT,     --(CS01)
   @c_Lottable11       NVARCHAR(30) OUTPUT,     --(CS01) 
   @c_Lottable12       NVARCHAR(30) OUTPUT,     --(CS01)
   @dt_Lottable13      datetime OUTPUT,         --(CS01)
   @dt_Lottable14      datetime OUTPUT,         --(CS01)
   @dt_Lottable15      datetime OUTPUT,         --(CS01)
   @b_Success          int = 1  OUTPUT,  
   @n_Err              int = 0  OUTPUT,  
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,  
   @c_Sourcekey        NVARCHAR(15) = '',    
   @c_Sourcetype       NVARCHAR(20) = '',    
   @c_LottableLabel    NVARCHAR(20) = ''     
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cRD_SKU     NVARCHAR( 20)
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT <> 1
      GOTO Quit

   IF @c_Sourcetype NOT IN ('rdtfnc_PieceReceivin')
      GOTO Quit

   -- If lottable01/03 value already passed in, meaning user pre keyed in then we no need get from receiptdetail
   SELECT TOP 1 @c_Lottable01 = CASE WHEN ISNULL( @c_Lottable01Value, '') <> '' THEN @c_Lottable01Value ELSE Lottable01 END, 
                @c_Lottable03 = CASE WHEN ISNULL( @c_Lottable03Value, '') <> '' THEN @c_Lottable03Value ELSE Lottable03 END 
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = LEFT(@c_SourceKey,10)
   AND   SKU = @c_Sku
   AND   FinalizeFlag <> 'Y'

QUIT:  
  
END -- End Procedure  

GO