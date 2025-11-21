SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtUpdSP05                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Unlock return booked location                                     */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-02-21   yeekung  1.0   WMS-18942 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtUpdSP05]
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
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_513ExtUpdSP05 -- For rollback or commit only our own transaction

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
            DECLARE @cHOSTWHCode NVARCHAR(20)
            
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

            SELECT @cHOSTWHCode=hostwhcode
            from loc (nolock)
            where loc=@ctoloc

            UPDATE LOTattribute WITH (ROWLOCK)
            set lottable06=@cHOSTWHCode
            where lot=@cLOT and sku=@cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 183151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDLotattrFail
               GOTO RollBackTran
            END
         END
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513ExtUpdSP05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO