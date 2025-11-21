SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840ExtPrint03                                   */
/* Purpose: Print label after pick = pack                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-05-15 1.0  James      WMS1446. Created                          */
/* 2017-10-26 1.1  James      Move printing label out from transaction  */
/*                            block (james01)                           */
/* 2020-02-24 1.2  Leong      INC1049672 - Revise BT Cmd parameters.    */
/* 2020-04-01 1.3  James      WMS-12757 Skip print ship label if it is a*/  
/*                            Move orders (james02)                     */  
/* 2021-01-27 1.4  James      WMS-16145 Add carton label print (james03)*/
/* 2021-11-01 1.5  YeeKung    WMSS-17797 change rdt_BuiltPrintJob to    */ 
/*                            rdt_print  (yeekung01)                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtPrint03] (
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
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @cReportType       NVARCHAR( 10),
           @cPrintJobName     NVARCHAR( 50),
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cUPCCode          NVARCHAR( 10),
           @cTempBarcode      NVARCHAR( 20),
           @cOrderBoxBarcode  NVARCHAR( 20),
           @cCheckDigit       NVARCHAR( 1),
           @cUserName         NVARCHAR( 18),
           @cPriority         NVARCHAR( 10),
           @cLoadKey          NVARCHAR( 10),
           @cShipperKey       NVARCHAR( 10),
           @bDebug            INT,
           @nExpectedQty      INT,
           @nPackedQty        INT,
           @nCtnCount         INT,
           @nCtnNo            INT,
           @nIsMoveOrders     INT = 0,
           @cCartonLabel      NVARCHAR( 10),
           @cFacility         NVARCHAR( 5)             

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName,
          @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE  @cPackByTrackNotUpdUPC    NVARCHAR(1)

   SET @cPackByTrackNotUpdUPC = ''
   SET @cPackByTrackNotUpdUPC = rdt.RDTGetConfig( @nFunc, 'PackByTrackNotUpdUPC', @cStorerKey)

   SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),  
          @cShipperKey = ISNULL(RTRIM(ShipperKey), '')  
   FROM dbo.Orders WITH (NOLOCK)  
   WHERE Storerkey = @cStorerkey  
   AND   Orderkey = @cOrderkey  

   -- If it is a Move type orders then no need print ship label    
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
               JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
               WHERE C.ListName = 'HMORDTYPE'    
               AND   C.UDF01 = 'M'    
               AND   O.OrderKey = @cOrderkey    
               AND   O.StorerKey = @cStorerKey)    
      SET @nIsMoveOrders = 1     

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
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
            /*
            Order box barcode: 20 digits, Code 128 barcode codification, divided into 5 blocks:
            3 digits: Hardcode æ021Æ.
            12 digits: Orders.OrderKey (10digits) + Current CartonNo (2 digits, e.g. 01, 02à)
            3 digits: Total carton box in the order (e.g. 002)
            1 digit: Hardcode æ1Æ
            1 digit: BarcodeÆs check digit, refer to the below java code.
            */

            SELECT @nCtnCount = ISNULL(COUNT( DISTINCT CartonNo), 0)
            FROM dbo.PackDetail WITH ( NOLOCK)
            WHERE Storerkey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo

            IF @nCtnCount > 0
            BEGIN
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_840ExtPrint03 -- For rollback or commit only our own transaction

               DECLARE CUR_PACKDTL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT CartonNo FROM dbo.PackDetail WITH (NOLOCK)
               WHERE Storerkey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
               ORDER BY CartonNo
               OPEN CUR_PACKDTL
               FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @cUPCCode = ''
                  SELECT @cUPCCode = Code FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'WHUPCCODE'
                  AND   StorerKey = @cStorerKey

                  -- Generateorder box barcode
                  SET @cTempBarcode = ''
                  SET @cTempBarcode = CASE WHEN ISNULL( @cUPCCode, '') = '' THEN '021' ELSE RTRIM( @cUPCCode) END
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
                     SET @nErrNo = 109001
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD BOX Failed'
                     CLOSE CUR_PACKDTL
                     DEALLOCATE CUR_PACKDTL
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM CUR_PACKDTL INTO @nCtnNo
               END
               CLOSE CUR_PACKDTL
               DEALLOCATE CUR_PACKDTL

               GOTO CommitTrans

               RollBackTran:
                  ROLLBACK TRAN rdt_840ExtPrint03
               CommitTrans:
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                     COMMIT TRAN

               -- Print only if rdt report is setup (james05)
               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
                          WHERE StorerKey = @cStorerKey
                          AND   ReportType = 'ORDERLABEL'
                          AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
                                    ELSE 0 END)
               BEGIN
                  -- If Orders.Priority ='4', then need to print the order box label,
                  -- if Orders.Priority ='1' or '2' or '3', then do not print order box label.
                  -- For A5 report, all orders need to print this report.
                  SET @cPriority = ''
                  SELECT @cPriority = Priority
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   OrderKey = @cOrderKey

                  IF ISNULL(@cPriority, '') = '4'
                  BEGIN
                     -- Print the label
                     IF ISNULL(@cLabelPrinter, '') = ''
                     BEGIN
                        SET @nErrNo = 109011
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
                        GOTO Quit
                     END

                     -- If label setup in bartender then skip printing using rdtspooler (james06)
                     IF NOT EXISTS ( SELECT 1 FROM dbo.BartenderLabelCfg WITH (NOLOCK)
                                     WHERE StorerKey = @cStorerKey
                                     AND   LabelType = 'BOXLABEL')
                     BEGIN
                        SET @cReportType = 'ORDERLABEL'
                        SET @cPrintJobName = 'PRINT_ORDERLABEL'

                        SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                               @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                        FROM RDT.RDTReport WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   ReportType = @cReportType

                        IF ISNULL(@cDataWindow, '') = ''
                        BEGIN
                           SET @nErrNo = 109012
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP
                           GOTO Quit
                        END

                        IF ISNULL(@cTargetDB, '') = ''
                        BEGIN
                           SET @nErrNo = 109013
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET
                           GOTO Quit
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
                           @cOrderKey

                        IF @nErrNo <> 0
                           GOTO Quit
                     END
                     ELSE
                     BEGIN
                        -- Call Bartender standard SP
                        EXECUTE dbo.isp_BT_GenBartenderCommand
                           @cPrinterID     = @cLabelPrinter,-- printer id
                           @c_LabelType    = 'BOXLABEL',    -- label type
                           @c_userid       = @cUserName,    -- user id
                           @c_Parm01       = @cStorerKey,   -- parm01
                           @c_Parm02       = @cOrderKey,    -- parm02
                           @c_Parm03       = '',            -- parm03
                           @c_Parm04       = '',            -- parm04
                           @c_Parm05       = '',            -- parm05
                           @c_Parm06       = '',            -- parm06
                           @c_Parm07       = '',            -- parm07
                           @c_Parm08       = '',            -- parm08
                           @c_Parm09       = '',            -- parm09
                           @c_Parm10       = '',            -- parm10
                           @c_StorerKey    = @cStorerKey,   -- StorerKey
                           @c_NoCopy       = '1',           -- no of copy
                           @b_Debug        = @bDebug,
                           @c_Returnresult = '',            -- return result
                           @n_err          = @nErrNo        OUTPUT,
                           @c_errmsg       = @cErrMsg       OUTPUT

                        IF @nErrNo <> 0
                        BEGIN
                           SET @nErrNo = 109014
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSERTPRTFAIL
                           GOTO Quit
                        END
                     END   -- end print
                  END
               END

               IF @nIsMoveOrders = 0   -- (james02)  
               BEGIN  
	               -- Print only if rdt report is setup (james08)
	               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
	                          WHERE StorerKey = @cStorerKey
	                          AND   ReportType = 'SHIPPLABEL'
	                          AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
	                                                        ELSE 0 END)
	               BEGIN
	                  SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),
	                         @cShipperKey = ISNULL(RTRIM(ShipperKey), '')
	                  FROM dbo.Orders WITH (NOLOCK)
	                  WHERE Storerkey = @cStorerkey
	                  AND   Orderkey = @cOrderkey

	                  IF ISNULL( @cShipperKey, '') = ''
	                  BEGIN
	                     SET @nErrNo = 109015
	                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY
	                     GOTO Quit
	                  END

                      --(yeekung01)
                     DECLARE @tSHIPPLABEL VariableTable
                     SET @cReportType = 'SHIPPLABEL'  

                     INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',    @cshipperkey) 
                     INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadkey',       @cLoadkey) 
                     INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',      @cOrderKey)  

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, '1', @cFacility, @cStorerkey, @clabelPrinter, @cPaperPrinter, 
                        @cReportType, -- Report type
                        @tSHIPPLABEL, -- Report params
                        'rdt_840ExtPrint03', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT,
                        '1',
                        ''

	                  IF @nErrNo <> 0
	                     GOTO Quit
	               END

	               -- Print only if rdt report is setup (james21)
	               IF EXISTS (SELECT 1 FROM RDT.RDTReport WITH (NOLOCK)
	                          WHERE StorerKey = @cStorerKey
	                          AND   ReportType = 'SHIPPLBLSP'
	                          AND   1 = CASE WHEN Function_ID = @nFunc OR Function_ID = 0 THEN 1
	                                                        ELSE 0 END)
	               BEGIN
	                  SELECT @cLoadKey = ISNULL(RTRIM(LoadKey), ''),
	                         @cShipperKey = ISNULL(RTRIM(ShipperKey), '')
	                  FROM dbo.Orders WITH (NOLOCK)
	                  WHERE Storerkey = @cStorerkey
	                  AND   Orderkey = @cOrderkey

	                  IF ISNULL( @cShipperKey, '') = ''
	                  BEGIN
	                     SET @nErrNo = 109016
	                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV SHIPPERKEY
	                     GOTO Quit
	                  END

	                  SET @cReportType = 'SHIPPLBLSP'
	                  SET @cPrintJobName = 'PRINT_SHIPPLBLSP'

	                  SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
	                         @cTargetDB = ISNULL(RTRIM(TargetDB), '')
	                  FROM RDT.RDTReport WITH (NOLOCK)
	                  WHERE StorerKey = @cStorerkey
	                  AND ReportType = @cReportType

	                  SET @nErrNo = 0
	                  EXEC RDT.rdt_BuiltPrintJob
	                     @nMobile,
	                     @cStorerKey,
	                     'SHIPPLBLSP',
	                     'PRINT_SHIPPLBLSP',
	                     @cDataWindow,
	                     @cLabelPrinter,
	                     @cTargetDB,
	                     @cLangCode,
	                     @nErrNo  OUTPUT,
	                     @cErrMsg OUTPUT,
	                     @cLoadKey,
	                     @cOrderKey,
	                     @cShipperKey,
	                     0

	                  IF @nErrNo <> 0
	                     GOTO Quit
	               END
               END   -- @nIsMoveOrders = 0  
            END
         END
      END   -- IF @nStep = 3
      
      -- (james03)
      IF @nStep = 4
      BEGIN
         IF @nIsMoveOrders = 1
         BEGIN
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerKey)
            IF @cCartonLabel = '0'
               SET @cCartonLabel = ''

            IF @cCartonLabel <> ''
            BEGIN
               DECLARE @tCartonLabel AS VariableTable
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)  
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)     
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)    

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
                  @cCartonLabel, -- Report type
                  @tCartonLabel, -- Report params
                  'rdt_840ExtPrint03', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 
            END
         END
      END
   END   -- @nInputKey = 1

Quit:

GO