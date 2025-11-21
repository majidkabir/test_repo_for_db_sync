SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveToID_Confirm                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS265198. Created                        */
/* 2017-07-25 1.1  Ung        Fix bug                                   */
/* 2018-03-07 1.2  ChewKP     WMS-4190 (ChewKP01)                       */
/* 2020-01-15 1.3  YeeKung    INC1008653 Fix rdtMoveToIDLog(yeekung01)  */
/* 2023-07-29 1.4  Ung        WMS-23069 Add serial no                   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveToID_Confirm] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cType         NVARCHAR( 1),   --Y=Confirm, N=Undo
   @cStorerKey    NVARCHAR( 15),
   @cToID         NVARCHAR( 18),
   @cFromLOC      NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cUCC          NVARCHAR( 20) = '',
   @nQTY          INT,
   @cSerialNo     NVARCHAR( 30) = '',
   @nSerialQTY    INT = 0,
   @nBulkSNO      INT = 0,
   @nBulkSNOQTY   INT = 0,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cFacility NVARCHAR( 5)
   DECLARE @cFromLOT  NVARCHAR( 10)
   DECLARE @cFromID   NVARCHAR( 18)
   DECLARE @nQTYAvail INT
   DECLARE @nQTYMove  INT
   DECLARE @nQTYBal   INT
   DECLARE @curLLI    CURSOR
	DECLARE @cRowref   INT

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_MoveToID_Confirm

   IF @cType = 'Y' -- Confirm
   BEGIN
      SET @nQTYBal = @nQTY
      
      -- Open cursor
      IF @cSerialNo <> ''
      BEGIN
         DECLARE @cSerialID NVARCHAR( 18) = ''
         SELECT @cSerialID = ID
         FROM dbo.SerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo

         SET @curLLI = CURSOR FOR
            SELECT LOT, LOC, ID, SKU, QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cFromLOC
               AND ID = @cSerialID
               AND QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END) > 0
      END
      ELSE
         SET @curLLI = CURSOR FOR
            SELECT LOT, LOC, ID, SKU, QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND LOC = @cFromLOC
               AND QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END) > 0

      -- Loop rdtMoveToIDLog
      OPEN @curLLI
      FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYAvail
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get facility
         IF @cFacility = ''
            SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

         -- Calc QTY
         IF @nQTYAvail >= @nQTYBal
            SET @nQTYMove = @nQTYBal
         ELSE
            SET @nQTYMove = @nQTYAvail

         -- Increase LOTxLOCxID.QTYReplen
         UPDATE dbo.LOTxLOCxID SET
            QTYReplen = QTYReplen + @nQTYMove
         WHERE LOT = @cFromLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END

         -- SKU, QTY
         IF @cUCC = '' AND @cSerialNo = ''
         BEGIN
            -- Update Log
            IF EXISTS( SELECT 1 FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                           AND ToID = @cToID
                           AND FromLOT = @cFromLOT
                           AND FromLOC = @cFromLOC
                           AND FromID = @cFromID)
            BEGIN
               UPDATE rdt.rdtMoveToIDLog SET
                  QTY = QTY + @nQTYMove
               WHERE StorerKey = @cStorerKey
                  AND ToID = @cToID
                  AND FromLOT = @cFromLOT
                  AND FromLOC = @cFromLOC
                  AND FromID = @cFromID
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 79002
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log Fail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               INSERT INTO rdt.rdtMoveToIDLog (StorerKey, ToID, FromLOT, FromLOC, FromID, SKU, QTY)
               VALUES (@cStorerKey, @cToID, @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYMove )
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 79003
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
                  GOTO RollBackTran
               END
            END
         END
         
         -- UCC
         ELSE IF @cUCC <> ''
         BEGIN
            INSERT INTO rdt.rdtMoveToIDLog (StorerKey, ToID, FromLOT, FromLOC, FromID, SKU, QTY, UCC)
            VALUES (@cStorerKey, @cToID, @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYMove, @cUCC )
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79007
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
               GOTO RollBackTran
            END
         END
         
         -- Serial no
         ELSE IF @cSerialNo <> ''
         BEGIN
            INSERT INTO rdt.rdtMoveToIDLog (StorerKey, ToID, FromLOT, FromLOC, FromID, SKU, QTY, SerialNo)
            VALUES (@cStorerKey, @cToID, @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nSerialQTY, @cSerialNo)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 79008
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
               GOTO RollBackTran
            END
         END
         
         SET @nQTYBal = @nQTYBal - @nQTYMove
         IF @nQTYBal = 0
            BREAK

         FETCH NEXT FROM @curLLI INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTYAvail
      END

      -- Check QTY fully offset
      IF @nQTYBal <> 0
      BEGIN
         SET @nErrNo = 79004
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotEnuf QTYAVL
         GOTO RollBackTran
      END
   END


   IF @cType = 'N' -- Undo
   BEGIN
      -- Loop rdtMoveToIDLog
      SET @curLLI = CURSOR FOR
         SELECT rowref, FromLOT, FromLOC, FromID, QTY
         FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ToID = @cToID
      OPEN @curLLI
      FETCH NEXT FROM @curLLI INTO @cRowref,@cFromLOT, @cFromLOC, @cFromID, @nQTYMove     --(yeekung01)
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Reduce LOTxLOCxID.QTYReplen
         UPDATE dbo.LOTxLOCxID SET
            QTYReplen = CASE WHEN QTYReplen - @nQTYMove >= 0 THEN QTYReplen - @nQTYMove ELSE 0 END
         WHERE LOT = @cFromLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79005
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END

         -- Delete rdtMoveToIDLog
         DELETE rdt.rdtMoveToIDLog
         WHERE StorerKey = @cStorerKey
            AND ToID = @cToID
            AND FromLOT = @cFromLOT
            AND FromLOC = @cFromLOC
            AND FromID = @cFromID
            AND rowref = @cRowref  --(yeekung01)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 79006
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curLLI INTO @cRowref,@cFromLOT, @cFromLOC, @cFromID, @nQTYMove
      END
   END
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_MoveToID_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO