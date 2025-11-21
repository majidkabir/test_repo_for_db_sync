SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_CloseCarton                                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Close station                                                     */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 01-03-2021 1.0  YeeKung    WMS-16066 Created                               */
/* 22-11-2022 1.1  Ung        WMS-21112 Rename PtlPieceCloseCartonSP to       */
/*                            CloseCartonSP                                   */
/*                            Add ShipLabel, CartonManifest                   */
/* 30-11-2022 1.2  Ung        WMS-21170 Add DynamicSlot that need carton ID   */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_PTLPiece_CloseCarton] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR(5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cLight       NVARCHAR( 1)
   ,@cStation     NVARCHAR( 10)
   ,@cPosition    NVARCHAR( 20)
   ,@cLOC         NVARCHAR( 20)
   ,@cCartonID    NVARCHAR( 20)
   ,@cNewCartonID NVARCHAR( 20)
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT 
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cCloseCartonSP NVARCHAR(30)

   SET @nTranCount = @@TRANCOUNT

   SET @cCloseCartonSP = rdt.rdtGetConfig( @nFunc, 'CloseCartonSP', @cStorerKey)
   IF @cCloseCartonSP = '0'
      SET @cCloseCartonSP = ''

  /**********************************************************************************************/
  /*                                     Custom close carton                                    */
  /**********************************************************************************************/
   IF @cCloseCartonSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCloseCartonSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCloseCartonSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cLight, @cStation, @cPosition, @cLOC, @cCartonID, @cNewCartonID, ' + 
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '  @nMobile    INT                 '+
            ' ,@nFunc      INT                 '+
            ' ,@cLangCode  NVARCHAR( 3)        '+
            ' ,@nStep      INT                 '+
            ' ,@nInputKey  INT                 '+
            ' ,@cFacility  NVARCHAR(5)         '+
            ' ,@cStorerKey NVARCHAR( 15)       '+
            ' ,@cLight     NVARCHAR( 1)        '+
            ' ,@cStation   NVARCHAR( 10)       '+
            ' ,@cPosition  NVARCHAR( 20)       '+
            ' ,@cLOC       NVARCHAR( 20)       '+
            ' ,@cCartonID  NVARCHAR( 20)       '+
            ' ,@cNewCartonID  NVARCHAR( 20)        ' +
            ' ,@nErrNo     INT           OUTPUT'+
            ' ,@cErrMsg    NVARCHAR(250) OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
            @cLight, @cStation, @cPosition, @cLOC, @cCartonID, @cNewCartonID, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         GOTO Quit
      END
   END
   
  /**********************************************************************************************/
  /*                                   Standard close carton                                    */
  /**********************************************************************************************/
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_PTLPiece_CloseCarton -- For rollback or commit only our own transaction

   UPDATE rdt.rdtPTLPieceLog SET
      CartonID = @cNewCartonID,
      EditDate = GETDATE(),
      EditWho = SUSER_SNAME()
   WHERE Station = @cStation
      AND Position = @cPosition
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 164951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Log fail
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_PTLPiece_CloseCarton
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

  /***********************************************************************************************
                                             Print label
  ***********************************************************************************************/
   -- Storer config
   DECLARE @cCartonManifest NVARCHAR( 10)
   DECLARE @cShipLabel      NVARCHAR( 10)
   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)
   IF @cCartonManifest = '0'
      SET @cCartonManifest = ''
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   -- Print label
   IF @cCartonManifest <> '' OR @cShipLabel <> ''
   BEGIN
      DECLARE @cPickSlipNo NVARCHAR( 10)
      DECLARE @cLabelNo    NVARCHAR( 20)
      DECLARE @nCartonNo   INT
     
      -- Get carton info
      SELECT TOP 1 
         @cPickSlipNo = PickSlipNo, 
         @cLabelNo    = LabelNo, 
         @nCartonNo   = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cCartonID
      
      IF @@ROWCOUNT > 0
      BEGIN
         -- Get login info
         DECLARE @cPaperPrinter NVARCHAR( 10)
         DECLARE @cLabelPrinter NVARCHAR( 10)
         SELECT 
            @cPaperPrinter = Printer_Paper,
            @cLabelPrinter = Printer
         FROM rdt.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Ship label
         IF @cShipLabel <> ''
         BEGIN
            -- Common params
            DECLARE @tShipLabel AS VariableTable
            INSERT INTO @tShipLabel (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cShipLabel, -- Report type
               @tShipLabel, -- Report params
               'rdt_PTLPiece_CloseCarton',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Carton manifest
         IF @cCartonManifest <> ''
         BEGIN
            -- Common params
            DECLARE @tCartonManifest AS VariableTable
            INSERT INTO @tCartonManifest (Variable, Value) VALUES
               ( '@cStorerKey',     @cStorerKey),
               ( '@cPickSlipNo',    @cPickSlipNo),
               ( '@cLabelNo',       @cLabelNo),
               ( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
               @cCartonManifest, -- Report type
               @tCartonManifest, -- Report params
               'rdt_PTLPiece_CloseCarton',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

  /***********************************************************************************************
                                Off light after assigned new carton ID
  ***********************************************************************************************/
   -- Storer configure
   DECLARE @cDynamicSlot NVARCHAR(30)
   DECLARE @cCustomCartonIDSP NVARCHAR(30)

   SET @cDynamicSlot = rdt.rdtGetConfig( @nFunc, 'DynamicSlot', @cStorerKey)
   SET @cCustomCartonIDSP = rdt.rdtGetConfig( @nFunc, 'CustomCartonIDSP', @cStorerKey)

   IF @cDynamicSlot = '1' AND
      @cCustomCartonIDSP = '0' 
   BEGIN
      IF @cLight = '1'
      BEGIN
         -- Off light
         DECLARE @bSuccess INT
         EXEC PTL.isp_PTL_TerminateModuleSingle
             @cStorerKey
            ,@nFunc
            ,@cStation
            ,@cPosition
            ,@bSuccess  OUTPUT
            ,@nErrNo    OUTPUT
            ,@cErrMsg   OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_PTLPiece_CloseCarton -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO