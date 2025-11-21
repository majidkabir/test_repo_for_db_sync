SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ConfirmShortPick                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print GS1 label                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev   Author   Purposes                                   */
/* 2012-03-11 1.0   Ung      SOS238698 Created                          */
/* 2024-11-27 1.1.0 Dennis   FCR-1349 Fix Bug                           */
/************************************************************************/

CREATE   PROC rdt.rdt_ConfirmShortPick (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @cWaveKey   NVARCHAR( 10),
   @cLoadKey   NVARCHAR( 10), 
   @cOrderkey  NVARCHAR( 10),
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cPickDetailKey NVARCHAR( 10)
DECLARE @cPickSlipNo    NVARCHAR( 10),
@nLoopIndex INT,
@nRowCount  INT
DECLARE @List TABLE
   (
   ID INT IDENTITY(1,1) NOT NULL,
   PickDetailKey NVARCHAR(10)
   )

DECLARE @nTranCount     INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN
SAVE TRAN rdt_ConfirmShortPick

/*--------------------------------------------------------------------------------------------------

                                          PickDetail line

--------------------------------------------------------------------------------------------------*/
IF @cOrderKey <> ''
   INSERT INTO @List
      SELECT PickDetailKey
      FROM PickDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND Status = '4'

IF @cLoadKey <> ''
   INSERT INTO @List
      SELECT PickDetailKey
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      WHERE OD.LoadKey = @cLoadKey
         AND PD.Status = '4'
      
IF @cWaveKey <> ''
   INSERT INTO @List
      SELECT PickDetailKey
      FROM PickDetail PD WITH (NOLOCK)
         INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
         INNER JOIN WaveDetail WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
      WHERE WD.WaveKey = @cWaveKey
         AND PD.Status = '4'

/*--------------------------------------------------------------------------------------------------

                                             PickSlip 

--------------------------------------------------------------------------------------------------*/
DECLARE @curPickSlipNo CURSOR
IF @cOrderKey <> ''
   SET @curPickSlipNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

IF @cLoadKey <> ''
   SET @curPickSlipNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey

IF @cWaveKey <> ''
   SET @curPickSlipNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickHeaderKey 
      FROM PickHeader PH WITH (NOLOCK)
         INNER JOIN WaveDetail WD  WITH (NOLOCK) ON (PH.OrderKey = WD.OrderKey)
      WHERE WD.WaveKey = @cWaveKey

OPEN @curPickSlipNo
FETCH NEXT FROM @curPickSlipNo INTO @cPickSlipNo
WHILE @@FETCH_STATUS = 0
BEGIN
   -- Scan out
   IF EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND ScanOutDate IS NULL)
   BEGIN
      UPDATE dbo.PickingInfo SET
         ScanOutDate = GETDATE()
      WHERE PickSlipNo = @cPickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 75553
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickInfFail
         GOTO RollBackTran
      END
   END
   
   -- Pack confirm
   IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> 9)
   BEGIN
      UPDATE dbo.PackHeader SET
         Status = 9
      WHERE PickSlipNo = @cPickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 75554
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackHdrFail
         GOTO RollBackTran
      END
   END
   FETCH NEXT FROM @curPickSlipNo INTO @cPickSlipNo   
END
SET @nLoopIndex = -1
WHILE(1=1)
BEGIN
   SELECT TOP 1 
      @cPickDetailKey = PickDetailKey,
      @nLoopIndex = id
   FROM @List
   WHERE id > @nLoopIndex
   ORDER BY id

   SELECT @nRowCount = @@ROWCOUNT
   IF @nRowCount = 0
      BREAK

   -- Unallocate
   UPDATE dbo.PickDetail WITH(ROWLOCK) SET
      QTY = 0
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 75551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
      GOTO RollBackTran
   END

   -- Confirm short pick
   UPDATE dbo.PickDetail WITH(ROWLOCK) SET
      Status = 0
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 75552
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
      GOTO RollBackTran
   END
END

COMMIT TRAN rdt_ConfirmShortPick -- Only commit change made in rdt_ConfirmShortPick
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_ConfirmShortPick -- Only rollback change made in rdt_ConfirmShortPick
Quit:
   -- Commit until the level we started
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
Fail:


GO