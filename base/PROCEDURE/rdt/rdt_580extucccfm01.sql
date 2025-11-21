SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_580ExtUCCCfm01                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 08-Mar-2017 1.0  James       WMS1219. Created                              */
/* 14-Sep-2018 1.1  Ung         WMS-6291 Pack confirm for all pick slip type  */
/* 07-Nov-2018 1.2  James       INC0459184 - Filter func id when retrieve     */
/*                              datawindow (james01)                          */
/* 26-Aug-2021 1.3  James       WMS-17796 Add ORDSKULBL printing (james02)    */
/*                              Add rdtReportToPrinter function               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_580ExtUCCCfm01] (
   @nMobile        INT,
   @nFunc          INT, 
	@cLangCode	    NVARCHAR( 3),
   @nStep          INT,
	@cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cLOC           NVARCHAR( 10), 
   @cPickDetailKey NVARCHAR( 10), 
   @cUCC           NVARCHAR( 20), 
   @nErrNo         INT          OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	      INT,
           @cOrderKey         NVARCHAR( 10),
           @cPickSlipNo       NVARCHAR( 10),
           @cCaseID           NVARCHAR( 20),
           @cLoadKey          NVARCHAR( 10),
           @cUCCSKU           NVARCHAR( 20),
           @cLastCarton       NVARCHAR( 1),
           @cCartonNo         NVARCHAR( 10),
           @cWeight           NVARCHAR( 10),
           @cCube             NVARCHAR( 10),
           @cCartonType       NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cPaperPrinter     NVARCHAR( 10),
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cUserName         NVARCHAR( 18),
           @cLabelNo          NVARCHAR( 20),
           @cLabelLine        NVARCHAR( 5),
           @cZone             NVARCHAR( 18), 
           @nCartonNo         INT,
           @nUCCQTY           INT,
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @cOrdSkuLbl        NVARCHAR( 10),
           @tOrdSkuLbl        VARIABLETABLE,
           @cLabelPrinter1    NVARCHAR( 10),
           @cLabelPrinter2    NVARCHAR( 10)

   DECLARE @fWeight        FLOAT
   DECLARE @fCube          FLOAT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_580ExtUCCCfm01 -- For rollback or commit only our own transaction

   IF @nFunc = 580
   BEGIN
      IF @nStep = 1
      BEGIN
         /*-------------------------------------------------------------------------------

                                        Orders, PickDetail, UCC

         -------------------------------------------------------------------------------*/
         SELECT @cUserName = UserName,
                @cLabelPrinter = Printer,
                @cPaperPrinter = Printer_Paper
          FROM RDT.RDTMobRec WITH (NOLOCK) 
          WHERE Mobile = @nMobile

         -- Get Orders info
         SELECT TOP 1 @cOrderKey = OrderKey 
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey

         SELECT @cPickSlipNo = PickSlipNo,
                @cCaseID = CaseID
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE PickDetailKey = @cPickDetailKey

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 106666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip No
            GOTO RollBackTran
         END

         -- Get PickHeader info
         SELECT
            --@cOrderKey = OrderKey, 
            @cLoadKey = ExternOrderKey, 
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo

         SELECT @cCartonNo = Seqno,
                @fWeight = CurrWeight,
                @fCube = CurrCube,
                @cCartonType = CartonType
         FROM dbo.CartonList CL WITH (NOLOCK)
         JOIN dbo.CartonListDetail CLD WITH (NOLOCK) ON ( CL.CartonKey = CLD.CartonKey)
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 106669
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No CartonList
            GOTO RollBackTran
         END

         IF ISNULL( @cCartonNo, '') = ''
         BEGIN
            SET @nErrNo = 106670
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Carton No
            GOTO RollBackTran
         END

         SET @nCartonNo = CAST( @cCartonNo AS INT)

         -- Check PackHeader exist
         IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
         BEGIN
            -- Insert PackHeader
            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, LoadKey, OrderKey)
            VALUES (@cPickSlipNo, @cStorerKey, @cLoadKey, @cOrderKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackHdrFail
               GOTO RollBackTran
            END
         END

         -- Check PickingInfo exist
         IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
         BEGIN
            -- Insert PackHeader
            INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)
            VALUES (@cPickSlipNo, GETDATE(), @cUserName)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
               GOTO RollBackTran
            END
         END
   
   
         /*-------------------------------------------------------------------------------

                                           PackDetail

         -------------------------------------------------------------------------------*/
         -- Check PackDetail exist
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cUCC)
         BEGIN
            -- Get UCC info
            SELECT 
               @cUCCSKU = SKU, 
               @nUCCQTY = QTY
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND   UCCNo = @cUCC

            IF @nCartonNo = 0
               SET @cLabelLine = '00000'
            ELSE
               -- Get next ReceiptLineNumber
               SELECT @cLabelLine = 
                  RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, DropID, RefNo, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cCaseID, '00000', @cStorerKey, @cUCCSKU, @nUCCQTY, @cUCC, @cUCC, -- CartonNo = 0 and LabelLine = '0000', trigger will auto assign
               'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackDtlFail
               GOTO RollBackTran
            END
         END

         -- Check PackInfo Exists
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                         WHERE PickSlipNo = @cPickSlipNo
                         AND   CartonNo = @nCartonNo)
         BEGIN
            SET @nCartonNo = CAST( @cCartonNo AS INT)

            INSERT INTO dbo.PackInfo 
               (PickSlipNo, CartonNo, Weight, Cube, CartonType)
            VALUES
               (@cPickSlipNo, @nCartonNo, @fWeight, @fCube, @cCartonType)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfoFail
               GOTO RollBackTran
            END
         END

         -- Check label printer blank
         IF @cLabelPrinter = ''
         BEGIN
            SET @nErrNo = 106655
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
            GOTO RollBackTran
         END

        -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'CARTONLBL'
         AND   ( Function_ID = @nFunc OR Function_ID = 0)  
            
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 106656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO RollBackTran
         END
   
         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 106657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO RollBackTran
         END
            
         -- Get CartonNo
         SELECT TOP 1 @nCartonNo = CartonNo 
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND   DropID = @cUCC
            
         -- Insert print job
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'CARTONLBL',       -- ReportType
            'PRINT_CARTONLBL', -- PrintJobName
            @cDataWindow,
            @cLabelPrinter,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @cStorerKey,
            @cPickSlipNo, 
            @nCartonNo,  -- Start CartonNo
            @nCartonNo  -- End CartonNo

         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'SHIPPLABEL'
         AND   ( Function_ID = @nFunc OR Function_ID = 0)  
            
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 106658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO RollBackTran
         END
   
         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 106659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO RollBackTran
         END
            
         -- Get CartonNo
         SELECT TOP 1 @nCartonNo = CartonNo, 
                      @cLabelNo = LabelNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
         AND   DropID = @cUCC

         SELECT @cLabelPrinter1 = PrinterID
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)
         WHERE Function_ID = @nFunc
         AND   StorerKey = @cStorerKey
         AND   PrinterGroup = @cLabelPrinter
         AND   ReportType = 'SHIPPLABEL'
               
         -- Insert print job
         EXEC RDT.rdt_BuiltPrintJob
            @nMobile,
            @cStorerKey,
            'SHIPPLABEL',       -- ReportType
            'PRINT_SHIPPLABEL', -- PrintJobName
            @cDataWindow,
            @cLabelPrinter1,
            @cTargetDB,
            @cLangCode,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT, 
            @cPickSlipNo, 
            @nCartonNo,  -- Start CartonNo
            @nCartonNo,  -- End CartonNo
            @cLabelNo,   -- Start LabelNo
            @cLabelNo    -- End LabelNo

         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Update DropID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            -- Insert DropID
            INSERT INTO dbo.DropID 
               (DropID, LabelPrinted, Status) 
            VALUES 
               (@cUCC, '1', '9')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106660
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Update DropID
            UPDATE dbo.DropID WITH (ROWLOCK) SET
               LabelPrinted = '1'
            WHERE DropID = @cUCC

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106661
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
               GOTO RollBackTran
            END
         END

         -- Check paper printer blank
         IF @cPaperPrinter = ''
         BEGIN
            SET @nErrNo = 106662
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
            GOTO RollBackTran
         END

         -- Get packing list report info
         SET @cDataWindow = ''
         SET @cTargetDB = ''
         SELECT 
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
         FROM RDT.RDTReport WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReportType = 'PACKLIST'
         AND   ( Function_ID = @nFunc OR Function_ID = 0)  
            
         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 106663
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
            GOTO RollBackTran
         END
   
         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 106664
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO RollBackTran
         END
         
         -- Insert DropID
         IF NOT EXISTS( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cUCC)
         BEGIN
            -- Insert DropID
            INSERT INTO dbo.DropID (DropID, Status) VALUES (@cUCC, '9')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106665
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDropIDFail
               GOTO RollBackTran
            END
         END

         -- Check last carton
         /*
         Last carton logic:
         1. If not fully pick (PickDetail.Status = 4), definitely not last carton
         2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton
         */
         -- 1. Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
               AND Status = '4' -- Status = 0 is full case replenish, not check
               AND QTY > 0)
            SET @cLastCarton = 'N' 
         ELSE
         BEGIN
            -- 2. Check pick, pack tally
            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
               SELECT @nExpectedQTY = ISNULL(SUM( QTY), 0)
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               WHERE RKL.PickSlipNo = @cPickSlipNo

            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
               SELECT @nExpectedQTY = ISNULL(SUM( QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cOrderKey

            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
               SELECT @nExpectedQTY = ISNULL(SUM( QTY), 0)
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey
                  
            -- Custom PickSlip
            ELSE
               SELECT @nExpectedQTY = ISNULL(SUM( QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK) 
               WHERE PD.PickSlipNo = @cPickSlipNo

            SELECT @nPackedQty = ISNULL(SUM( QTY), 0) 
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            IF @nExpectedQty <> @nPackedQty
               SET @cLastCarton = 'N' 
            ELSE
            BEGIN
               SET @cLastCarton = 'Y' 

               UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
                  Status = '9'
               WHERE PickSlipNo = @cPickSlipNo
               AND   [Status] < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 106671
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
                  GOTO RollBackTran
               END
            END
         END

         -- Insert print job
         IF @cLastCarton = 'Y'
         BEGIN
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorerKey,
               'PACKLIST',       -- ReportType
               'PRINT_PACKLIST', -- PrintJobName
               @cDataWindow,
               @cPaperPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT, 
               @cPickSlipNo

            IF @nErrNo <> 0
               GOTO RollBackTran

            -- Prompt message
            SET @nErrNo = 106666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackLstPrinted
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg
            SET @nErrNo = 0
            SET @cErrMsg = ''

            -- Update DropID
            UPDATE dbo.DropID SET
               ManifestPrinted = '1'
            WHERE DropID = @cUCC

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 106667
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD DropIDFail
               GOTO RollBackTran
            END
         END

         -- (james02)
         SET @cOrdSkuLbl = rdt.rdtGetConfig( @nFunc, 'OrdSkuLbl', @cStorerKey)
         IF @cOrdSkuLbl = '0'  
            SET @cOrdSkuLbl = ''
                 
         IF @cOrdSkuLbl <> ''
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND   DocType = 'N')
            BEGIN
               SELECT 
                  @cUCCSKU = SKU, 
                  @nUCCQTY = SUM( QTY)
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
               AND   UCCNo = @cUCC
               GROUP BY SKU
                  
               IF EXISTS ( SELECT 1 FROM dbo.ORDERDETAIL WITH (NOLOCK)
                           WHERE OrderKey = @cOrderKey
                           AND   Sku = @cUCCSKU
                           AND   ISNULL( ExtendedPrice, 0) > 0 
                           AND   ISNULL( UnitPrice, 0) > 0)
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)           
                              JOIN dbo.Orders O WITH (NOLOCK) 
                                 ON (C.Long = O.ConsigneeKey AND C.StorerKey = O.StorerKey)          
                              WHERE C.ListName = 'NKLABREF'          
                              AND   O.OrderKey = @cOrderkey          
                              AND   O.StorerKey = @cStorerKey)  
                  BEGIN
                     SELECT @cLabelPrinter2 = PrinterID
                     FROM rdt.rdtReportToPrinter WITH (NOLOCK)
                     WHERE Function_ID = @nFunc
                     AND   StorerKey = @cStorerKey
                     AND   PrinterGroup = @cLabelPrinter
                     AND   ReportType = @cOrdSkuLbl                     
                        
                     INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cStorerKey',    @cStorerKey)
                     INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cSKU',          @cUCCSKU)
                     INSERT INTO @tOrdSkuLbl (Variable, Value) VALUES ( '@cOrderkey',     @cOrderkey)  
           
                     -- Print label  
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter2, '',    
                        @cOrdSkuLbl, -- Report type  
                        @tOrdSkuLbl, -- Report params  
                        'rdt_580ExtUCCCfm01',   
                        @nErrNo  OUTPUT,  
                        @cErrMsg OUTPUT,   
                        @nUCCQTY    -- No of copy
                  
                     IF @nErrNo <> 0
                        GOTO RollBackTran
                  END
               END
            END
         END
         --COMMIT TRAN rdt_580ExtUCCCfm01

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '3', -- Picking
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cLOC, 
            @cRefNo1       = @cUCC, 
            @cPickSlipNo   = @cPickSlipNo

      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_580ExtUCCCfm01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO