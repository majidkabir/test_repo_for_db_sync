SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_803CustomID01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 25-11-2022 1.0 Ung         WMS-21112 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_803CustomID01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5) ,
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cPosition    NVARCHAR( 10),
   @cMethod      NVARCHAR( 1),
   @cSKU         NVARCHAR( 20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR(250) OUTPUT,
   @cNewCartonID NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)

   DECLARE @cPickSlipNo    NVARCHAR( 10) = ''
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerkey)
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''

   -- Get assign info
   SELECT @cLoadKey = LoadKey
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
   WHERE Station = @cStation
      AND Position = @cPosition

   -- Get Pickslip
   -- Note: packing side is by load, picking side is by wave
   SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE LoadKey = @cLoadKey

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_803CustomID01 -- For rollback or commit only our own transaction
   
   -- PackHeader
   IF @cPickSlipNo = ''
   BEGIN
      -- Generate PickSlipNo
      EXECUTE dbo.nspg_GetKey
         'PICKSLIP',
         9,
         @cPickSlipNo   OUTPUT,
         @bSuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT  
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cPickSlipNo = 'P' + @cPickSlipNo
      
      INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
      VALUES (@cPickSlipNo, @cStorerKey, '', @cLoadKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 194301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHdr Fail
         GOTO RollBackTran
      END
   END

   SET @cLabelNo = ''
   SET @nCartonNo = 0

   IF @cGenLabelNo_SP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')  
      BEGIN
         SET @cSQL = 'EXEC dbo.' + RTRIM( @cGenLabelNo_SP) +
            ' @cPickslipNo, ' +  
            ' @nCartonNo,   ' +  
            ' @cLabelNo     OUTPUT '  
         SET @cSQLParam =
            ' @cPickslipNo  NVARCHAR(10),       ' +  
            ' @nCartonNo    INT,                ' +  
            ' @cLabelNo     NVARCHAR(20) OUTPUT '  
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cPickSlipNo, 
            @nCartonNo, 
            @cLabelNo OUTPUT
      END
   END
   ELSE
   BEGIN   
      EXEC isp_GenUCCLabelNo
         @cStorerKey,
         @cLabelNo      OUTPUT, 
         @bSuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 194302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenLabelNoFail
         GOTO RollBackTran
      END
   END
   
   IF @cLabelNo <> ''
      SET @cNewCartonID = @cLabelNo
   
   COMMIT TRAN rdt_803CustomID01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_803CustomID01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO