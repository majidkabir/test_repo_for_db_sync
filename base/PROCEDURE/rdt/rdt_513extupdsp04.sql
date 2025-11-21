SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtUpdSP04                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Unlock return booked location                                     */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-12-04   Ung       1.0   WMS-6467 Created (base on rdt_513ExtUpdSP03)  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtUpdSP04]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
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

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            -- 1 FromLOC can put into multiple ToLOC (pick face). Extended validate will block if ToLOC is not one of the suggested ToLOC
            -- Even if go to 1 ToLOC, the could be multiple ITrn, due to different LOT

            DECLARE @nBal     INT
            DECLARE @nITrnQTY INT
            DECLARE @nRF_QTY  INT
            DECLARE @nRowRef  INT
            DECLARE @nDeduct  INT
            DECLARE @cLOT     NVARCHAR(10)
            DECLARE @cITrnKey NVARCHAR(10)
            
            SET @nBal = @nQTY
            
            -- Get 1st ITrn
            SET @nITrnQTY = 0
            SELECT TOP 1 
               @cITrnKey = ITrnKey, 
               @nITrnQTY = QTY, 
               @cLOT = LOT
            FROM ITrn WITH (NOLOCK)
            WHERE TranType = 'MV'
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND FromLOC = @cFromLOC
               AND FromID = @cFromID
               AND ToLOC = @cToLOC
            ORDER BY ITrnKey DESC

            -- Get 1st RFPutaway
            SET @nRF_QTY = 0
            SELECT TOP 1
               @nRowRef = RowRef, 
               @nRF_QTY = QTY
            FROM dbo.RFPutaway WITH (NOLOCK)
            WHERE FromLOC = @cFromLOC
               AND FromID = @cFromID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOT = @cLOT
               AND SuggestedLOC = @cToLOC
            ORDER BY RowRef

            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_513ExtUpdSP04 -- For rollback or commit only our own transaction
            
            -- Loop if have QTY
            WHILE @nBal > 0 AND @nITrnQTY > 0 AND @nRF_QTY > 0
            BEGIN
               -- Take smallest amoung 3 QTY
               IF @nITrnQTY > @nRF_QTY
                  SET @nDeduct = @nRF_QTY
               ELSE
                  SET @nDeduct = @nITrnQTY
                  
               IF @nDeduct > @nBal
                  SET @nDeduct = @nBal
-- select 'start', @nDeduct '@nDeduct', @nRF_QTY '@nRF_QTY', @nRowRef '@nRowRef', @cITrnKey '@cITrnKey', @nITrnQTY '@nITrnQTY', @nBal '@nBal'
               -- RFPutaway
               IF @nDeduct = @nRF_QTY
               BEGIN
                  DELETE dbo.RFPutaway WITH (ROWLOCK)
                  WHERE  RowRef = @nRowRef
                  IF @@ERROR <> 0
                     GOTO RollBackTran
               END
               ELSE
               BEGIN
                  UPDATE dbo.RFPutaway SET 
                     QTY = QTY - @nDeduct
                  WHERE RowRef = @nRowRef
                  IF @@ERROR <> 0
                     GOTO RollBackTran
               END

               -- Reduce QTY
               SET @nBal = @nBal - @nDeduct
               SET @nITrnQTY = @nITrnQTY - @nDeduct
               SET @nRF_QTY = @nRF_QTY - @nDeduct

-- select 'end', @nDeduct '@nDeduct', @nRF_QTY '@nRF_QTY', @nRowRef '@nRowRef', @cITrnKey '@cITrnKey', @nITrnQTY '@nITrnQTY', @nBal '@nBal'

               IF @nBal = 0
                  BREAK
                  
               -- Get next ITrn
               IF @nITrnQTY = 0
               BEGIN
                  SELECT TOP 1 
                     @cITrnKey = ITrnKey, 
                     @nITrnQTY = QTY, 
                     @cLOT = LOT
                  FROM ITrn WITH (NOLOCK)
                  WHERE TranType = 'MV'
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND FromLOC = @cFromLOC
                     AND FromID = @cFromID
                     AND ToLOC = @cToLOC
                     AND ITrnKey < @cITrnKey
                  ORDER BY ITrnKey DESC
               
                  IF @nITrnQTY = 0
                     BREAK

                  SET @nRF_QTY = 0 -- Need to reload, due to LOT change
                  SET @nRowRef = 0
               END
               
               -- Get next RFPutaway
               IF @nRF_QTY = 0
               BEGIN
                  SELECT TOP 1
                     @nRowRef = RowRef, 
                     @nRF_QTY = QTY
                  FROM dbo.RFPutaway WITH (NOLOCK)
                  WHERE FromLOC = @cFromLOC
                     AND FromID = @cFromID
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LOT = @cLOT
                     AND SuggestedLOC = @cToLOC
                     AND RowRef > @nRowRef
                  ORDER BY RowRef

                  IF @nRF_QTY = 0
                     BREAK
               END
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513ExtUpdSP04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO