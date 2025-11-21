SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_Move_SerialNo                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* 2017-05-04 1.1  Ung      WMS-3547 Add serial no                            */
/* 2019-06-07 1.2  TLTING01 Wrong data type                                   */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Move_SerialNo] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT, 
   @nInputKey     INT, 
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cType         NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cSerialNo     NVARCHAR( 30), 
   @nSerialQTY    INT, 
   @cToLOC        NVARCHAR( 10),
   @cToID         NVARCHAR( 18),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nTranCount  INT
DECLARE @cSerialNoCapture NVARCHAR(1)
DECLARE @cSerialNoKey NVARCHAR(30)   --tlting01

DECLARE @curSNO CURSOR

-- Get SKU info
SELECT @cSerialNoCapture = SerialNoCapture  
FROM SKU WITH (NOLOCK)
WHERE StorerKey = @cStorerKey 
   AND SKU = @cSKU
   
-- Check need serial no
IF @cSerialNoCapture <> '1'
   GOTO Quit

-- Handling transaction
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_Move_SerialNo -- For rollback or commit only our own transaction   

-- Insert log
IF @cType = 'INSERTLOG'
BEGIN
   INSERT INTO rdt.rdtMoveSerialNoLog (Mobile, Func, StorerKey, SKU, SerialNo, QTY)
   VALUES (@nMobile, @nFunc, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 117701
      SET @cErrMsg = rdt.rdtgetmessage( 60564, @cLangCode, 'DSP') --INS MVLog Fail
      GOTO RollbackTran
   END
END

-- Clear log
ELSE IF @cType = 'CLEARLOG'
BEGIN
   IF EXISTS( SELECT 1 FROM rdt.rdtMoveSerialNoLog WITH (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
      DECLARE @nMoveSerialNoLogKey BIGINT
      SET @curSNO = CURSOR FOR
         SELECT MoveSerialNoLogKey 
         FROM rdt.rdtMoveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
      OPEN @curSNO 
      FETCH NEXT FROM @curSNO INTO @nMoveSerialNoLogKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtMoveSerialNoLog WHERE @nMoveSerialNoLogKey = MoveSerialNoLogKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 117702
            SET @cErrMsg = rdt.rdtgetmessage( 60564, @cLangCode, 'DSP') --DEL MVLog Fail
            GOTO RollbackTran
         END
            
         FETCH NEXT FROM @curSNO INTO @nMoveSerialNoLogKey
      END
   END
END

ELSE IF @cType = 'MOVE'
BEGIN
   -- Get LOC info
   DECLARE @cLoseID NVARCHAR(1)
   SELECT @cLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
   
   -- LoseID
   IF @cLoseID = '1'
      SET @cToID = ''
      
   -- Loop serial no
  -- DECLARE @nSerialNoKey BIGINT
   SET @curSNO = CURSOR FOR
      SELECT SerialNo
      FROM rdt.rdtMoveSerialNoLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
   OPEN @curSNO 
   FETCH NEXT FROM @curSNO INTO @cSerialNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get SerialNo info
      DECLARE @cSerialNo_ID NVARCHAR( 18)
      SELECT 
         @cSerialNoKey = SerialNoKey, 
         @cSerialNo_ID = ID
      FROM SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
         
      -- Update serial no ID
      IF @cSerialNo_ID <> @cToID
      BEGIN
         UPDATE SerialNo SET
            ID = @cToID, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME(), 
            TrafficCop = NULL
         WHERE SerialNoKey = @cSerialNoKey  --tlting01
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 117703
            SET @cErrMsg = rdt.rdtgetmessage( 60564, @cLangCode, 'DSP') --UPD SNo Fail
            GOTO RollbackTran
         END
      END
      
      FETCH NEXT FROM @curSNO INTO @cSerialNo
   END
END

COMMIT TRAN rdt_Move_SerialNo -- Only commit change made in rdt_Move_SerialNo
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Move_SerialNo -- Only rollback change made in rdt_Move_SerialNo
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO