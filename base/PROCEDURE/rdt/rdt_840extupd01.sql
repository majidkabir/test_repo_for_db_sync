SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840ExtUpd01                                     */
/* Purpose: If short pick then need insert transmitlog3 to trigger      */
/*          order value recalculation interface to get new total        */
/*          order value                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2015-10-19  1.0  James      SOS#353558. Created                      */
/* 2016-11-02  1.1  MTTEY      IN#00187851. Courier label miss out-MT01-*/
/* 2017-May-25 1.2  CheeMun    IN00305915 - Added Step 1 for ScanInLog  */
/* 2018-01-25  1.3  James      WMS3352-Add                              */
/*                             isp_AssignPackLabelToOrderByLoad(james01)*/
/* 2020-03-10  1.4  James      WMS-12338 Add PreDelNote (james02)       */
/* 2020-07-13  1.5  James      WMS-13919 Display short pack msg(james03)*/
/* 2021-04-01  1.6 YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/* 2022-08-19  1.8 WyeChun    JSM-89759 Swap TrackingNo with            */  
/*                            UserDefine04 (WC01)                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtUpd01] (
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

   DECLARE @nTranCount     INT,
           @cReportType    NVARCHAR( 10),
           @cPrintJobName  NVARCHAR( 50),
           @cDataWindow    NVARCHAR( 50),
           @cTargetDB      NVARCHAR( 20),
           @cOrderType     NVARCHAR( 10),
           @cPaperPrinter  NVARCHAR( 10),
           @cLabelPrinter  NVARCHAR( 10),
           @nOriginalQty   INT,
           @nPickQty       INT,
           @nExpectedQty   INT,
           @nPackedQty     INT,
           @nCtnCount      INT,
           @nCtnNo         INT,
           @b_success      INT,
           @n_err          INT,
           @c_errmsg       NVARCHAR( 20),
           @cOrdType       NVARCHAR( 10),  -- (james02)
           @cErrMsg1       NVARCHAR( 20)   -- (james03)

   DECLARE @bSuccess             INT,
           @cAuthority_ScanInLog NVARCHAR( 1)

   DECLARE @cPackByTrackNotUpdUPC      NVARCHAR(1),
           @cTempBarcode               NVARCHAR( 20),
           @cCheckDigit                NVARCHAR( 1),
           @cOrderBoxBarcode           NVARCHAR( 20),
           @cShipperKey                NVARCHAR( 15),
           @cFacility                  NVARCHAR( 5),     -- (james02)
           @cPreDelNote                NVARCHAR( 10),    -- (james02)
           @cECOM_SINGLE_Flag          NVARCHAR( 1) = '',-- (james02)
           @cCartonType                NVARCHAR( 10)
   SELECT
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile
         
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1 --IN00305915 (start)
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN rdt_840ExtUpd01
         
         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 95401
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO PKSLIP'
            GOTO RollBackTran
         END

         IF ISNULL( @cOrderKey, '') = ''
         BEGIN
            SELECT @cOrderKey = OrderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            IF ISNULL( @cOrderKey, '') = ''
            BEGIN
               SET @nErrNo = 95402
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO ORDERKEY'
               GOTO RollBackTran
            END
         END

         -- (james02)
         SET @cOrdType = ''
         SELECT @cOrdType = [Type],
                @cFacility = Facility,
                @cECOM_SINGLE_Flag = ECOM_SINGLE_Flag -- (james02)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         UPDATE dbo.ORDERS WITH (ROWLOCK) SET
            STATUS = '3',
            EditWho = sUser_sName(),
            EditDate = GetDate()
         WHERE OrderKey = @cOrderKey
         AND Status < '3'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 95403
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdHdr Fail'
            GOTO RollBackTran
         END

         UPDATE dbo.ORDERDETAIL WITH (ROWLOCK) SET
            STATUS = '3',
            EditWho = sUser_sName(),
            EditDate = GetDate(),
            TrafficCop = NULL
         WHERE OrderKey = @cOrderKey
         AND   STATUS < '3'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 95404
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd OdDtl Fail'
            GOTO RollBackTran
         END

         UPDATE dbo.LOADPLANDETAIL WITH (ROWLOCK) SET
            STATUS = '3',
            EditWho = sUser_sName(),
            EditDate = GetDate(),
            TrafficCop = NULL
         WHERE OrderKey = @cOrderKey
         AND STATUS < '5'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 95405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd LpDtl Fail'
            GOTO RollBackTran
         END

         -- Check if pickslip already scan in and not yet insert transmitlog3 then start insert
         -- (if orders.doctype = 'E' then scan in will not fire trigger and hence no transmitlog3 record)
         IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   ScanInDate IS NOT NULL
                     AND   TrafficCop = 'U')
         AND @cOrdType NOT IN ( 'R','S')  -- Move orders no need scaninlog (james02)
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)
                            WHERE TableName = 'ScanInLog'
                            AND   Key1 = @cOrderKey
                            AND   Key3 = @cStorerkey)
            BEGIN
               EXECUTE dbo.nspGetRight
                  @c_Facility    = '',
                  @c_StorerKey   = @cStorerKey,
                  @c_SKU         = '',
                  @c_ConfigKey   = 'ScanInLog',
                  @b_success     = @bSuccess                OUTPUT,
                  @c_authority   = @cAuthority_ScanInLog    OUTPUT,
                  @n_err         = @nErrNo                  OUTPUT,
                  @c_errmsg      = @cErrmsg                 OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 95406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'nspGetRightErr'
                  GOTO RollBackTran
               End

               IF @cAuthority_ScanInLog = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3
                     @c_TableName      = 'ScanInLog',
                     @c_Key1           = @cOrderKey,
                     @c_Key2           = '' ,
                     @c_Key3           = @cStorerKey,
                     @c_TransmitBatch  = '',
                     @b_success        = @bSuccess    OUTPUT,
                     @n_err            = @nErrNo      OUTPUT,
                     @c_errmsg         = @cErrMsg     OUTPUT

                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 95407
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog3 Fail'
                     GOTO RollBackTran
                  End
               END
            END
         END
         
         -- (james02)
         SET @cPreDelNote = rdt.RDTGetConfig( @nFunc, 'PreDelNote', @cStorerKey)  
         IF @cPreDelNote = '0'  
            SET @cPreDelNote = ''     
  
         IF @cECOM_SINGLE_Flag = 'S' AND @cPreDelNote <> ''  
         BEGIN    
            DECLARE @tDELNOTES AS VariableTable    
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)    
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')    
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')    
    
            -- Print label    
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,     
               @cPreDelNote,  -- Report type    
               @tDELNOTES,    -- Report params    
               'rdt_840ExtUpd01',     
               @nErrNo     OUTPUT,    
               @cErrMsg    OUTPUT     
         END    
      END --IN00305915 (end)

      -- (james01)
      IF @nStep = 3
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                         WHERE C.ListName = 'HMORDTYPE'
                         AND   C.Short = 'S'
                         AND   O.OrderKey = @cOrderkey
                         AND   O.StorerKey = @cStorerKey)
         BEGIN
            SET @nExpectedQty = 0
            SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey
            AND   Storerkey = @cStorerkey
            AND   Status < '9'

            SET @nPackedQty = 0
            SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   Storerkey = @cStorerkey

            IF @nExpectedQty = @nPackedQty
            BEGIN
               EXEC [dbo].[isp_AssignPackLabelToOrderByLoad]
                  @c_Pickslipno  = @cPickSlipNo,
                  @b_Success     = @b_Success   OUTPUT,
                  @n_err         = @n_err       OUTPUT,
                  @c_errmsg      = @c_errmsg    OUTPUT

               IF @b_Success <> 1    
               BEGIN    
                  SET @nErrNo = 57661    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Assign Lbl Err'    
                  GOTO RollBackTran    
               END    
            END
         END
      END

      IF @nStep = 4
      BEGIN
         SELECT @cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   [Status] = '9'

         -- After packconfirm only trigger below interface
         IF ISNULL( @cOrderKey, '') = ''
            GOTO Quit

         SELECT @cOrderType = [Type],
                @cShipperKey = ShipperKey,
                @nOriginalQty = ISNULL( SUM( OriginalQty), 0)
         FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey)
         WHERE O.OrderKey = @cOrderKey
         AND   O.StorerKey = @cStorerkey
         GROUP BY [Type], ShipperKey

         SELECT @nPickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   StorerKey = @cStorerkey
         --AND   [Status] = '5'

         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN rdt_840ExtUpd01

         IF @nOriginalQty <> @nPickQty
         BEGIN
            IF @cOrderType = 'COD'
            BEGIN
               -- Retrigger the interface if it exists (james03)
               IF EXISTS ( SELECT 1 FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
                            WHERE tablename = 'WSOrdRecalculate'
                            AND key1 = @cOrderKey
                            AND key2 = ''
                            AND key3 = @cStorerkey)
               BEGIN
                  UPDATE dbo.TRANSMITLOG2 SET
                     transmitflag = '0',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE tablename = 'WSOrdRecalculate'
                  AND key1 = @cOrderKey
                  AND key2 = ''
                  AND key3 = @cStorerkey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 57662
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TriggerTL2 Err'
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  -- Insert transmitlog2 here
                  EXEC ispGenTransmitLog2 'WSOrdRecalculate', @cOrderKey, '', @cStorerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @nErrNo = @n_err
                     SET @cErrMsg = @c_errmsg
                     GOTO RollBackTran
                  END
               END

               UPDATE dbo.Orders WITH (ROWLOCK) SET
                  SOStatus = 'PENDGET',
                  Trafficcop = NULL,      -- (james01)
                  EditDate = GETDATE(),   -- (james01)
                  EditWho = sUSER_sNAME() -- (james01)
               WHERE StorerKey = @cStorerkey
               AND   OrderKey = @cOrderKey
               AND   SOStatus <> 'PENDGET'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 57651
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PGET FAIL'
                  GOTO RollBackTran
               END
            END
            
            ---- (james03)
            --SET @cErrMsg1 = rdt.rdtgetmessage( 57663, @cLangCode, 'DSP') --Orders Short Pick
            
            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1 

            --SET @nErrNo = 0
            --SET @cErrMsg = ''
         END

         -- Only customer order need print below label
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                     WHERE C.ListName = 'HMORDTYPE'
                     AND   C.Short = 'S'
                     AND   O.OrderKey = @cOrderkey
                     AND   O.StorerKey = @cStorerKey)
         BEGIN
            IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                 WHERE StorerKey = @cStorerKey
                 AND   ReportType = 'DELNOTES'
                 AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
                           ELSE 0 END)
            BEGIN
               -- Printing process
               -- Print the delivery notes
               IF ISNULL(@cPaperPrinter, '') = ''
               BEGIN
                  SET @nErrNo = 57652
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
                  GOTO RollBackTran
               END

               SET @cReportType = 'DELNOTES'
               SET @cPrintJobName = 'PRINT_DELIVERYNOTES'

               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')
               FROM RDT.RDTReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType

               IF ISNULL(@cDataWindow, '') = ''
               BEGIN
                  SET @nErrNo = 57653
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
                  GOTO RollBackTran
               END

               IF ISNULL(@cTargetDB, '') = ''
               BEGIN
                  SET @nErrNo = 57654
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
                  GOTO RollBackTran
               END

               SET @nErrNo = 0
               EXEC RDT.rdt_BuiltPrintJob
                  @nMobile,
                  @cStorerKey,
                  'DELNOTES',
                  'PRINT_DELIVERYNOTES',
                  @cDataWindow,
                  @cPaperPrinter,
                  @cTargetDB,
                  @cLangCode,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT,
                  @cOrderKey,
                  ''

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END

            -- If not fully packed then no need print label
            IF @cOrderType = 'COR' AND                            --MT01--
              @nOriginalQty <> @nPickQty
                     GOTO Quit

            IF EXISTS ( SELECT 1
               FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.PackInfo PIF WITH (NOLOCK)
                  ON ( PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo)
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND   EXISTS ( SELECT 1 FROM dbo.CODELKUP CLK WITH (NOLOCK)
                              WHERE PIF.CartonType = CLK.Short
                              AND   CLK.ListName = 'HMCarton'
                              AND   CLK.UDF01= @cShipperKey
                              AND   CLK.UDF02= 'Letter'
                              AND   CLK.StorerKey = @cStorerKey ))
            BEGIN
               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND   ReportType = 'LETTERHM'
                    AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
                              ELSE 0 END)
               BEGIN
                  -- Printing process
                  -- Print the courier label
                  IF ISNULL(@cLabelPrinter, '') = ''
                  BEGIN
                     SET @nErrNo = 57655
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLblPrinter
                     GOTO RollBackTran
                  END

                  SET @cReportType = 'LETTERHM'
                  SET @cPrintJobName = 'PRINT_LETTERHM'

                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     SET @nErrNo = 57656
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
                     GOTO RollBackTran
                  END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     SET @nErrNo = 57657
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
                     GOTO RollBackTran
                  END

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cLabelPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cOrderKey,
                     '',      -- carton no. blank to print all carton label
                     @cShipperKey

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   ReportType = 'SHIPLBLHM'
                     AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
                        ELSE 0 END)
               BEGIN
                  -- Printing process
                  -- Print the courier label
                  IF ISNULL(@cLabelPrinter, '') = ''
                  BEGIN
                     SET @nErrNo = 57658
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLblPrinter
                     GOTO RollBackTran
                  END

                  SET @cReportType = 'SHIPLBLHM'
                  SET @cPrintJobName = 'PRINT_SHIPPLABEL'

                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                           @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = @cReportType

                  IF ISNULL(@cDataWindow, '') = ''
                  BEGIN
                     SET @nErrNo = 57659
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
                     GOTO RollBackTran
                  END

                  IF ISNULL(@cTargetDB, '') = ''
                  BEGIN
                     SET @nErrNo = 57660
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
                     GOTO RollBackTran
                  END

                  SET @nErrNo = 0
                  EXEC RDT.rdt_BuiltPrintJob
                     @nMobile,
                     @cStorerKey,
                     @cReportType,
                     @cPrintJobName,
                     @cDataWindow,
                     @cLabelPrinter,
                     @cTargetDB,
                     @cLangCode,
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     @cStorerKey,
                     @cOrderKey,
                     @nCartonNo,      
                     @cShipperKey

                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END
         END

         SELECT @cCartonType = CartonType
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSliPno
         AND   CartonNo = 1   -- Letter service only 1 carton 
            
         IF EXISTS ( SELECT 1
                     FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE ListName = 'HMCARTON'
                     AND   StorerKey = @cStorerKey
                     AND   Short = @cCartonType
                     AND   UDF01 = @cShipperkey
                     AND   UDF02 = 'LETTER')
         BEGIN
            UPDATE dbo.Orders SET 
               --TrackingNo = UserDefine04  --(WC01)  
               UserDefine04 = TrackingNo  --(WC01)  
            WHERE OrderKey = @cOrderKey
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 57664
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter
               GOTO RollBackTran
            END
         END

      END
   END

   IF @nInputKey = 0
   BEGIN
      IF @nStep = 3
      BEGIN
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.CODELKUP C WITH (NOLOCK)
                         JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                         WHERE C.ListName = 'HMORDTYPE'
                         AND   O.OrderKey = @cOrderkey
                         AND   O.StorerKey = @cStorerKey
                         AND   C.Short = 'S')
            GOTO Quit

         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN rdt_840ExtUpd01

         SET @cPackByTrackNotUpdUPC = ''
         SET @cPackByTrackNotUpdUPC = rdt.RDTGetConfig( @nFunc, 'PackByTrackNotUpdUPC', @cStorerKey)

         IF ISNULL( @cPickSlipNo, '') = ''
            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderkey


         -- 1 orders 1 tracking no
         -- discrete pickslip, 1 ordes 1 pickslipno
         SET @nExpectedQty = 0
         SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
            AND Storerkey = @cStorerkey
            AND Status < '9'

         SET @nPackedQty = 0
         SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND Storerkey = @cStorerkey

         -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton
         IF @nExpectedQty = @nPackedQty
         BEGIN
            SELECT @nCtnCount = ISNULL(COUNT( DISTINCT CartonNo), 0)
            FROM dbo.PackDetail WITH ( NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo

            IF @nCtnCount > 0
            BEGIN
               DECLARE CUR_PACKDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT CartonNo FROM dbo.PackDetail WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
               ORDER BY CartonNo
               OPEN CUR_PACKDTL
               FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  -- Generateorder box barcode
                  SET @cTempBarcode = ''
                  SET @cTempBarcode = '021'
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RTRIM(@cOrderKey)
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '00' + CAST( @nCtnNo AS NVARCHAR( 2)), 2)
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + RIGHT( '000' + CAST( @nCtnCount AS NVARCHAR( 3)), 3)
                  SET @cTempBarcode = RTRIM(@cTempBarcode) + '1'
                  SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcode), 0)
                  SET @cOrderBoxBarcode = RTRIM(@cTempBarcode) + @cCheckDigit

                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET
                     UPC = CASE WHEN @cPackByTrackNotUpdUPC = '1' THEN UPC ELSE @cOrderBoxBarcode END,
                     ArchiveCop = NULL,
                     EditWho = 'rdt.' + sUser_sName(),
                     EditDate = GETDATE()
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCtnNo

                  IF @@ERROR <> 0
                  BEGIN
                     CLOSE CUR_PACKDTL
                     DEALLOCATE CUR_PACKDTL

                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo
               END
               CLOSE CUR_PACKDTL
               DEALLOCATE CUR_PACKDTL
               /*
               -- Trigger pack confirm
               UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                  STATUS = '9',
                  EditWho = 'rdt.' + sUser_sName(),
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
               AND   [STATUS] <> '9'

               IF @@ERROR <> 0
                  GOTO RollBackTran
               */
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_840ExtUpd01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

GO