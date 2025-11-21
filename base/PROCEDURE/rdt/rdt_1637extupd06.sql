SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd06                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-08-06 1.0  James      WMS-14252 Created                         */  
/* 2021-03-08 1.1  James      Fix the wrong script structure (james01)  */
/* 2021-08-16 1.1  James      When validate mbol set cbolkey=0 (james02)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtUpd06] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 18), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @bReturnCode    INT
   DECLARE @nCBOLKey       BIGINT
   DECLARE @cCallFrom      NVARCHAR( 30)
   DECLARE @cExternMbolKey NVARCHAR( 30)
   DECLARE @curUpdMbol     CURSOR
   DECLARE @cFilePath         NVARCHAR(100)       
   DECLARE @cPrintFilePath    NVARCHAR(100)      
   DECLARE @cPrintCommand     NVARCHAR(MAX)    
   DECLARE @cReportType       NVARCHAR( 10)
   DECLARE @cFilePrefix       NVARCHAR( 30)
   DECLARE @cPaperPrinter     NVARCHAR( 10)  
   DECLARE @cWinPrinter       NVARCHAR(128)  
   DECLARE @cPrinterName      NVARCHAR(100)   
   DECLARE @cWinPrinterName   NVARCHAR(100)   
   DECLARE @cMBOLKey2Print    NVARCHAR(100)
   DECLARE @cFileName         NVARCHAR( 50)    
   
   SET @nErrNo = 0
   
   IF @nFunc = 1637 -- Scan to container
   BEGIN
      IF @nStep = 6 -- Close Container
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption = '1'
            BEGIN
               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN
               SAVE TRAN rdt_1637ExtUpd06
               
               SET @curUpdMbol = CURSOR FOR  
               SELECT DISTINCT MBOL.MbolKey, MBOL.ExternMbolKey
               FROM dbo.MBOL MBOL WITH (NOLOCK)
               WHERE MBOL.[Status] = '5'
               AND   EXISTS ( SELECT 1 FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)
                              WHERE MBOL.ExternMbolKey = CD.PalletKey
                              AND   CD.ContainerKey = @cContainerKey) 
               ORDER BY 1
               OPEN @curUpdMbol
               FETCH NEXT FROM @curUpdMbol INTO @cMBOLKey, @cExternMbolKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @bReturnCode = 0
                  EXEC [dbo].[isp_ValidateMBOL]          
                     @c_MBOLKey = @cMBOLKey,          
                     @b_ReturnCode = @bReturnCode  OUTPUT, -- 0 = OK, -1 = Error, 1 = Warning          
                     @n_err        = @nErrNo       OUTPUT,          
                     @c_errmsg     = @cErrMsg      OUTPUT,   
                     @n_CBOLKey    = 0,-- (james02)        
                     @c_CallFrom   = ''

                  IF @bReturnCode <> 0
                  BEGIN        
                     SET @nErrNo = 156701        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ValidateMBOLEr    
                     GOTO RollBackTran  
                  END 

                  UPDATE dbo.Mbol SET 
                     [Status] = '7', 
                     ValidatedFlag = 'Y',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE MbolKey = @cMBOLKey
                  
                  IF @@ERROR <> 0
                  BEGIN        
                     SET @nErrNo = 156702        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Ship Fail    
                     GOTO RollBackTran  
                  END 
                  
                  IF EXISTS ( SELECT 1 FROM dbo.PALLET WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND [Status] = '5')
                  BEGIN
                     UPDATE dbo.Pallet SET 
                        [Status] = '9',
                        EditDate = GETDATE(),
                        EditWho = SUSER_SNAME()
                     WHERE PalletKey = @cExternMbolKey
                  
                     IF @@ERROR <> 0
                     BEGIN        
                        SET @nErrNo = 156703        
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Ship Fail    
                        GOTO RollBackTran  
                     END 
                  END

                  FETCH NEXT FROM @curUpdMbol INTO @cMBOLKey, @cExternMbolKey
               END
               
               GOTO Quit

               RollBackTran:  
                     ROLLBACK TRAN rdt_1637ExtUpd06  
               Quit:  
                  WHILE @@TRANCOUNT > @nTranCount  
                     COMMIT TRAN  

               IF @nErrNo <> 0
                  GOTO FAIL

               SELECT @cFilePath = Long, 
               @cPrintFilePath = Notes, 
               @cReportType = Code2, 
               @cFilePrefix = UDF01
               FROM dbo.CODELKUP WITH (NOLOCK)      
               WHERE LISTNAME = 'PrtbyShipK'      
               AND   Code = 'MBOLPDF' 
               AND   StorerKey = @cStorerKey
   
               IF @@ROWCOUNT > 0
               BEGIN
                  SELECT @cPaperPrinter = Printer_Paper
                  FROM RDT.RDTMOBREC WITH (NOLOCK)
                  WHERE Mobile = @nMobile

                  SELECT @cWinPrinter = WinPrinter
                  FROM rdt.rdtPrinter WITH (NOLOCK)  
                  WHERE PrinterID = @cPaperPrinter
                  
                  IF CHARINDEX(',' , @cWinPrinter) > 0 
                  BEGIN
                     SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )    
                     SET @cWinPrinterName = @cPrinterName
                  END
                  ELSE
                  BEGIN
                     SET @cWinPrinterName = @cWinPrinter
                  END

                  IF ISNULL( @cFilePath, '') = ''    
                  BEGIN    
                     SET @nErrNo = 156704     
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
                     GOTO FAIL   
                  END

                  DECLARE @tRDTPrintJob AS VariableTable
                  DECLARE @curPrintMbol   CURSOR
                  SET @curPrintMbol = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT MbolKey 
                  FROM dbo.MBOL M WITH (NOLOCK)
                  WHERE EXISTS( SELECT 1 
                                FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)
                                WHERE ContainerKey = @cContainerKey
                                AND   M.ExternMbolKey = CD.PalletKey)
                  ORDER BY 1
                  OPEN @curPrintMbol
                  FETCH NEXT FROM @curPrintMbol INTO @cMBOLKey2Print
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     DELETE FROM @tRDTPrintJob
                     SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
                     SET @cFileName = @cFilePrefix + RTRIM( @cMBOLKey2Print) + '.pdf'     
                     SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "19" "2" "' + @cWinPrinterName + '"'                              

                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                        @cReportType,     -- Report type
                        @tRDTPrintJob,    -- Report params
                        'rdt_1637ExtUpd06', 
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT,
                        1,
                        @cPrintCommand
                     
                     FETCH NEXT FROM @curPrintMbol INTO @cMBOLKey2Print
                  END
               END
            END
         END
      END
   END
   
   FAIL:
   

GO