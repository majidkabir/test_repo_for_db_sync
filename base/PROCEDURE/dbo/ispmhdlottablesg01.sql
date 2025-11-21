SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Trigger:  ispMHDLottableSG01                                         */  
/* Creation Date: 11-Sep-2013                                           */  
/* Copyright: IDS                                                       */  
/*                                                                      */  
/* Purpose:  SOS#308816 Get Lottable01 based on lottable03 value        */  
/*           Blank out lottable02                                       */
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
/* 04-Jun-2014  James     1.1   Bug fix. SELECT TOP 1 record (james01)  */
/* 09-Jun-2014  James     1.2   Always default cursor @ lot01 (james02) */
/************************************************************************/  
                   
CREATE PROCEDURE [dbo].[ispMHDLottableSG01]  
   @c_Storerkey        NVARCHAR(15),  
   @c_Sku              NVARCHAR(20),  
   @c_Lottable01Value  NVARCHAR(18),  
   @c_Lottable02Value  NVARCHAR(18),  
   @c_Lottable03Value  NVARCHAR(18),  
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

   DECLARE @c_ReceiptKey      NVARCHAR( 10), 
           @c_TempLottable03  NVARCHAR( 18), 
           @nMobile           INT 

   SELECT @nMobile  = Mobile FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = sUser_sName()

   SET @c_Lottable01 = ''
   SET @c_Lottable02 = ''
   SET @c_ReceiptKey    = LEFT(@c_SourceKey,10)   
   SELECT @c_TempLottable03 = V_ID FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUser_sName()

   -- (james01) 
   SELECT TOP 1 @c_Lottable01 = Lottable01, @c_Lottable02 = Lottable02 
   FROM dbo.ReceiptDetail WITH (NOLOCK) 
   WHERE ReceiptKey = @c_ReceiptKey
   AND   Lottable03 = @c_TempLottable03
   AND   SKU = @c_Sku
   AND   FinalizeFlag = 'N'
   GROUP BY Lottable01, Lottable02, Receiptlinenumber
   ORDER BY CASE WHEN SUM(QtyExpected) - SUM(BeforeReceivedQty) > 0 
                 THEN SUM(QtyExpected) - SUM(BeforeReceivedQty) ELSE 999999999 END, Receiptlinenumber 

   SET @c_Lottable03 = @c_TempLottable03

   EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01   (james02)
   
QUIT:  
  
END -- End Procedure  

GO