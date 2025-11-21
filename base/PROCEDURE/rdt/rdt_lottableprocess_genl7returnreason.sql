SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL7ReturnReason                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS350418 Created                             */
/* 12-Jan-2017  Ung       1.1   WMS-928 Change of return policy               */
/* 15-Mar-2017  Ung       1.2   WMS-1348 Change of return policy              */
/* 14-Feb-2019  James     1.3   WMS-7929 Change policy (james01)              */
/* 15-Mar-2019  YeeKung   1.4   WMS-8317 Change Policy (YeeKung01)            */   
/* 21-Feb-2020  Chermaine 1.5   WMS-11672 Change Policy (cc01)                */      
/* 22-Jun-2020  YeeKung   1.6   WMS-13814 Change Policy (yeekung02)           */ 
/* 18-Sep-2020  YeeKung   1.7   WMS-15226 Change Policy (yeekung03)           */
/* 15-Nov-2021  YeeKung   1.8   WMS-18365 Change Policy (yeekung04)           */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenL7ReturnReason]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nInputKey        INT
   ,@cStorerKey       NVARCHAR( 15)
   ,@cSKU             NVARCHAR( 20)
   ,@cLottableCode    NVARCHAR( 30)
   ,@nLottableNo      INT
   ,@cLottable        NVARCHAR( 30)
   ,@cType            NVARCHAR( 10)
   ,@cSourceKey       NVARCHAR( 15)
   ,@cLottable01Value NVARCHAR( 18)
   ,@cLottable02Value NVARCHAR( 18)
   ,@cLottable03Value NVARCHAR( 18)
   ,@dLottable04Value DATETIME
   ,@dLottable05Value DATETIME
   ,@cLottable06Value NVARCHAR( 30)
   ,@cLottable07Value NVARCHAR( 30)
   ,@cLottable08Value NVARCHAR( 30)
   ,@cLottable09Value NVARCHAR( 30)
   ,@cLottable10Value NVARCHAR( 30)
   ,@cLottable11Value NVARCHAR( 30)
   ,@cLottable12Value NVARCHAR( 30)
   ,@dLottable13Value DATETIME
   ,@dLottable14Value DATETIME
   ,@dLottable15Value DATETIME
   ,@cLottable01      NVARCHAR( 18) OUTPUT
   ,@cLottable02      NVARCHAR( 18) OUTPUT
   ,@cLottable03      NVARCHAR( 18) OUTPUT
   ,@dLottable04      DATETIME      OUTPUT
   ,@dLottable05      DATETIME      OUTPUT
   ,@cLottable06      NVARCHAR( 30) OUTPUT
   ,@cLottable07      NVARCHAR( 30) OUTPUT
   ,@cLottable08      NVARCHAR( 30) OUTPUT
   ,@cLottable09      NVARCHAR( 30) OUTPUT
   ,@cLottable10      NVARCHAR( 30) OUTPUT
   ,@cLottable11      NVARCHAR( 30) OUTPUT
   ,@cLottable12      NVARCHAR( 30) OUTPUT
   ,@dLottable13      DATETIME      OUTPUT
   ,@dLottable14      DATETIME      OUTPUT
   ,@dLottable15      DATETIME      OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @cLottable07Value = ''
   BEGIN
      DECLARE @cBUSR6      NVARCHAR(30) 
      DECLARE @cIVAS       NVARCHAR(30)
      DECLARE @cSKUGroup   NVARCHAR(10)
      DECLARE @cItemClass  NVARCHAR(10)
      DECLARE @cLong       NVARCHAR(250)
      DECLARE @nMonth      INT

      -- Get SKU info
      SELECT 
         @cBUSR6 = BUSR6, 
         @cIVAS = ISNULL( IVAS, ''), 
         @cSKUGroup = SKUGroup, 
         @cItemClass = ItemClass
      FROM SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
         AND SKU = @cSKU

      -- Get codelkup info
      SELECT @cLong = ISNULL( Long, '')
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'ITEMCLASS' 
         AND Code = @cItemClass
         AND StorerKey = @cStorerKey 

      IF @dLottable04 IS NOT NULL AND @dLottable04 <> 0
         SET @nMonth = DATEDIFF( mm, GETDATE(), @dLottable04)

      IF @cBUSR6 >= '80'        --(yeekung03)   
         SET @cLottable07 = 'JR'            
                  
      --ELSE IF @cBUSR6 = '07'            
