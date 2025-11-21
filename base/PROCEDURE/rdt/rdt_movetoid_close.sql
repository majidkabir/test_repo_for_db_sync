SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveToID_Close                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS265198. Created                        */
/* 2018-03-07 1.1  ChewKP     WMS-4190 Add ConfirmSP Config (ChewKP01)  */
/* 2021-06-15 1.2  James      WMS-17221 Add stdevtlog (james02)         */
/* 2023-07-29 1.3  Ung        WMS-23069 Add serial no                   */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveToID_Close] (
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @cStorerKey NVARCHAR( 15),
   @cToID      NVARCHAR( 18),
   @cToLOC     NVARCHAR( 10),
   @nErrNo     INT       OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cFromLOT    NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY        INT
   DECLARE @cSerialNo   NVARCHAR( 30)
   DECLARE @cUserName   NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cFacility = ''

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_MoveToID_Close

   DECLARE @cConfirmSP NVARCHAR( 20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''

   -- Custom receiving logic
   IF @cConfirmSP <> ''
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         '@nMobile    INT,                  ' +
         '@nFunc      INT,                  ' +
         '@cLangCode  NVARCHAR( 3),         ' +
         '@nStep      INT,                  ' +
         '@cStorerKey NVARCHAR( 15),        ' +
         '@cToID      NVARCHAR( 18),        ' +
         '@cToLOC     NVARCHAR( 10),        ' +
         '@nErrNo     INT           OUTPUT, ' +
         '@cErrMsg    NVARCHAR( 20) OUTPUT  '

       EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToID, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT
   END
   ELSE
   BEGIN
      -- Loop rdtMoveToIDLog
      DECLARE @curMoveToIDLog CURSOR
      SET @curMoveToIDLog = CURSOR FOR
         SELECT FromLOT, FromLOC, FromID, SKU, QTY, SerialNo
         FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND ToID = @cToID
      OPEN @curMoveToIDLog
      FETCH NEXT FROM @curMoveToIDLog INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY, @cSerialNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get facility
         IF @cFacility = ''
            SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

         -- Reduce LOTxLOCxID.QTYReplen
         UPDATE dbo.LOTxLOCxID SET
            QTYReplen = CASE WHEN QTYReplen - @nQTY >= 0 THEN QTYReplen - @nQTY ELSE 0 END
         WHERE LOT = @cFromLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 78951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END

         -- Move
         EXECUTE rdt.rdt_Move
            @nMobile     = @nMobile,
            @cLangCode   = @cLangCode,
            @nErrNo      = @nErrNo  OUTPUT,
            @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
            @cSourceType = 'rdtfnc_Move_SKU',
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @cFromLOC    = @cFromLOC,
            @cToLOC      = @cToLOC,
            @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cFromLOT    = @cFromLOT,
            @cSKU        = @cSKU,
            @nQTY        = @nQTY
         IF @nErrNo <> 0
            GOTO RollBackTran

         IF @cSerialNo <> ''
         BEGIN
            UPDATE dbo.SerialNo SET
               ID = @cToID, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cSerialNo
               AND Status = '1'
            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 78953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD SNO Fail
               GOTO RollBackTran
            END
         END

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '4', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cToID         = @cToID,
            @cToLocation   = @cToLOC,
            @cSKU          = @cSKU,
            @nQTY          = @nQTY,
            @cLocation     = @cFromLOC,
            @cID           = @cFromID,
            @cSerialNo     = @cSerialNo

         FETCH NEXT FROM @curMoveToIDLog INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY, @cSerialNo
      END

      -- Delete log
      DELETE rdt.rdtMoveToIDLog
      WHERE StorerKey = @cStorerKey
         AND ToID = @cToID
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
         GOTO RollBackTran
      END
   END
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_MoveToID_Close
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO