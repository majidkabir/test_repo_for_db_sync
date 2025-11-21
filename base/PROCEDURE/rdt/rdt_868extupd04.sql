SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_868ExtUpd04                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Purpose: Print pdf file                                              */
/*                                                                      */
/* Called from: rdtfnc_PickAndPack                                      */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-05-14 1.0  James      WMS-13125. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd04] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess          INT
   DECLARE @cDocType          NVARCHAR( 1)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cTrackingNo       NVARCHAR( 30)
   DECLARE @cShipperKey       NVARCHAR( 15)
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cPrinterName      NVARCHAR(100)   
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cFileName         NVARCHAR( 50)    

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 3 -- Pick completed
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Must have orderkey
            IF ISNULL( @cOrderKey, '') = ''
            BEGIN
               SET @nErrNo = 152201     
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need OrderKey    
               GOTO Quit    
            END
            
             -- Check orderkey validity
            SELECT @cShipperKey = ShipperKey,
                   @cTrackingNo = TrackingNo,
                   @cLoadkey = LoadKey,
                   @cDocType = DocType      
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey

            IF @cTrackingNo <> '' AND @cShipperKey = 'QTS' AND @cDocType = 'E' 
            BEGIN
               SET @cPickSlipNo = ''  
               SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

               IF @cPickSlipNo = ''  
                  SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey  

               IF ISNULL( @cPickSlipNo, '') = ''
               BEGIN
                  SET @nErrNo = 152202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --PickSlip req
                  GOTO Quit  
               END

               IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                               WHERE PickSlipNo = @cPickSlipNo
                               AND   [Status] = '9')
               --BEGIN
               --   SET @nErrNo = 152203     
               --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not PackCfm    
                  GOTO Quit    
               --END
               
               SELECT @cLabelPrinter = Printer
               FROM rdt.rdtMobrec WITH (NOLOCK)
               WHERE Mobile = @nMobile

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 152204     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Lbl Printer    
                  GOTO Quit    
               END

               SELECT @cWinPrinter = WinPrinter
               FROM rdt.rdtPrinter WITH (NOLOCK)  
               WHERE PrinterID = @cLabelPrinter

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 152205     
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No WinPrinter    
                  GOTO Quit    
               END
                  
               DECLARE @cur_Print CURSOR 
               SET @cur_Print = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT Long, Notes, Code2, UDF01
               FROM dbo.CODELKUP WITH (NOLOCK)      
               WHERE LISTNAME = 'PrtbyShipK'      
               AND   Code = @cShipperKey
               AND   StorerKey = @cStorerKey
               ORDER BY Code
               OPEN @cur_Print
               FETCH NEXT FROM @cur_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF CHARINDEX(',' , @cWinPrinter) > 0 
                     SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )    
                  ELSE
                     SET @cWinPrinterName = @cWinPrinter

                  IF ISNULL( @cFilePath, '') = ''    
                  BEGIN    
                     SET @nErrNo = 152206     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
                     GOTO Quit   
                  END

                  SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
                  SET @cFileName = @cFilePrefix + RTRIM( @cTrackingNo) + '.pdf'     
                  SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "0" "3" "' + @cWinPrinterName + '"'                              

                  DECLARE @tRDTPrintJob AS VariableTable
      
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                     @cReportType,     -- Report type
                     @tRDTPrintJob,    -- Report params
                     'rdt_868ExtUpd04', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT,
                     1,
                     @cPrintCommand

	               IF @nErrNo <> 0
                     BREAK

                  FETCH NEXT FROM @cur_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
               END
            END
         END
      END
   END
Quit:
Fail:

GO