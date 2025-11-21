SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Move_PrePack_Carton_Confirm                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-07-28 1.0  Ung      WMS-20345 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Move_PrePack_Carton_Confirm] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @cFromLOC        NVARCHAR( 10),
   @cRefNo          NVARCHAR( 20),
   @nQTY            INT,
   @cToID           NVARCHAR( 18),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)

   DECLARE @tContent TABLE
   (
      SKU NVARCHAR( 20) NOT NULL, 
      QTY INT           NOT NULL
   )

   SET @nTranCount = @@TRANCOUNT

   -- Get one of the order (with the prepack code)
   SELECT TOP 1 
      @cOrderKey = OrderKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND Notes2 = @cRefNo

   -- Get the content of 1 order (1 carton)
   INSERT INTO @tContent (SKU, QTY)
   SELECT SKU, SUM( OriginalQTY)
   FROM dbo.OrderDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   GROUP BY SKU

   -- Multiple by the no of cartons
   UPDATE @tContent SET
      QTY = QTY * @nQTY -- No of carton
   
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Move_PrePack_Carton_Confirm -- For rollback or commit only our own transaction

   -- Move the content
   DECLARE @curContent CURSOR
   SET @curContent = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SKU, QTY 
      FROM @tContent
   OPEN @curContent
   FETCH NEXT FROM @curContent INTO @cSKU, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      EXECUTE rdt.rdt_Move
         @nMobile     	= @nMobile,
         @cLangCode   	= @cLangCode,
         @nErrNo      	= @nErrNo  OUTPUT,
         @cErrMsg     	= @cErrMsg OUTPUT,
         @cSourceType 	= 'rdt_Move_PrePack_Carton_Confirm',
         @cStorerKey  	= @cStorerKey,
         @cFacility   	= @cFacility,
         @cFromLOC    	= @cFromLOC,
         @cToLOC      	= @cToLOC,
         @cFromID     	= NULL,     -- NULL means not filter by ID. Blank is a valid ID
         @cToID       	= @cToID,   -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        	= @cSKU,
         @nQTY        	= @nQTY,
		   @nFunc   		= @nFunc
      IF @nErrNo <> 0
         GOTO RollBackTran
      
      FETCH NEXT FROM @curContent INTO @cSKU, @nQTY
   END
   
   COMMIT TRAN rdt_Move_PrePack_Carton_Confirm   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move_PrePack_Carton_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO