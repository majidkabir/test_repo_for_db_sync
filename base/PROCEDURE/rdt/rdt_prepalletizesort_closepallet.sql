SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PrePalletizeSort_ClosePallet                    */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdtfnc_PrePalletizeSort                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-01-29  1.0  James      WMS11430. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_PrePalletizeSort_ClosePallet] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 20), 
   @cLane            NVARCHAR( 10), 
   @cPosition        NVARCHAR( 20),   
   @cToID            NVARCHAR( 18),  
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 125) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @cUdf06       NVARCHAR( 60),
      @cUdf07       NVARCHAR( 60),
      @cUdf08       NVARCHAR( 60),
      @cUdf09       NVARCHAR( 60),
      @cUdf10       NVARCHAR( 60),
      @cCode        NVARCHAR( 10),
      @cUCCCount    NVARCHAR( 5),
      @cUCCCounted  NVARCHAR( 5),
      @cPOKey       NVARCHAR( 10), 
      @nPosInUsed       INT,
      @nMaxAllowedPos   INT,
      @nTranCount       INT,
      @nNonImmediateNeedsPos  INT,
      @cBUSR7       NVARCHAR( 30),
      @cPrePltClosePltSP   NVARCHAR( 20),
      @cSQL                NVARCHAR( MAX), 
      @cSQLParam           NVARCHAR( MAX)      

   SET @nErrNo = 0

   SET @cPrePltClosePltSP = rdt.RDTGetConfig( @nFunc, 'PrePltSortClosePltSP', @cStorerkey)
   IF @cPrePltClosePltSP IN ('0', '')
      SET @cPrePltClosePltSP = ''

   IF @cPrePltClosePltSP <> '' AND 
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPrePltClosePltSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cPrePltClosePltSP) +     
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane, ' + 
         ' @cPosition, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

      SET @cSQLParam =    
         '@nMobile         INT,           ' +
         '@nFunc           INT,           ' +
         '@cLangCode       NVARCHAR( 3),  ' +
         '@nStep           INT,           ' +
         '@nInputKey       INT,           ' +
         '@cStorerkey      NVARCHAR( 15), ' +
         '@cFacility       NVARCHAR( 5),  ' +
         '@cReceiptKey     NVARCHAR( 20), ' +
         '@cLane           NVARCHAR( 10), ' +
         '@cPosition       NVARCHAR( 20), ' +  
         '@cToID           NVARCHAR( 18), ' +  
         '@nErrNo          INT            OUTPUT, ' +
         '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility, @cReceiptKey, @cLane,  
            @cPosition, @cToID, @nErrNo OUTPUT, @cErrMsg OUTPUT 
      RETURN
   END


GO