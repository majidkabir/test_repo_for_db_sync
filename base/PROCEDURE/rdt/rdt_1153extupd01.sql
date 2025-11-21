SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1153ExtUpd01                                    */
/* Purpose: Gen SSCC code. Update to Workorder_Palletize.Lottable03     */
/*          if it not already exists                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-03-17 1.0  James      SOS#362979. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1153ExtUpd01] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cToID                     NVARCHAR( 18), 
   @cJobKey                   NVARCHAR( 10), 
   @cWorkOrderKey             NVARCHAR( 10), 
   @cSKU                      NVARCHAR( 20), 
   @nQtyToComplete            INT, 
   @cPrintLabel               NVARCHAR( 10), 
   @cEndPallet                NVARCHAR( 10), 
   @dStartDate                DATETIME,      
   @cType                     NVARCHAR( 1),   
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @cPartial_SSCC          NVARCHAR( 17),
      @cExtension_digit       NVARCHAR( 1),
      @cCompanyCode           NVARCHAR( 7),
      @cFixscal_Year          NVARCHAR( 2),
      @cPrinterID             NVARCHAR( 1),
      @b_debug                int,
      @b_success              INT,
      @n_err                  INT,
      @c_errmsg               NVARCHAR( 20),
      @cLottable03            NVARCHAR( 18)

   DECLARE 
      @cRunningNum  NVARCHAR( 9),
      @nSumOdd      int,
      @nSumEven     int,
      @nSumAll      int,
      @nPos         int,
      @nNum         int,
      @nTry         int,
      @cChkDigit    NVARCHAR( 1)

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         -- If exists already lottable03 then no need to retrieve again
         IF EXISTS ( SELECT 1 FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
                     WHERE ID = @cToID
                     AND   JobKey = @cJobKey
                     AND   WorkOrderKey = @cWorkOrderKey
                     AND   [Status] = '3'
                     AND   ISNULL( Lottable03, '') <> '')
         BEGIN
            SELECT TOP 1 @cLottable03 = Lottable03
            FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
            WHERE ID = @cToID
            AND   JobKey = @cJobKey
            AND   WorkOrderKey = @cWorkOrderKey
            AND   [Status] = '3'
            AND   ISNULL( Lottable03, '') <> ''

            UPDATE WorkOrder_Palletize WITH (ROWLOCK) SET
               Lottable03 = @cLottable03
            WHERE ID = @cToID
            AND   JobKey = @cJobKey
            AND   WorkOrderKey = @cWorkOrderKey
            AND   [Status] = '3'
            AND   ISNULL( Lottable03, '') = ''

            GOTO Quit
         END

         EXECUTE dbo.nspg_GetKey
            'DGESSCCLblNo',
            6,
            @cRunningNum	OUTPUT,
            @b_success		OUTPUT,
            @n_err			OUTPUT,
            @c_errmsg		OUTPUT

         SET @cExtension_digit = '0'
         SET @cCompanyCode = '5010408'
         SET @cFixscal_Year = ( YEAR( GETDATE() ) % 100 )
         SET @cPrinterID = '1'
         set @cPartial_SSCC = @cExtension_digit + @cCompanyCode + @cFixscal_Year + @cPrinterID + @cRunningNum

         SET @nSumOdd  = 0
         SET @nSumEven = 0
         SET @nSumAll  = 0
         SET @nPos = 1

         WHILE @nPos <= 17
         BEGIN
            SET @nNum = SUBSTRING(@cPartial_SSCC, @nPos, 1)

            IF @nPos % 2 = 0
               SET @nSumEven = @nSumEven + @nNum
            ELSE
               SET @nSumOdd = @nSumOdd + @nNum

            SET @nPos = @nPos + 1
         END

         -- Step 3
         SELECT @nSumAll = (@nSumOdd * 3) + @nSumEven

         IF @b_debug = 1
            SELECT @nSumEven '@nSumEven', @nSumOdd '@nSumOdd', @nSumAll '@nSumAll'

         -- Step 4
         SET @nTry = 0
         WHILE @nTry <= 9
         BEGIN
            IF (@nSumAll + @nTry) % 10 = 0 
            BEGIN
               SET @cChkDigit = CAST( @nTry as NVARCHAR(1))
               BREAK
            END
            SET @nTry = @nTry + 1
         END

         SET @cLottable03 = @cPartial_SSCC + @cChkDigit

         -- Update SSCC to the lottable03
         UPDATE dbo.WorkOrder_Palletize WITH (ROWLOCK) SET 
            Lottable03 = @cLottable03
         WHERE ID = @cToID
         AND   JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'
         AND   ISNULL( Lottable03, '') = ''
      END
   END

   QUIT:

GO