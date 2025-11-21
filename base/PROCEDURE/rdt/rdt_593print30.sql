SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593Print30                                            */
/* Copyright      : LF                                                        */
/*                                                                            */
/* Purpose: Print PDF                                                         */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Rev  Author   Purposes                                         */
/* 2020-09-14  1.0  James    WMS-15082. Created                               */
/* 2020-10-01  1.1  James    WMS-15359 Add option 10 (james01)                */
/* 2022-01-27  1.2  Ung      WMS-18850 Support PDF ship label under option 5  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_593Print30] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2),
   @cParam1    NVARCHAR(20),  -- StorerKey
   @cParam2    NVARCHAR(20),  -- OrderKey
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter     NVARCHAR( 10)
   DECLARE @cLabelNo          NVARCHAR( 20)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cShipLabel        NVARCHAR( 10)
   DECLARE @nInputKey         INT
   DECLARE @cPalletKey        NVARCHAR( 10)
   DECLARE @cMbolKey          NVARCHAR( 10)
   DECLARE @cContainerKey     NVARCHAR( 10)
   DECLARE @cMbolStatus       NVARCHAR( 10)
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

   SELECT @cLabelPrinter = Printer, 
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility, 
          @nInputKey = InputKey
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @cOption IN ('5', '9')
   BEGIN
      DECLARE @cOrderKey NVARCHAR( 10)
      DECLARE @cCartonNo NVARCHAR( 5)

      -- Param mapping
      SET @cOrderKey = @cParam1
      SET @cCartonNo = @cParam2

      -- Check orderkey
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 158951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need orderkey
         GOTO Quit
      END

      -- Check carton no
      IF @cCartonNo = ''
         SET @cCartonNo = '1'

      -- Check orderkey validity
      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND OrderKey = @cOrderKey

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 158952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OrderKey
         GOTO Quit
      END

      SELECT @cLabelNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND   CartonNo = CAST( @cCartonNo AS INT)

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 158953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv cartonno
         GOTO Quit
      END

      IF @cOption = '9'
      BEGIN
         DECLARE @tReturnLabel AS VariableTable
         INSERT INTO @tReturnLabel (Variable, Value) VALUES
            ( '@cPickSlipNo', @cPickSlipNo),
            ( '@cOrderKey',   @cOrderKey),
            ( '@cLabelNo',    @cLabelNo),
            ( '@cCartonNo',   @cCartonNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',
            'RTNLABEL', -- Report type
            @tReturnLabel, -- Report params
            'rdt_593Print30',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      IF @cOption = '5'
      BEGIN
         -- Get order info
         DECLARE @cShipperKey NVARCHAR( 15)
         SELECT @cShipperKey = ISNULL( ShipperKey, '')
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         -- Determine shipper label format
         DECLARE @cLabelFormat NVARCHAR( 10) = ''
         SELECT @cLabelFormat = ISNULL( Short, '')
         FROM dbo.CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'SHPLBLTYPE'
            AND Code = @cShipperKey
            AND StorerKey = @cStorerKey

         DECLARE @tShipLabel AS VariableTable
         INSERT INTO @tShipLabel (Variable, Value) VALUES
            ( '@cPickSlipNo', @cPickSlipNo),
            ( '@cOrderKey',   @cOrderKey),
            ( '@cLabelNo',    @cLabelNo),
            ( '@cCartonNo',   @cCartonNo)

         IF @cLabelFormat IN ('ZPL', '')
         BEGIN
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',
               'SHIPZPLLBL', -- Report type
               @tShipLabel, -- Report params
               'rdt_593Print30',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         IF @cLabelFormat = 'PDF'
         BEGIN
            SELECT
               @cFilePath = Long,
               @cPrintFilePath = Notes,
               @cReportType = Code2,
               @cFilePrefix = UDF01
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'PrtbyShipK'
            AND   Code = 'SHIPLBLPDF'
            AND   StorerKey = @cStorerKey

            SELECT @cWinPrinter = WinPrinter
            FROM rdt.rdtPrinter WITH (NOLOCK)
            WHERE PrinterID = @cLabelPrinter

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
               SET @nErrNo = 158956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath
               GOTO Quit
            END

            -- Build print command
            SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
            SET @cFileName = LTRIM( RTRIM( @cFilePrefix)) + LTRIM( RTRIM( @cLabelNo)) + '_' + @cOrderKey + '.pdf'
            SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "19" "2" "' + @cWinPrinterName + '"'

            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cReportType,  -- Report type
               @tShipLabel,   -- Report params
               'rdt_593Print34',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               1,
               @cPrintCommand
         END
      END
   END

   IF @cOption = '10'
   BEGIN
      DECLARE @tPalletKey TABLE      
      (      
         PalletKey NVARCHAR( 10) NOT NULL
         PRIMARY KEY CLUSTERED (PalletKey)      
      )      

      SET @cPalletKey = @cParam1 
      SET @cMbolKey = @cParam2 
      SET @cContainerKey = @cParam3 

      IF @cPalletKey <> ''
         INSERT INTO @tPalletKey (PalletKey) VALUES (@cPalletKey)

      IF @cMbolKey <> ''
         INSERT INTO @tPalletKey (PalletKey) 
         SELECT DISTINCT ExternMbolKey
         FROM dbo.MBOL WITH (NOLOCK)
         WHERE MbolKey = @cMbolKey

      IF @cContainerKey <> ''
      BEGIN
         INSERT INTO @tPalletKey (PalletKey)
         SELECT DISTINCT CD.PalletKey
         FROM dbo.CONTAINERDETAIL CD WITH (NOLOCK)
         JOIN dbo.CONTAINER C WITH (NOLOCK) ON ( CD.ContainerKey = C.ContainerKey)
         WHERE CD.ContainerKey = @cContainerKey
      END

      SELECT @cMbolStatus = MIN( M.[Status])
      FROM dbo.MBOL M WITH (NOLOCK)
      JOIN @tPalletKey P ON ( M.ExternMbolKey = P.PalletKey)

      IF @cMbolStatus < '5'
      BEGIN
         SET @nErrNo = 158954     
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PTL No Manifest    
         GOTO Quit    
      END

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
            SET @nErrNo = 158955     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup FilePath    
            GOTO Quit   
         END

         DECLARE @tRDTPrintJob AS VariableTable
         DECLARE @curPrintMbol   CURSOR
         SET @curPrintMbol = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT MbolKey
         FROM dbo.MBOL M WITH (NOLOCK)
         JOIN @tPalletKey P ON ( M.ExternMbolKey = P.PalletKey)
         WHERE M.[Status] BETWEEN '5' AND '8'
         AND   (( @cMbolKey <> '' AND M.MbolKey = @cMbolKey) OR ( M.MbolKey = M.MbolKey))
         ORDER BY 1
         OPEN @curPrintMbol
         FETCH NEXT FROM @curPrintMbol INTO @cMbolKey2Print
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE FROM @tRDTPrintJob
            SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
            SET @cFileName = @cFilePrefix + RTRIM( @cMBOLKey2Print) + '.pdf'     
            SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cFilePath + '\' + @cFileName + '" "19" "2" "' + @cWinPrinterName + '"'                              

            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
               @cReportType,     -- Report type
               @tRDTPrintJob,    -- Report params
               'rdt_593Print30', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               1,
               @cPrintCommand
                     
            FETCH NEXT FROM @curPrintMbol INTO @cMBOLKey2Print
         END
      END
   END
   
   Quit:
END


GO