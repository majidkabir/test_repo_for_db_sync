SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_Lottable12chk_VLT                                 */
/*                                                                        */
/* Purpose: Validate Lottable 12                                          */
/*                                                                        */
/*                                                                        */
/* Date        Author                                                     */
/* 6/04/2024   AGM046                                                     */
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_Lottable12chk_VLT]
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
   
   DECLARE 
        @cErrMessage        NVARCHAR(20)
        ,@isFlymoBatery     INT
        ,@styleValue        NVARCHAR(20) 
   
   SET @nErrNo = 0
   SET @isFlymoBatery = 0
  
   -- IF 01
   IF @cType = 'POST' AND @cStorerKey = 'HUSQ'  AND @nLottableNo = 12
   BEGIN
        SELECT TOP 1 @styleValue = sku.Style                   
        FROM SKU sku (NOLOCK)
        WHERE sku.Sku = @cSKU 

        IF @styleValue = 'B'
        BEGIN
            SET @isFlymoBatery = 1  
        END

        SET @cLottable12 = @cLottable12Value

        IF ISNULL( @cLottable12Value , '') = '' AND  @isFlymoBatery = 1 
        BEGIN
            SET @nErrNo = 217950
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BatchIDNeeded
            SET @nErrNo = -1  -- Make it display value on screen. next ENTER will proceed next screen
        END
       
    END -- END IF 01
      
END -- End Procedure

GO