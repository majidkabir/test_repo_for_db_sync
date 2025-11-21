SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_877DecodeSP01_2DPallet_CaseSet                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-05-2018  1.0  Ung         WMS-4846 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_877DecodeSP01_2DPallet_CaseSet]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCaseSet       NVARCHAR( MAX), 
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCasePrefix    NVARCHAR( MAX)
   DECLARE @cFormula       NVARCHAR( MAX)
   DECLARE @cCaseSurfix    NVARCHAR( MAX)
   DECLARE @nStart         INT
   DECLARE @nEnd           INT
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cLottable06    NVARCHAR( 30)

   SET @cCasePrefix = ''
   SET @cCaseSurfix = ''
   SET @cFormula = ''

   -- Get case prefix
   SET @nStart = CHARINDEX( '(', @cCaseSet)
   IF @nStart = 0
   BEGIN
      SET @nErrNo = 123851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing (
      GOTO Quit
   END
   ELSE
      SET @cCasePrefix = SUBSTRING( @cCaseSet, 1, @nStart-1)
   
   -- Check case prefix blank
   IF @cCasePrefix = ''
   BEGIN
      SET @nErrNo = 123852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank L01
      GOTO Quit
   END

   -- Check case prefix valid
   IF LEN( @cCasePrefix) <> 2 + 14 + 2 + 8 + 2 + 1 -- "01" + GTIN( 14 chars) + "10" + BATCH (L01, 8 chars) + "21" + "?"
   BEGIN
      SET @nErrNo = 123853
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L01
      GOTO Quit
   END
   ELSE
      SET @cLottable06 = SUBSTRING( @cCasePrefix, 19, 8) -- Batch

   -- Get case surfix
   SET @nEnd = CHARINDEX( ')', @cCaseSet)
   IF @nEnd = 0
   BEGIN
      SET @nErrNo = 123854
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing )
      GOTO Quit
   END
   ELSE
      SET @cCaseSurfix = SUBSTRING( @cCaseSet, @nEnd+1, LEN( @cCaseSet))
   
   -- Check case surfix blank
   IF @cCaseSurfix = ''
   BEGIN
      SET @nErrNo = 123855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank L06
      GOTO Quit
   END

   -- Check case surfix valid
   IF LEN( @cCaseSurfix) <> 3 + 8 -- "240" + L06 (8 chars)
   BEGIN
      SET @nErrNo = 123856
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid L06
      GOTO Quit
   END
   ELSE
      SET @cLottable01 = SUBSTRING( @cCaseSurfix, 4, 8) -- LOT

   -- Get formula
   SET @cFormula = SUBSTRING( @cCaseSet, @nStart+1, @nEnd-@nStart-1)
   IF @cFormula = ''
   BEGIN
      SET @nErrNo = 123857
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank formula
      GOTO Quit
   END

   -- Execute formula
   EXECUTE rdt.rdt_877DecodeSP01_2DPallet_CaseSet_Formula @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cCasePrefix
      ,@cFormula
      ,@cCaseSurfix
      ,@cLottable01
      ,@cLottable06
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

Quit:

END

GO