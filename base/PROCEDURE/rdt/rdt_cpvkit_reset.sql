SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CPVKit_Reset                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 28-08-2018 1.0  Ung       WMS-5368 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_CPVKit_Reset] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerKey    NVARCHAR( 15), 
   @cFacility     NVARCHAR( 5), 
   @cKitKey       NVARCHAR( 10), 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE @nRowRef INT
   DECLARE @nTranCount INT
   DECLARE @nKitSerialNoKey BIGINT
   
   SET @nTranCount = @@TRANCOUNT

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_CPVKit_Reset -- For rollback or commit only our own transaction

   -- Loop log
   DECLARE @curLog CURSOR 
   SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT RowRef
      FROM rdt.rdtCPVKitLog WITH (NOLOCK)
      WHERE KitKey = @cKitKey
      ORDER BY RowRef
   OPEN @curLog 
   FETCH NEXT FROM @curLog INTO @nRowRef
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE rdt.rdtCPVKitLog WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
         GOTO RollbackTran
      END
      FETCH NEXT FROM @curLog INTO @nRowRef
   END

   -- Loop KitSerialNo
   DECLARE @curKSNO CURSOR 
   SET @curKSNO = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT KitSerialNoKey
      FROM KitSerialNo WITH (NOLOCK)
      WHERE KitKey = @cKitKey
   OPEN @curKSNO 
   FETCH NEXT FROM @curKSNO INTO @nKitSerialNoKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE KitSerialNo WHERE KitSerialNoKey = @nKitSerialNoKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL KitSN Fail
         GOTO RollbackTran
      END
      FETCH NEXT FROM @curKSNO INTO @nKitSerialNoKey
   END

   -- Loop KitDetail
   DECLARE @cType NVARCHAR( 5)
   DECLARE @cKitLineNumber NVARCHAR(5)
   DECLARE @curKD CURSOR 
   SET @curKD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Type, KitLineNumber
      FROM KitDetail WITH (NOLOCK)
      WHERE KitKey = @cKitKey
         AND QTY <> 0
   OPEN @curKD 
   FETCH NEXT FROM @curKD INTO @cType, @cKitLineNumber
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE KitDetail SET
         QTY = 0, 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE KitKey = @cKitKey
         AND Type = @cType 
         AND KitLineNumber = @cKitLineNumber
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 128353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD KitDt Fail
         GOTO RollbackTran
      END
      FETCH NEXT FROM @curKD INTO @cType, @cKitLineNumber
   END

   COMMIT TRAN rdt_CPVKit_Reset
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_CPVKit_Reset -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO