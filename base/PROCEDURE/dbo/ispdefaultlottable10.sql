SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: ispDefaultLottable10                                */  
/* Creation Date: 14-Mar-2015                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: SOS#333117 - Project Merlion_Default_Lottable10             */  
/* Called By: of_lottable_default_roles                                 */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[ispDefaultLottable10]  
     @c_Storerkey        NVARCHAR(15)  
   , @c_Sku              NVARCHAR(20)  
   , @c_Lottable01Value  NVARCHAR(18)  
   , @c_Lottable02Value  NVARCHAR(18)  
   , @c_Lottable03Value  NVARCHAR(18)  
   , @dt_Lottable04Value DATETIME  
   , @dt_Lottable05Value DATETIME  
   , @c_Lottable06Value  NVARCHAR(30)  
   , @c_Lottable07Value  NVARCHAR(30)  
   , @c_Lottable08Value  NVARCHAR(30)  
   , @c_Lottable09Value  NVARCHAR(30)  
   , @c_Lottable10Value  NVARCHAR(30)  
   , @c_Lottable11Value  NVARCHAR(30)  
   , @c_Lottable12Value  NVARCHAR(30)  
   , @dt_Lottable13Value DATETIME  
   , @dt_Lottable14Value DATETIME                                   
   , @dt_Lottable15Value DATETIME                                 
   , @c_Lottable01       NVARCHAR(18)  OUTPUT                                    
   , @c_Lottable02       NVARCHAR(18)  OUTPUT                                  
   , @c_Lottable03       NVARCHAR(18)  OUTPUT        
   , @dt_Lottable04      DATETIME      OUTPUT       
   , @dt_Lottable05      DATETIME      OUTPUT       
   , @c_Lottable06       NVARCHAR(30)  OUTPUT       
   , @c_Lottable07       NVARCHAR(30)  OUTPUT       
   , @c_Lottable08       NVARCHAR(30)  OUTPUT       
   , @c_Lottable09       NVARCHAR(30)  OUTPUT       
   , @c_Lottable10       NVARCHAR(30)  OUTPUT       
   , @c_Lottable11       NVARCHAR(30)  OUTPUT       
   , @c_Lottable12       NVARCHAR(30)  OUTPUT       
   , @dt_Lottable13      DATETIME      OUTPUT       
   , @dt_Lottable14      DATETIME      OUTPUT       
   , @dt_Lottable15      DATETIME      OUTPUT       
   , @b_Success          INT = 1       OUTPUT           
   , @n_Err              INT = 0       OUTPUT       
   , @c_Errmsg           NVARCHAR(250) = '' OUTPUT  
   , @c_Sourcekey        NVARCHAR(15)  = ''  
   , @c_Sourcetype       NVARCHAR(20)  = ''  
   , @c_LottableLabel    NVARCHAR(20)  = ''  
   , @c_Type             NVARCHAR(10)  = ''  
  
AS  
  
BEGIN  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_IsRDT INT  
   EXECUTE RDT.rdtIsRDT @n_IsRDT   
  
  
  
   -- RDT checking  
  
   IF @n_IsRDT = 1  
   BEGIN  
  
      -- Get mobile info  
  
      DECLARE @cLangCode NVARCHAR(3)  
      SELECT @cLangCode = Lang_Code FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()  
   END  
  
   IF @c_Sourcetype NOT IN ('RECEIPT', 'TRADERETURN', 'TRANSFER', 'PO') -- (Wan01) Add PO  
   BEGIN  
      GOTO Quit  
   END  
  
  
   IF ISNULL(RTRIM(@c_Lottable10Value),'') = ''  
  
   BEGIN  
  
      SELECT TOP 1 @c_Lottable10 = RTRIM(SKU.IVAS)  
      FROM SKU  WITH (NOLOCK)  
      WHERE SKU.Storerkey= @c_Storerkey  
      AND   SKU.SKU = @c_sku  
  
   END  
  
Quit:  
  
END  

GO