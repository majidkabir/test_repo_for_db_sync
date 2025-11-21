SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1628ExtUpd02                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update UCC after finish picking                             */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 29-Nov-2017  1.0  James       WMS3221. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtUpd02] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cShipLabel    NVARCHAR( 10),
            @cOption       NVARCHAR( 1),
            @cLabelNo      NVARCHAR( 20),
            @cPickSlipNo   NVARCHAR( 10),
            @cFacility     NVARCHAR( 5),
            @cLabelPrinter NVARCHAR( 10),
            @cPaperPrinter NVARCHAR( 10),
            @cUserName     NVARCHAR( 18),
            @cConso_Orders NVARCHAR( 10),
            @cPutAwayZone  NVARCHAR( 10),
            @cPickZone     NVARCHAR( 10),
            @cLOT          NVARCHAR( 10),
            @cPickConfirm_SP  NVARCHAR( 20),
            @cSQLStatement NVARCHAR( MAX),
            @cSQLParms     NVARCHAR( MAX),
            @nCartonNo     INT,
            @nTranCount    INT,
            @nRowRef       INT
            
   SELECT @cOption = I_Field01, 
          @cPickSlipNo = V_PickSlipNo,
          @cUserName = UserName,
          @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cPutAwayZone = V_String10,
          @cPickZone = V_String11,
          @cLOT = V_LOT
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   SET @cPickConfirm_SP = rdt.RDTGetConfig( @nFunc, 'ClusterPickConfirm_SP', @cStorerKey)
   IF @cPickConfirm_SP = '0'
      SET @cPickConfirm_SP = ''

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 15
      BEGIN
         IF @cOption = '2'
         BEGIN
            -- Check if user picked something then only proceed
            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK)
                            WHERE LoadKey = @cLoadKey
                            AND   AddWho = @cUserName
                            AND   DropID = @cDropID
                            AND   PickQTY > 0)
                            --AND   [Status] = '1')
               GOTO Quit

            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN
            SAVE TRAN STEP_15_Option1

            -- Confirm pick first
            DECLARE CUR_CFMPICKS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT OrderKey, LOT FROM RDT.RDTPickLock WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND Status = '1'
            AND AddWho = @cUserName
            AND LoadKey = @cLoadKey
            AND SKU = @cSKU
            AND PickQty > 0
            OPEN CUR_CFMPICKS
            FETCH NEXT FROM CUR_CFMPICKS INTO @cConso_Orders, @cLOT
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @nErrNo = 0
               IF @cPickConfirm_SP <> ''
               BEGIN
                  SET @cSQLStatement = 'EXEC rdt.' + RTRIM( @cPickConfirm_SP) +     
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                     ' @cWaveKey, @cLoadKey, @cOrderKey, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, ' + 
                     ' @cLOT, @cLOC, @cDropID, @cStatus, @cCartonType, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                  SET @cSQLParms =    
                     '@nMobile                   INT,           ' +
                     '@nFunc                     INT,           ' +
                     '@cLangCode                 NVARCHAR( 3),  ' +
                     '@nStep                     INT,           ' +
                     '@nInputKey                 INT,           ' +
                     '@cFacility                 NVARCHAR( 5),  ' +
                     '@cStorerkey                NVARCHAR( 15), ' +
                     '@cWaveKey                  NVARCHAR( 10), ' +
                     '@cLoadKey                  NVARCHAR( 10), ' +
                     '@cOrderKey                 NVARCHAR( 10), ' +
                     '@cPutAwayZone              NVARCHAR( 10), ' +
                     '@cPickZone                 NVARCHAR( 10), ' +
                     '@cSKU                      NVARCHAR( 20), ' +
                     '@cPickSlipNo               NVARCHAR( 10), ' +
                     '@cLOT                      NVARCHAR( 10), ' +
                     '@cLOC                      NVARCHAR( 10), ' +
                     '@cDropID                   NVARCHAR( 20), ' +
                     '@cStatus                   NVARCHAR( 1),  ' +
                     '@cCartonType               NVARCHAR( 10), ' +
                     '@nErrNo                    INT           OUTPUT,  ' +
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT   ' 
               
                  EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,     
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                     @cWaveKey, @cLoadKey, @cConso_Orders, @cPutAwayZone, @cPickZone, @cSKU, @cPickSlipNo, 
                     @cLOT, @cLOC, @cDropID, '5', '', @nErrNo OUTPUT, @cErrMsg OUTPUT 
               END
               ELSE
               BEGIN
                  EXECUTE rdt.rdt_Cluster_Pick_ConfirmTask
                     @cStorerKey,
                     @cUserName,
                     @cFacility,
                     @cPutAwayZone,
                     @cPickZone,
                     @cConso_Orders,   -- Set orderkey = '' as conso pick
                     @cSKU,
                     @cPickSlipNo,
                     @cLOT,
                     @cLOC,
                     @cDropID,
                     '5',
                     @cLangCode,
                     @nErrNo        OUTPUT,
                     @cErrMsg       OUTPUT,  -- screen limitation, 20 NVARCHAR max
                     @nMobile, -- (Vicky06)
                     @nFunc    -- (Vicky06)
               END

               IF @nErrNo <> 0
               BEGIN
                  CLOSE CUR_CFMPICKS
                  DEALLOCATE CUR_CFMPICKS
                  ROLLBACK TRAN STEP_15_Option1
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN

                  GOTO Quit
               END

               FETCH NEXT FROM CUR_CFMPICKS INTO @cConso_Orders, @cLOT
            END
            CLOSE CUR_CFMPICKS
            DEALLOCATE CUR_CFMPICKS

            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            -- Ship label
            IF @cShipLabel <> '' 
            BEGIN
               IF ISNULL( @cPickSlipNo, '') = ''
                  SELECT @cPickSlipNo = PickSlipNo
                  FROM dbo.DropID WITH (NOLOCK)
                  WHERE DropID = @cDropID

               SELECT @cLabelNo = LabelNo, 
                      @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   DropID = @cDropID

               -- Common params
               DECLARE @tShipLabel AS VariableTable
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cFromDropID', @cDropID)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                  @cShipLabel, -- Report type
                  @tShipLabel, -- Report params
                  'rdt_Cluster_Pick_PrintLabel', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
   END

   Quit:
END

GO