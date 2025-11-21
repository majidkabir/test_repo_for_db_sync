SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_867ExtUpdSP04                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_PickByTrackNo                                    */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2021-08-12   1.0  yeekung  WMS-17055. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_867ExtUpdSP04] (
   @nMobile        INT,
   @nFunc          INT,
   @nStep          INT, 
   @cLangCode      NVARCHAR( 3), 
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @cOrderKey      NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cTracKNo       NVARCHAR( 18),
   @cSerialNo      NVARCHAR( 30),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @bSuccess       INT
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nQty           INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @cPSType        NVARCHAR( 10)
   DECLARE @cSKUStatus     NVARCHAR( 10) = ''
   DECLARE @cPickFilter    NVARCHAR( MAX) = ''
   DECLARE @nSKUCnt        INT
   DECLARE @nSum_Picked    INT = 0
   DECLARE @nSum_Packed    INT = 0
   DECLARE @cPackDetailCartonID  NVARCHAR( 20)  
   DECLARE @nCartonNo      INT
   DECLARE @nInputKey      INT
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)  
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cOrderType     NVARCHAR( 1)
   DECLARE @cShipLabel     NVARCHAR( 1)
   DECLARE @cDelNotes         NVARCHAR( 10)
   DECLARE @cTrackingNo       NVARCHAR( 30)
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)    
   DECLARE @cLabelPrinter     NVARCHAR(10)  
   DECLARE @cPaperPrinter     NVARCHAR(10)  
   DECLARE @cOption           NVARCHAR( 1)
          
   SET @nErrNo = 0

   SELECT @nInputKey = InputKey,
          @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,
          @cOption = I_Field01
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_867ExtUpdSP04
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         
         SELECT @cLoadKey=LoadKey,
                @cShipperKey=ShipperKey
         FROM dbo.ORDERS (NOLOCK)
         WHERE orderkey=@cOrderKey

        DECLARE @tSHIPPLABEL VariableTable
        
        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',    @cshipperkey) 
        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadkey',       @cLoadkey) 
        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cTrackNo',       @cTrackNo) 
        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',      @cOrderKey)  

        SET @cReportType='SHIPPLABEL'

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter, 
            @cReportType, -- Report type
            @tSHIPPLABEL, -- Report params
            'rdt_867ExtUpdSP04', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT,
            '1',
            '' 
      END
   END


   COMMIT TRAN rdt_867ExtUpdSP04  
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_867ExtUpdSP04  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

   Fail:
END

GO