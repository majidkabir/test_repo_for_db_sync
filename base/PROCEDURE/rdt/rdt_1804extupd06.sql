SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804ExtUpd06                                    */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-04-12   YeeKung   1.0   Created. WMS-12916                      */  
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1804ExtUpd06]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cUCC            NVARCHAR( 20)
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount 			INT
   	    ,@cLot              NVARCHAR(10)
          ,@b_success         INT
          ,@dLottable05       DATETIME
          ,@cLottable06       NVARCHAR(20)
          ,@cLottable07       NVARCHAR(20)
          ,@cLottable08       NVARCHAR(20)
          ,@cLottable09       NVARCHAR(20)
          ,@cLottable10       NVARCHAR(20)
          ,@cLottable11       NVARCHAR(20)
          ,@cLottable12       NVARCHAR(20)

   DECLARE @cPrinter    NVARCHAR( 10)  
   DECLARE @cUCClabel NVARCHAR( 50)   
   DECLARE @tUCClabel AS VariableTable  
   				
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC
   IF @nFunc = 1804
   BEGIN
      IF @nStep=7
      BEGIN


        SELECT top 1 @cLot = Lot   
        FROM dbo.LotAttribute WITH (NOLOCK)  
        WHERE StorerKey = @cStorerKey  
        AND SKU = @cSKU  
         
         SELECT   @dLottable05 = Lottable05,
                  @cLottable06 = Lottable06,
                  @cLottable07 = Lottable07,
                  @cLottable08 = Lottable08,
                  @cLottable09 = Lottable09,
                  @cLottable10 = Lottable10,
                  @cLottable11 = Lottable11,
                  @cLottable12 = Lottable12
         FROM dbo.LotAttribute WITH (NOLOCK)  
         WHERE Lot = @cLOT  


         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)   
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)  
                     JOIN dbo.LotAttribute LA WITH (NOLOCK) ON ( LLI.Lot = LA.Lot)  
                     WHERE LLI.StorerKey = @cStorerKey  
                     AND   LLI.SKU = @cSKU  
                     AND   LLI.LOC = @cFromLOC  
                     AND   (( ISNULL( @cFromID, '') = '') OR ( LLI.ID = @cFromID))  
                     AND   LOC.Facility = @cFacility  
                     AND   ISNULL( LA.Lottable05, '') <> @dLottable05 
                     AND   ISNULL( LA.Lottable06, '') <> @cLottable06 
                     AND   ISNULL( LA.Lottable07, '') <> @cLottable07 
                     AND   ISNULL( LA.Lottable08, '') <> @cLottable08 
                     AND   ISNULL( LA.Lottable09, '') <> @cLottable09 
                     AND   ISNULL( LA.Lottable10, '') <> @cLottable10 
                     AND   ISNULL( LA.Lottable11, '') <> @cLottable11 
                     AND   ISNULL( LA.Lottable12, '') <> @cLottable12 
                     GROUP BY LA.LOT  
                     HAVING ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.PendingMoveIn), 0) > 0)
         BEGIN
            UPDATE dbo.UCC WITH (ROWLOCK)  
            SET Lot = @cLot  
            WHERE StorerKey = @cStorerKey  
            AND SKU = @cSKU  
            AND UCCNo = @cUCC  
          
            IF @@ERROR <> 0  

            BEGIN  
               SET @nErrNo = 153351  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdUCCFail  
               GOTO Quit  
            END  
  

         END

         SELECT @cPrinter = PRINTER   
         FROM rdt.rdtmobrec WITH (NOLOCK)  
         WHERE Mobile = @nMobile   
  
         SET @cUCClabel = rdt.rdtGetConfig( @nFunc, 'UCCSEPLabel', @cStorerKey)  
         IF @cUCClabel = '0'  
            SET @cUCClabel = ''  
         IF (@cUCClabel<>'')
         BEGIN
            INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cUCCno', @cUCC)
            INSERT INTO  @tUCClabel (Variable, Value) VALUES ( '@cSKU', @cSKU) 

            -- Print label  
            EXEC RDT.rdt_Print  
                  @nMobile       = @nMobile  
               , @nFunc         = @nFunc  
               , @cLangCode     = @cLangCode  
               , @nStep         = 0  
               , @nInputKey     = 1  
               , @cFacility     = @cFacility  
               , @cStorerKey    = @cStorerKey  
               , @cLabelPrinter = @cPrinter  
               , @cPaperPrinter = '' 
               , @cReportType   = @cUCClabel  
               , @tReportParam  = @tUCClabel  
               , @cSourceType   = 'rdt_1804ExtUpd06'  
               , @nErrNo        = @nErrNo  OUTPUT  
               , @cErrMsg       = @cErrMsg OUTPUT 

               IF @cErrMsg<>''
                  GOTO QUIT
         END
      END
   END

Quit:

END

GO