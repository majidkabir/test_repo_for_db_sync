SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtMetaPackC23Reprn                                    */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author   Purposes                                       */  
/* 2014-09-07 1.0  James    SOS317664 Created                              */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtMetaPackC23Reprn] (  
   @nMobile    INT,  
   @nFunc      INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @cStorerKey NVARCHAR( 15),  
   @cOption    NVARCHAR( 1),  
   @cParam1    NVARCHAR(20),  -- OrderKey  
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),    
   @cParam4    NVARCHAR(20),  
   @cParam5    NVARCHAR(20),  
   @nErrNo     INT OUTPUT,  
   @cErrMsg    NVARCHAR( 20) OUTPUT  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
  
   DECLARE @b_Success     INT  
     
   DECLARE @cDataWindow       NVARCHAR( 50)  
          ,@cTargetDB         NVARCHAR( 20)  
          ,@cLabelPrinter     NVARCHAR( 10)  
          ,@cPrinter_Paper    NVARCHAR( 10)  
          ,@cIncoTerm         NVARCHAR( 10)  
          ,@cOrderKey         NVARCHAR( 10) 
          ,@cPickSlipNo       NVARCHAR( 10) 
          ,@nCartonNo         INT  
          ,@cLabelNo          NVARCHAR( 20) 
          ,@cReportType       NVARCHAR( 10)  
          ,@cPrintJobName     NVARCHAR( 50) 
          ,@cDocumentFilePath NVARCHAR( 1000) 
          ,@cFileName         NVARCHAR( 100)      
          ,@cPrintFileName    NVARCHAR( 500)      
          ,@cFilePath         NVARCHAR( 1000)     
          ,@nFileExists       INT            
          ,@bSuccess          INT 
          ,@cPrintFilePath    NVARCHAR( 1000) 
          ,@nReturnCode       INT  
          ,@cCMD              NVARCHAR(1000) 
          ,@cToteNo           NVARCHAR( 18) 

   DECLARE @tCMDError TABLE( ErrMsg NVARCHAR(250))  -- james08 

   SELECT @cFilePath = Long, @cPrintFilePath = Notes 
   FROM dbo.CODELKUP WITH (NOLOCK)  
   WHERE LISTNAME = 'Metapack'  
   AND   Code = 'PDFPrint'
   AND   StorerKey = @cStorerKey 
      
   SET @cOrderKey = ''
   SET @cToteNo = ''

   SET @cOrderKey = @cParam1
   SET @cToteNo = @cParam2

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cToteNo, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'Value Required'
      GOTO Quit  
   END

   -- Get printer info  
   SELECT @cPrinter_Paper = Printer_Paper  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   IF ISNULL( @cPrinter_Paper, '') = ''
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'A4 Prnter Req'
      GOTO Quit  
   END

   IF ISNULL( @cOrderKey, '') = ''
   BEGIN
      SELECT TOP 1 @cOrderKey = PD.OrderKey 
      FROM dbo.PickDetail PD  WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.DropID = @cToteNo
      AND   PD.[Status] = '5'
      AND   O.UserDefine05 <> '' --ECOMM
   END

   -- To ToteNo value must not blank
   IF ISNULL( @cOrderKey, '') = '' 
   BEGIN
      SET @nErrNo = 1  
      SET @cErrMsg = 'No OrderKey Found'
      GOTO Quit  
   END

   SELECT @cIncoTerm = IncoTerm FROM dbo.Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderkey

   SELECT @cPickSlipNo = PickSlipno 
   FROM dbo.PackHeader WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   -- Skip printing is incoterm = 'CC'
   IF @cIncoTerm <> 'CC'
   BEGIN
      /********************************  
         CALL METAPACK & PRINT C23 DOC   
      *********************************/ 
      DECLARE CUR_PRINT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT DISTINCT LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   PickSlipNo = @cPickSlipno
      ORDER BY 1
      OPEN CUR_PRINT
      FETCH NEXT FROM CUR_PRINT INTO @cLabelNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         -- Print C23 doc (if exists)
         SET @cFileName = 'C23_' + RTRIM( @cLabelNo) + '.pdf' 
         SET @cPrintFileName = RTRIM( @cFilePath) + '\' + 'C23_' + RTRIM( @cLabelNo) + '.pdf' 
         EXEC isp_FileExists @cPrintFileName, @nFileExists OUTPUT, @bSuccess OUTPUT
         IF @nFileExists = 1
         BEGIN
            SET @nReturnCode = 0  
            SET @cCMD = '""' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinter_Paper + '"'  
--            INSERT INTO CMDError (ErrMsg) VALUES (@cCMD)
            INSERT INTO @tCMDError  
            EXEC @nReturnCode = xp_cmdshell @cCMD  
            IF @nReturnCode <> 0  
            BEGIN  
               SET @cErrMsg = 'PRINT C23 FAIL'          
               BREAK       
            END  
         END
         ELSE
         BEGIN  
            SET @cErrMsg = 'C23 DOC NOT EXISTS'          
            BREAK       
         END  
         FETCH NEXT FROM CUR_PRINT INTO @cLabelNo
      END
      CLOSE CUR_PRINT
      DEALLOCATE CUR_PRINT
   END


Quit:  

GO