SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1804ExtUpd05                                    */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-02-22   ChewKP    1.0   WMS-3850 Created                        */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1804ExtUpd05]
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
   				
   SET @nTranCount = @@TRANCOUNT

   -- Move To UCC
   IF @nFunc = 1804
   BEGIN
      IF @nStep = 7 -- UCC
      BEGIN
      		SELECT @cLot = Lot 
      		FROM dbo.LotAttribute WITH (NOLOCK)
      		WHERE StorerKey = @cStorerKey
      		AND SKU = @cSKU
      		AND Lottable11 = @cUCC
      		
      		IF ISNULL(@cLot,'')  <> '' 
      		BEGIN 
      		   UPDATE dbo.UCC WITH (ROWLOCK)
      		   SET Lot = @cLot
      		   WHERE StorerKey = @cStorerKey
      		   AND SKU = @cSKU
      		   AND UCCNo = @cUCC
      		
		         IF @@ERROR <> 0
		         BEGIN
		            SET @nErrNo = 119801
		            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdUCCFail
		            GOTO Quit
		         END
            END
      END
   END

Quit:

END

GO