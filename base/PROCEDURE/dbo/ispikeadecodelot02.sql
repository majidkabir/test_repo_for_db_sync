SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispIkeaDecodeLot02                                  */  
/* Copyright: IDS                                                       */  
/* Purpose: Decode lottable02 (remove 1st 2 chars)                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2018-08-09   James     1.0   WMS5313-Created                         */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispIkeaDecodeLot02]  
   @c_Storerkey        NVARCHAR(15),  
   @c_Sku              NVARCHAR(20),  
   @c_Lottable01Value  NVARCHAR(60),  
   @c_Lottable02Value  NVARCHAR(60),  
   @c_Lottable03Value  NVARCHAR(60),  
   @dt_Lottable04Value datetime,  
   @dt_Lottable05Value datetime,  
   @c_Lottable01       NVARCHAR(18) OUTPUT,  
   @c_Lottable02       NVARCHAR(18) OUTPUT,  
   @c_Lottable03       NVARCHAR(18) OUTPUT,  
   @dt_Lottable04      datetime OUTPUT,  
   @dt_Lottable05      datetime OUTPUT,  
   @b_Success          int = 1  OUTPUT,  
   @n_ErrNo            int = 0  OUTPUT,  
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,  
   @c_Sourcekey        NVARCHAR(15) = '',    
   @c_Sourcetype       NVARCHAR(20) = '',    
   @c_LottableLabel    NVARCHAR(20) = ''     
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   SET @c_Lottable02 = SUBSTRING( RTRIM( @c_Lottable02Value), 3, 18)
     
END  

GO