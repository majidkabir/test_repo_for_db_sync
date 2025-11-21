SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************************************/
/* Store procedure: rdt_LottableProcess_EndPalletize_01                                                */
/* Copyright      : LF Logistics                                                                       */
/*                                                                                                     */
/* Purpose: Generate lottable value for VAP Palletisation from Uncasing table                          */
/*                                                                                                     */
/* Date         Author    Ver.  Purposes                                                               */
/* 03-Feb-2016  James     1.0   SOS315942 Created                                                      */
/*******************************************************************************************************/

CREATE PROCEDURE [RDT].[rdt_LottableProcess_EndPalletize_01]
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cWorkOrderKey     NVARCHAR( 10),
           @cJobKey           NVARCHAR( 10)

   SELECT @cWorkOrderKey = V_String4,
          @cJobKey = V_String10
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE MOBILE = CAST( @cSourceKey AS INT)

      SELECT TOP 1 
             @cLottable01 = Lottable01,
             @cLottable02 = Lottable02, 	
             @cLottable03 = Lottable03, 
             @dLottable04 = Lottable04 
      FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] = '3'
      AND   ISNULL( Qty - QtyCompleted, 0) > 0
      AND   SKU.BUSR3 = 'DGE-GEN'

      SELECT @cLottable07 = Udf1,
             @cLottable08 = Udf4
      FROM dbo.WorkOrderRequest WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey

      insert into traceinfo (tracename, timein, col1, col2, col3, col4) values 
      ('1153', getdate(), @cWorkOrderKey, @cJobKey, @cLottable07, @cLottable08)
Fail:

END

GO