SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PrintQCCLabel                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert print QCC label job                                  */
/*                                                                      */
/* Called from: rdtfnc_PrintQCCLabel                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-05-20  1.0  James       SOS310288 Created                       */ 
/* 2014-08-29  1.1  CSCHONG     fix for duplicate qty in pickdetail(CS01)*/ 
/* 2014-09-02  1.2  Ung         SOS310288 Clean up source               */
/************************************************************************/

CREATE PROC [RDT].[rdt_PrintQCCLabel] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3),
   @cStorerKey  NVARCHAR( 15),
   @cUCCNo      NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cLottable01 NVARCHAR( 18),
   @nQty        INT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT   -- screen limitation, 20 char max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExtendedField02  NVARCHAR( 30), 
           @cTtl_Qty          NVARCHAR( 5), 
           @cDW_Sticker       NVARCHAR( 50), 
           @cDB_Sticker       NVARCHAR( 20), 
           @cDW_HangTag       NVARCHAR( 50), 
           @cDB_HandTag       NVARCHAR( 20), 
           @cPrinter_Paper    NVARCHAR( 10), 
           @cPrinter_Label    NVARCHAR( 10), 
           @nTtl_Qty          INT, 
           @n                 INT 

--SKUINFO.ExtendedField02 in ('FT', 'PC')
--SKUINFO.ExtendedField02 in ('AP', 'AC')

   SELECT @cDW_Sticker = DataWindow, 
          @cDB_Sticker = TargetDB 
   FROM rdt.rdtReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReportType = 'QCLBLSTICK'
   
   SELECT @cDW_HangTag = DataWindow, 
          @cDB_HandTag = TargetDB 
   FROM rdt.rdtReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   ReportType = 'QCLBLHAND'

   IF ISNULL( @cDW_Sticker, '') = '' OR ISNULL( @cDW_HangTag, '') = ''
   BEGIN
      SET @nErrNo = 88601  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup  
      GOTO Quit  
   END

   IF ISNULL( @cDB_Sticker, '') = '' OR ISNULL( @cDB_HandTag, '') = ''
   BEGIN
      SET @nErrNo = 88602  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set  
      GOTO Quit  
   END

   SELECT @cPrinter_Paper = Printer_Paper, 
          @cPrinter_Label = Printer 
   FROM rdt.rdtMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF ISNULL( @cPrinter_Paper, '') = '' 
   BEGIN
      SET @nErrNo = 88603  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter  
      GOTO Quit  
   END

   IF ISNULL( @cPrinter_Label, '') = '' 
   BEGIN
      SET @nErrNo = 88604  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter  
      GOTO Quit  
   END

   IF EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   LabelNo = @cUCCNo
               AND   SKU NOT IN ( SELECT SI.SKU FROM dbo.SKUINFO SI WITH (NOLOCK) 
                                  WHERE PD.SKU = SI.SKU 
                                  AND ISNULL( ExtendedField02, '')<> ''))
   BEGIN
      SET @nErrNo = 88605  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO SKUINFO   
      GOTO Quit  
   END

   SELECT @cExtendedField02 = ExtendedField02 
   FROM dbo.SKUINFO SI WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   IF @cExtendedField02 IN ('FT', 'PC')
      EXEC RDT.rdt_BuiltPrintJob  
         @nMobile,  
         @cStorerKey,  
         'QCLBLSTICK',              -- ReportType  
         'PRINT_QCCLABELSTICKER',   -- PrintJobName  
         @cDW_Sticker,  
         @cPrinter_Label,  
         @cDB_Sticker,  
         @cLangCode,  
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT,   
         @cUCCNo, 
         @cSKU,
         @cLottable01, 
         @nQty 
   ELSE
      EXEC RDT.rdt_BuiltPrintJob  
         @nMobile,  
         @cStorerKey,  
         'QCLBLHAND',               -- ReportType  
         'PRINT_QCCLABELHANDTAG',   -- PrintJobName  
         @cDW_HangTag,  
         @cPrinter_Paper,  
         @cDB_HandTag,  
         @cLangCode,  
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT,   
         @cUCCNo, 
         @cSKU,
         @cLottable01, 
         @nQty 
   
Quit:
END

GO