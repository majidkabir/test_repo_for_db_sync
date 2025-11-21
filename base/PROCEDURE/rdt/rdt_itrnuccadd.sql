SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_ItrnUCCAdd                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert into ItrnUCC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2020-06-16 1.0  James    WMS-13116. Created                          */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_ItrnUCCAdd] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cSourceType   NVARCHAR( 30),
   @cUCC          NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cFromStatus   NVARCHAR( 10),
   @cToStatus     NVARCHAR( 10),
   @cFromLOT      NVARCHAR( 10),
   @cFromLOC      NVARCHAR( 10),
   @cFromID       NVARCHAR( 18),
   @cToLOC        NVARCHAR( 10),
   @cToID         NVARCHAR( 18),
   @cItrnKey      NVARCHAR( 10),
   @tItrnUCCVar   VARIABLETABLE READONLY,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cItrnLot    NVARCHAR( 10)
   DECLARE @cItrnSKU    NVARCHAR( 20)
   DECLARE @cUCCNo      NVARCHAR( 20)
   DECLARE @cUCCSKU     NVARCHAR( 20)
   DECLARE @cUCCStatus  NVARCHAR( 10)
   DECLARE @cUserName   NVARCHAR( 20)
   DECLARE @nUCCQty     INT
   DECLARE @cCurUCC     CURSOR
   DECLARE @cCurItrn    CURSOR

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN         -- Begin our own transaction
   SAVE TRAN rdt_ItrnUCCAdd -- For rollback or commit only our own transaction

   -- status remain no change
   IF @cFromStatus = @cToStatus
   BEGIN
      -- Get itrn info
      SELECT @cFromLOT = Lot, 
             @cSKU = SKU, 
             @cFromLOC = FromLoc, 
             @cFromID = FromID, 
             @cToLOC = ToLoc, 
             @cToID = ToID
      FROM dbo.ITRN WITH (NOLOCK)
      WHERE ItrnKey = @cItrnKey

      -- Get UCC info
      SET @cCurUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT UCCNo, Sku, Qty, STATUS
      FROM dbo.UCC WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   Sku = @cSKU
      AND   Lot = @cFromLOT
      AND   Loc = @cToLOC
      AND   ID = @cToID
      OPEN @cCurUCC
      FETCH NEXT FROM @cCurUCC INTO @cUCCNo, @cUCCSKU, @nUCCQty, @cUCCStatus
      WHILE @@FETCH_STATUS = 0
      BEGIN
         INSERT INTO dbo.ITRNUCC (ItrnKey, StorerKey, UCCNo,SKU, Qty, FromStatus, ToStatus) VALUES
         (@cItrnKey, @cStorerKey, @cUCCNo, @cUCCSKU, @nUCCQty, @cUCCStatus, @cUCCStatus)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 153751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ITRNUCC InsErr'
            GOTO RollBackTran
         END
       
         FETCH NEXT FROM @cCurUCC INTO @cUCCNo, @cUCCSKU, @nUCCQty, @cUCCStatus   
      END
   END
   
   COMMIT TRAN rdt_ItrnUCCAdd -- Only commit change made in rdt_ItrnUCCAdd
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_ItrnUCCAdd -- Only rollback change made in rdt_ItrnUCCAdd
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:

GO