--   SET @cLottable07 = 'JR'        
           
      IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 17)         
         SET @cLottable07 = ''    

      ELSE IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 16 AND @nMonth >= 2) 
         SET @cLottable07 = 'BR'

      ELSE IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth < 2)
         SET @cLottable07 = 'D1'

      ELSE IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 13) 
         SET @cLottable07 = ''

      ELSE IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 12 AND @nMonth >= 2) 
         SET @cLottable07 = 'BR'

      ELSE IF @cLong = 'LPD' AND @cItemClass='19' AND @cSKUGroup <> 'YFG'  AND (@nMonth IS NOT NULL AND @nMonth < 2)
         SET @cLottable07 = 'D1' 
		 
      --ELSE IF @cLong = 'CPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth > 18) 
      --   SET @cLottable07 = 'LR'

      --ELSE IF @cLong = 'CPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 18 AND @nMonth>2) 
      --   SET @cLottable07 = 'BR'

      --ELSE IF @cLong = 'CPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
      --   SET @cLottable07 = 'D1'

      --ELSE IF @cLong = 'CPD' AND (@nMonth IS NOT NULL AND @nMonth >13) 
      --   SET @cLottable07 = 'BR'

      --ELSE IF @cLong = 'CPD' AND (@nMonth IS NOT NULL AND @nMonth <=13 AND @nMonth>2) 
      --   SET @cLottable07 = 'BR'
      
      --ELSE IF @cLong = 'CPD' AND(@nMonth IS NOT NULL AND @nMonth <= 2)  
         --SET @cLottable07 = 'D1'    --(cc01)

      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 15) --(yeekung04) 
         SET @cLottable07 = ''

      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 14 AND @nMonth >= 3)   --(yeekung02)    
         SET @cLottable07 = 'BR'      
      
      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 2)  --(yeekung02)    
         SET @cLottable07 = 'D1'   

      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG'  AND (@nMonth IS NOT NULL AND @nMonth >= 7) --(yeekung04) 
         SET @cLottable07 = ''

      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG'  AND (@nMonth IS NOT NULL AND @nMonth <= 6 AND @nMonth >= 3) --(yeekung04)
         SET @cLottable07 = 'BR'

      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG'  AND (@nMonth IS NOT NULL AND @nMonth <= 2)
         SET @cLottable07 = 'D1'

       --(cc01)
      --ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth > 18) 
      --   SET @cLottable07 = ''

      --ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 18 AND @nMonth>2) 
      --   SET @cLottable07 = 'BR'

      --ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
      --   SET @cLottable07 = 'D1'

      --ELSE IF @cLong = 'ACD' AND (@nMonth IS NOT NULL AND @nMonth >13) 
      --   SET @cLottable07 = ''

      --ELSE IF @cLong = 'ACD' AND (@nMonth IS NOT NULL AND @nMonth <= 13 AND @nMonth>2) 
      --   SET @cLottable07 = 'BR'

      --ELSE IF @cLong = 'ACD' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
      --   SET @cLottable07 = 'D1'
      
      --ELSE IF @cLong = 'PPD' AND (@nMonth IS NOT NULL AND @nMonth > 6)
      --   SET @cLottable07 = ''
		 
      --ELSE IF  @cLong='PPD' AND (@nMonth IS NOT NULL AND @nMonth <= 6 AND @nMonth>2) 
	     --SET @cLottable07='BR'
		 
      --ELSE IF @cLong = 'PPD' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
      --   SET @cLottable07 = 'D1'

      IF @cLong = 'LPD' AND @cLottable06 IN ('Q', 'B') AND @cLottable07 = ''
      BEGIN
         SET @nErrNo = 56801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Reason
      END
   END
END
SET QUOTED_IDENTIFIER OFF

GO