SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ShortPickCarton_Confirm                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 22-07-2018  1.0  Ung        WMS-5919 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_ShortPickCarton_Confirm] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cCartonID  NVARCHAR( 20),
   @cTotalSKU  NVARCHAR( 5), 
   @cQTYAlloc  NVARCHAR( 5),
   @cQTYShort  NVARCHAR( 5),
   @cQTYPick   NVARCHAR( 5),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @cSQL       NVARCHAR(MAX)
DECLARE @cSQLParam  NVARCHAR(MAX)
DECLARE @cConfirmSP NVARCHAR(20)

-- Get storer configure
SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
IF @cConfirmSP = '0'
   SET @cConfirmSP = ''

/***********************************************************************************************
                                           Custom confirm
***********************************************************************************************/
-- Custom logic
IF @cConfirmSP <> ''
BEGIN
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cCartonID, @cTotalSKU, @cQTYAlloc, @cQTYShort, @cQTYPick, ' + 
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

      SET @cSQLParam =
         ' @nMobile    INT,           ' + 
         ' @nFunc      INT,           ' + 
         ' @cLangCode  NVARCHAR( 3),  ' + 
         ' @nStep      INT,           ' + 
         ' @nInputKey  INT,           ' + 
         ' @cStorerKey NVARCHAR( 15), ' + 
         ' @cFacility  NVARCHAR( 5),  ' + 
         ' @cCartonID  NVARCHAR( 20), ' + 
         ' @cTotalSKU  NVARCHAR( 5),  ' + 
         ' @cQTYAlloc  NVARCHAR( 5),  ' + 
         ' @cQTYShort  NVARCHAR( 5),  ' + 
         ' @cQTYPick   NVARCHAR( 5),  ' + 
         ' @nErrNo     INT           OUTPUT, ' +
         ' @cErrMsg    NVARCHAR( 20) OUTPUT  ' 
         
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
         @cCartonID, @cTotalSKU, @cQTYAlloc, @cQTYShort, @cQTYPick, 
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
END

/***********************************************************************************************
                                          Standard confirm
***********************************************************************************************/
DECLARE @cPickDetailKey NVARCHAR( 10)
DECLARE @cSKU           NVARCHAR( 20)
DECLARE @nQTY           INT
DECLARE @cPickSlipNo    NVARCHAR( 10)
DECLARE @nCartonNo      INT
DECLARE @cLabelNo       NVARCHAR( 20)
DECLARE @cLabelLine     NVARCHAR( 5)
DECLARE @nPackQTY       INT

DECLARE @cSPCartonIDByPickDetailCaseID         NVARCHAR(1)
DECLARE @cUpdatePackDetail                      NVARCHAR(1)
DECLARE @cPickDetailCaseIDLinkPackDetailDropID  NVARCHAR(1)
DECLARE @cPickDetailDropIDLinkPackDetailLabelNo NVARCHAR(1)

-- Get storer config
SET @cSPCartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'SPCartonIDByPickDetailCaseID', @cStorerKey)
SET @cUpdatePackDetail = rdt.rdtGetConfig( @nFunc, 'UpdatePackDetail', @cStorerKey)
SET @cPickDetailCaseIDLinkPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PickDetailCaseIDLinkPackDetailLabelNo', @cStorerKey)
SET @cPickDetailDropIDLinkPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PickDetailDropIDLinkPackDetailLabelNo', @cStorerKey)

DECLARE @nTranCount     INT
SET @nTranCount = @@TRANCOUNT
BEGIN TRAN
SAVE TRAN rdt_ShortPickCarton_Confirm

/*--------------------------------------------------------------------------------------------------

                                          PickDetail line

--------------------------------------------------------------------------------------------------*/
DECLARE @curPD CURSOR

IF @cSPCartonIDByPickDetailCaseID = '1'
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, SKU, QTY
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE CaseID = @cCartonID
         AND StorerKey = @cStorerKey
         AND ShipFlag <> 'Y'
ELSE
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, SKU, QTY
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE DropID = @cCartonID
         AND StorerKey = @cStorerKey
         AND ShipFlag <> 'Y'
      
OPEN @curPD
FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
WHILE @@FETCH_STATUS = 0
BEGIN
   -- Short pick
   UPDATE PickDetail SET
      Status = '4', 
      EditDate = GETDATE(), 
      EditWho = SUSER_SNAME(), 
      TrafficCop = NULL
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 126951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPickDtlFail
      GOTO RollBackTran
   END

   -- Unpack
   IF @cUpdatePackDetail = '1'
   BEGIN
      SET @cLabelLine = ''

      -- Get PackDetail info
      IF @cSPCartonIDByPickDetailCaseID = '1'
      BEGIN
         IF @cPickDetailCaseIDLinkPackDetailDropID = '1'
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cLabelNo = LabelNo, 
               @cLabelLine = LabelLine, 
               @nPackQTY = QTY
            FROM PackDetail WITH (NOLOCK) 
            WHERE DropID = @cCartonID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU

         ELSE
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cLabelNo = LabelNo, 
               @cLabelLine = LabelLine, 
               @nPackQTY = QTY
            FROM PackDetail WITH (NOLOCK) 
            WHERE LabelNo = @cCartonID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
      END
      ELSE
      BEGIN
         IF @cPickDetailDropIDLinkPackDetailLabelNo = '1'
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cLabelNo = LabelNo, 
               @cLabelLine = LabelLine, 
               @nPackQTY = QTY
            FROM PackDetail WITH (NOLOCK) 
            WHERE LabelNo = @cCartonID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU

         ELSE
            SELECT 
               @cPickSlipNo = PickSlipNo, 
               @nCartonNo = CartonNo, 
               @cLabelNo = LabelNo, 
               @cLabelLine = LabelLine, 
               @nPackQTY = QTY
            FROM PackDetail WITH (NOLOCK) 
            WHERE DropID = @cCartonID
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
      END
      
      -- Unpack
      IF @cLabelLine <> ''
      BEGIN
         IF @nPackQTY = @nQTY
         BEGIN
            DELETE PackDetail 
            WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 126952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DELPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE PackDetail SET
               QTY = QTY - @nQTY, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo
               AND LabelNo = @cLabelNo
               AND LabelLine = @cLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 126953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDPackDtlFail
               GOTO RollBackTran
            END
         END
      END
   END

   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSKU, @nQTY
END

COMMIT TRAN rdt_ShortPickCarton_Confirm -- Only commit change made in rdt_ShortPickCarton_Confirm
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_ShortPickCarton_Confirm -- Only rollback change made in rdt_ShortPickCarton_Confirm
Quit:   
   WHILE @@TRANCOUNT > @nTranCount  -- Commit until the level we started
      COMMIT TRAN

GO