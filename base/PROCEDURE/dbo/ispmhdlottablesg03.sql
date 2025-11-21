SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger:  ispMHDLottableSG03                                         */  
/* Creation Date: 11-Sep-2013                                           */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose:  SOS#308816 Decode based on lottable03 value                */  
/*           Get Right(Lot03, 18)                                       */
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
/* 22-Apr-2014  James     1.0   SOS308816 James Created                 */
/* 25-Jun-2014  James     1.1   Extend Lottable01-03 length to 60 chars */
/************************************************************************/  
                   
CREATE PROCEDURE [dbo].[ispMHDLottableSG03]  
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

   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   IF @n_IsRDT <> 1
      GOTO Quit

   IF @c_Sourcetype NOT IN ('RDTRECEIPT', 'RECEIPTRET')
      GOTO Quit

   IF ISNULL( @c_Lottable03Value, '') = '' 
      GOTO Quit

   IF LEN( RTRIM( @c_Lottable03Value)) < 18  
      SET @c_Lottable03 = RTRIM( @c_Lottable03Value)
   ELSE
      SET @c_Lottable03 = RIGHT( @c_Lottable03Value, 18)
      
QUIT:  
  
END -- End Procedure  

GO