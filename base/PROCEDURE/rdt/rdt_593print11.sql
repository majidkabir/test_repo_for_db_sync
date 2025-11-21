SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593Print11                                         */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-06-06 1.0  Ung      WMS-1911 Created                               */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593Print11] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- CaseID
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

   DECLARE @cDecodeSP   NVARCHAR(20)
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)

   DECLARE @nInputKey     INT
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cBarcodePart1 NVARCHAR( 20)
   DECLARE @cBarcodePart2 NVARCHAR( 20)
   DECLARE @cBarcodePart3 NVARCHAR( 20)

   -- Screen mapping
   SET @cBarcodePart1 = @cParam1 
   SET @cBarcodePart2 = @cParam2
   SET @cBarcodePart3 = @cParam3 

   -- Get login info
   SELECT 
      @nInputKey = InputKey, 
      @cFacility = Facility, 
      @cLabelPrinter = Printer, 
      @cPaperPrinter = Printer_Paper, 
      @cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 95601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Check blank
   IF @cBarcodePart1 = '' AND @cBarcodePart2 = '' AND @cBarcodePart3 = '' 
   BEGIN
      SET @nErrNo = 95602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need Barcode
      GOTO Quit
   END

   -- Customize decode
   SET @cDecodeSP = rdt.rdtGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP <> '0' AND @cDecodeSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, ' +
            ' @cBarcodePart1 OUTPUT, @cBarcodePart2 OUTPUT, @cBarcodePart3 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cLabelPrinter  NVARCHAR( 15), ' +
            ' @cBarcodePart1  NVARCHAR( 20)  OUTPUT,' +
            ' @cBarcodePart2  NVARCHAR( 20)  OUTPUT,' +
            ' @cBarcodePart3  NVARCHAR( 20)  OUTPUT,' +
            ' @nErrNo         INT            OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20)  OUTPUT'
   
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, 
            @cBarcodePart1 OUTPUT, @cBarcodePart2 OUTPUT, @cBarcodePart3 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
   
         IF @nErrNo <> 0
            GOTO Quit
      END
   END

   -- Common params
   DECLARE @tBarcode AS VariableTable
   INSERT INTO @tBarcode (Variable, Value) VALUES ( '@cBarcodePart1', @cBarcodePart1)
   INSERT INTO @tBarcode (Variable, Value) VALUES ( '@cBarcodePart2', @cBarcodePart2)
   INSERT INTO @tBarcode (Variable, Value) VALUES ( '@cBarcodePart3', @cBarcodePart3)

   -- Print label
   EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
      'Barcode1', -- Report type
      @tBarcode,  -- Report params
      'rdt_593Print11', 
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

/*
   -- Print label
   EXEC dbo.isp_BT_GenBartenderCommand
        @cLabelPrinter
      , 'Barcode1'  -- Report type
      , @cUserName
      , @cBarcode   -- Param01
      , ''          -- Param02
      , ''          -- Param03
      , ''          -- Param04
      , ''          -- Param05
      , ''          -- Param06
      , ''          -- Param07
      , ''          -- Param08
      , ''          -- Param09
      , ''          -- Param10
      , @cStorerKey
      , '1'         -- No of copy
      , '0'         -- Debug
      , 'N'         -- Return result
      , @nErrNo  OUTPUT
      , @cErrMsg OUTPUT
*/

Quit:


GO