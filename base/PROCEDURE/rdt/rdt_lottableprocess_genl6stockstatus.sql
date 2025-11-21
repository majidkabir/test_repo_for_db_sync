SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableProcess_GenL6StockStatus                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Dynamic lottable                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 14-Sep-2015  Ung       1.0   SOS350418 Created                             */
/* 12-Jan-2017  Ung       1.1   WMS-928 Change of return policy               */
/* 15-Mar-2017  Ung       1.2   WMS-1348 Change of return policy              */
/* 12-Feb-2019  James     1.3   WMS-7929 Change policy (james01)              */
/* 15-Mar-2019  YeeKung   1.4   WMS-8317 Change Policy (YeeKung01)            */  
/* 21-Aug-2019  Ung       1.5   WMS-10277 Change Policy                       */
/* 14-Jan-2020  Chermaine 1.6   WMS-11672 Change Policy (cc01)                */
/* 22-Jun-2020  YeeKung   1.7   WMS-13814 Change Policy (yeekung02)           */  
/* 18-Sep-2020  YeeKung   1.8   WMS-15226 Change Policy (yeekung03)           */
/* 15-Nov-2021  YeeKung   1.9   WMS-18365 Change Policy (yeekung04)           */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_GenL6StockStatus]
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

   IF @cLottable06Value = ''
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

      IF @cIVAS = 'LORE1' AND @cBUSR6 = '08'
         SET @cLottable06 = 'EP'  
      
      --ELSE IF @cBUSR6 = '90'   --(yeekung02)    
      --   SET @cLottable06 = 'B' 
      
      --ELSE IF @cBUSR6 >= '80'   --(yeekung03)
      --   SET @cLottable06 = 'Q'     
  
      ELSE IF @cLong ='CPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 7)     
          SET @cLottable06 = 'Q'

      ELSE IF @cLong = 'CPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 6) 
         SET @cLottable06 = 'D'

      ELSE IF @cLong = 'CPD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3)
         SET @cLottable06 = 'D'

      ELSE IF @cLong = 'CPD' AND (@nMonth IS NOT NULL AND @nMonth <= 2) 
         SET @cLottable06 = 'B'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 17) 
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 13) 
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 7 AND @nMonth <= 16)
         SET @cLottable06 = 'Q'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 2 AND @nMonth <= 6)
         SET @cLottable06 = 'D'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 2 AND @nMonth <= 12)
         SET @cLottable06 = 'D'

      ELSE IF @cLong = 'LPD' AND @cItemClass = '19' AND (@nMonth IS NOT NULL AND @nMonth < 2) 
         SET @cLottable06 = 'B'

      ELSE IF @cLong = 'PPD' AND (@nMonth IS NOT NULL AND @nMonth >= 8)
         SET @cLottable06 = 'U' 
		 
	  ELSE IF  @cLong='PPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 7) 
	     SET @cLottable06='Q'

	  ELSE IF  @cLong='PPD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 7) 
	     SET @cLottable06='D'
		 
      ELSE IF @cLong = 'PPD' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
         SET @cLottable06 = 'B'

      ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 20) 
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'ACD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 14) 
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 19) 
         SET @cLottable06 = 'Q'

      --ELSE IF @cLong = 'ACD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 2 AND @nMonth <= 5) 
      --   SET @cLottable06 = 'D'  

      ELSE IF @cLong = 'ACD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 13) 
         SET @cLottable06 = 'D'

      ELSE IF @cLong = 'ACD' AND (@nMonth IS NOT NULL AND @nMonth <= 2)
         SET @cLottable06 = 'B'

      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 15) --(yeekung04)
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 7)  --(yeekung04)
         SET @cLottable06 = 'U'

      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 14) --(yeekung02) (yeekung04)     
         SET @cLottable06 = 'Q'  

      --ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 4 AND @nMonth <= 6)   --(yeekung02)    
      --   SET @cLottable06 = 'D'      
      
      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth >= 3 AND @nMonth <= 6) --(yeekung04)       
         SET @cLottable06 = 'D'      
      
      ELSE IF @cLong = 'LPD' AND @cSKUGroup = 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 2)--(yeekung02)       
         SET @cLottable06 = 'B'   

      ELSE IF @cLong = 'LPD' AND @cSKUGroup <> 'YFG' AND (@nMonth IS NOT NULL AND @nMonth <= 2) 
         SET @cLottable06 = 'B'

      ELSE 
         SET @cLottable06 = ''

      IF @cLottable06 = ''
      BEGIN
         SET @nErrNo = 56751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedProdStatus
      END
      ELSE
         -- Remain in current screen
         SET @nErrNo = -1
   END
   ELSE
   BEGIN
      IF NOT EXISTS( SELECT 1 
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'PRODSTATUS' 
            AND Code = @cLottable06 
            AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 56752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Bad ProdStatus
      END
   END
END

GO