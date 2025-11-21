SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/
/* Store procedure: rdt_840ExtUpd25                                     */
/* Purpose: Auto short pick pickdetail line which not been packed       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 03-08-2022  1.0  yeekung   WMS-20495 add label type                  */ 
/* 25-12-2022  1.1  yeekung    WMS-20500 Add PDF print (yeekung01)       */
/************************************************************************/

CREATE     PROC [RDT].[rdt_840ExtUpd25] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerkey  NVARCHAR( 15),
   @cOrderKey   NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @cTrackNo    NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,           
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount           INT
   DECLARE @cShipLabel        NVARCHAR( 10)
   DECLARE @cDelNotes         NVARCHAR( 10)

   DECLARE   @nPack_QTY         INT,
           @nPickQty          INT,
           @nPackQty          INT,
           @nNewCarton        INT,
           @nPD_CartonNo      INT,
           @nFromCartonNo     INT,
           @nToCartonNo       INT,
           @cOrderGroup       NVARCHAR(20),
           @cFacility         NVARCHAR( 5),
            @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cLoadKey          NVARCHAR( 10),
           @cLabelNo          NVARCHAR( 20),
           @cRoute            NVARCHAR( 20),
           @cConsigneeKey     NVARCHAR( 20),
           @cEcomPlatform     VARCHAR(20)

   DECLARE @cShipLabelEcom    NVARCHAR(20)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_840ExtUpd25

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 4 
      BEGIN
        
         SELECT @nPickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorerkey

         SELECT @nPackQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerkey
         AND   PickSlipNo = @cPickSlipNo

         SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
               , @cRoute = ISNULL(RTRIM(Route),'')
               , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')
               --, @cTrackNo = UserDefine04
               , @cTrackNo = TrackingNo   -- (james02)
               , @cOrderGroup = ordergroup
               ,@cEcomPlatform = Ecom_platform
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey

         -- Delivery notes only print when all items pick n pack
         IF @nPickQty = @nPackQty
         BEGIN

            -- (james01)
            -- Get storer config
            DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
            DECLARE @bsuccess INT
            EXECUTE nspGetRight
               @cFacility,
               @cStorerKey,
               '', --@c_sku
               'AssignPackLabelToOrdCfg',
               @bSuccess                 OUTPUT,
               @cAssignPackLabelToOrdCfg OUTPUT,
               @nErrNo                   OUTPUT,
               @cErrMsg                  OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT

            -- Assign
            IF @cAssignPackLabelToOrdCfg = '1'
            BEGIN
               -- Update PickDetail, base on PackDetail.DropID
               EXEC isp_AssignPackLabelToOrderByLoad
                   @cPickSlipNo
                  ,@bSuccess OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO QUIT
            END

            SELECT
               @cLabelPrinter = Printer,
               @cPaperPrinter = Printer_Paper
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
            IF @cDelNotes = '0'
               SET @cDelNotes = ''

            IF @cDelNotes <> ''
            BEGIN
               DECLARE @tDELNOTES AS VariableTable
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cTrackNo',     @cTrackNo)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)
               INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,
                  @cDelNotes, -- Report type
                  @tDELNOTES, -- Report params
                  'rdt_840ExtUpd25',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO QUIT
            END

            IF EXISTS (SELECT 1 FROM Codelkup (nolock) 
                        where listname='VIPORDTYPE' 
                           and storerkey=@cstorerkey
                           and code = @cOrdergroup
                           and short =@nFunc) --yeekung02
            BEGIN
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabels', @cStorerKey)      
               IF @cShipLabel = '0'      
                  SET @cShipLabel = ''   
            END
            ELSE
            BEGIN
               SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShippLabel', @cStorerKey)      
               IF @cShipLabel = '0'      
                  SET @cShipLabel = ''   
            END

            SET @cShipLabelEcom = rdt.RDTGetConfig( @nFunc, 'ShipLabelEC', @cStorerKey)        
            IF @cShipLabelEcom = '0'        
               SET @cShipLabelEcom = ''   
  
            IF @cShipLabel <> ''
            BEGIN

               SELECT @nFromCartonNo = MIN( CartonNo),
                        @nToCartonNo = MAX( CartonNo)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

               DECLARE @tSHIPPLABEL AS VariableTable
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nFromCartonNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nToCartonNo)
               INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',        @cLoadKey)

               IF @cEcomPlatform='PDD'
               BEGIN
                  SET @cShipLabel=@cShipLabelEcom

                  DECLARE @cPrinter      NVARCHAR( 10)
                        ,@cPrintData        NVARCHAR( MAX)
                        ,@cWorkingFilePath  NVARCHAR( 250)
                        ,@cFilePath         NVARCHAR( 250)
                        ,@cFileType         NVARCHAR( 10)
                        ,@cPrintServer      NVARCHAR( 50)
                        ,@cPrintFilePath  NVARCHAR(250)
                        ,@cFileName         NVARCHAR( 100)

                  DECLARE @cWinPrinterName   NVARCHAR( 100),
                             @cPrintCommand       NVARCHAR(MAX) 

                  SELECT @cWorkingFilePath = UDF01,
                           @cFileType = UDF02,
                           @cPrintServer = UDF03,
                           @cPrintFilePath = Notes   -- foxit program
                  FROM dbo.CODELKUP WITH (NOLOCK)      
                  WHERE LISTNAME = 'printlabel'        
                  AND   StorerKey = @cStorerKey
                  Order By Code

                  SELECT @cWinPrinterName = WinPrinter
                  FROM rdt.rdtPrinter WITH (NOLOCK)  
                  WHERE PrinterID = @cLabelPrinter

                  SET @cFileName =  RTRIM( @cTrackNo) + '.' + @cFileType

                  IF CHARINDEX( 'SEND2PRINTER', @cPrintFilePath) > 0    
                     SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cWorkingFilePath + '\' + @cFileName + '" "33" "3" "' + @cWinPrinterName + '"'  

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',
                     @cShipLabel,  -- Report type
                     @tSHIPPLABEL, -- Report params
                     'rdt_840ExtInsPack06',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     1,
                     @cPrintCommand

                  IF @nErrNo <> 0
                     GOTO QUIT
               END
               ELSE
               BEGIN
                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',
                     @cShipLabel,  -- Report type
                     @tSHIPPLABEL, -- Report params
                     'rdt_840ExtInsPack06',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO QUIT
               END
            END
         END
      END
   END


   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_840ExtUpd25
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

GO