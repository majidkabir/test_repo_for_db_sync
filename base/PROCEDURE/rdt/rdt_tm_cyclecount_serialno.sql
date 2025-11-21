SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TM_CycleCount_SerialNo                                */
/* Copyright      : MAERSK                                                    */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2023-10-12 1.0  James       WMS-23113. Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_TM_CycleCount_SerialNo] (
   @nFunc               INT,
   @nMobile             INT,
   @cLangCode           NVARCHAR( 3),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cCCKey              NVARCHAR( 10),
   @cCCDetailKey        NVARCHAR( 10),
   @cCCSheetNo          NVARCHAR( 10),
   @cLot                NVARCHAR( 10),
   @cLoc                NVARCHAR( 10),
   @cID                 NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cSerialNo           NVARCHAR( 30),
   @nSerialQTY          INT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount            INT
   DECLARE @nTranCount           INT
   DECLARE @nCountSerialKey      INT
   DECLARE @cChkSerialSKU        NVARCHAR( 20)
   DECLARE @nChkSerialQTY        INT
   DECLARE @nChkSerialQTYExp     INT

   -- Get serial no info
   SELECT
      @nCountSerialKey = CountSerialKey,
      @cChkSerialSKU = SKU,
      @nChkSerialQTY = QTY
   FROM dbo.CCSerialNoLog WITH (NOLOCK)
   WHERE CCKey = @cCCKey
   AND   CCSheetNo = @cCCSheetNo
   AND   StorerKey = @cStorerKey
   AND   SerialNo = @cSerialNo
   AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END

   SET @nRowCount = @@ROWCOUNT
   SET @nTranCount = @@TRANCOUNT

   -- New serial no
   IF @nRowCount = 0
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_TM_CycleCount_SerialNo -- For rollback or commit only our own transaction

      SELECT TOP 1 
         @cCCDetailKey = CCDetailKey,
         @cLot = Lot
      FROM dbo.CCDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   CCKey = @cCCKey
      AND   CCSheetNo = @cCCSheetNo
      AND   Loc = @cLoc
      AND   Sku = @cSKU
      AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END
      ORDER BY EditDate DESC

      -- Insert CCSerialNoLog
      INSERT INTO dbo.CCSerialNoLog ( CCKey, CCDetailKey, CCSheetNo, Facility, StorerKey, SerialNo, SKU, Qty, Lot, Loc, ID, Status)
      VALUES (@cCCKey, @cCCDetailKey, @cCCSheetNo, @cFacility, @cStorerKey, @cSerialNo, @cSKU, @nSerialQTY, '', @cLoc, @cID, '0')--temp remove @cLot
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 220401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Fail
         GOTO RollBackTran
      END

      COMMIT TRAN rdt_TM_CycleCount_SerialNo
      GOTO Quit
   END

   -- Verify serial no
   ELSE IF @nRowCount = 1
   BEGIN
      -- Check SKU matches
      IF @cChkSerialSKU <> @cSKU
      BEGIN
         SET @nErrNo = 220402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
         GOTO Quit
      END

      -- Check QTY matches
      IF @nChkSerialQTYExp <> @nSerialQTY
      BEGIN
         SET @nErrNo = 220403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff QTY
         GOTO Quit
      END

      -- Check serial no received
      IF @nChkSerialQTY <> 0
      BEGIN
         SET @nErrNo = 220404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady rcv
         GOTO Quit
      END

      -- Update serial no
      UPDATE dbo.CCSerialNoLog WITH (ROWLOCK) SET
         QTY = QTY + @nSerialQTY
      WHERE CountSerialKey = @nCountSerialKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 220405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RSNO Fail
         GOTO Quit
      END
   END
   ELSE
   BEGIN
      SET @nErrNo = 220406
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNOMultiRecord
      GOTO Quit
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TM_CycleCount_SerialNo
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO