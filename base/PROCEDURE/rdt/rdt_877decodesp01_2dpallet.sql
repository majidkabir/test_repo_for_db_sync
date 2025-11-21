SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_877DecodeSP01_2DPallet                          */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-05-2018  1.0  Ung         WMS-4846 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_877DecodeSP01_2DPallet]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( MAX), 
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*
   Details refer to pdf:
   180.003 - Pallet Datamatrix Code Specification v1.3.pdf
   
   Format:
   P:ppppp...Q:qqqqq...M:mmmmm...(ccccc;axb;j;axb...)sssss...M:mmmmm...(ccccc;axb;j;axb...)sssss...
   
   ppppp... = pallet ID
   qqqqq... = total cases in pallet
   mmmmm... = prefix of case ID
   ccccc = starting case ID
   a = number to be added to subsequence case ID (starting case ID + a)
   b = continue for b number of cases, where case ID = case ID + 1
   j = number to be added to subsequence case ID 
   sssss... = surfix of case ID

   Example:
   P:00976149000005918948Q:24M:01040329000062081007262126213(00040;4x5;2;2x6)24012933754M:01040549000062081007286326213(00004;1x3;3;4;2;6x4)24012933754
   
   P: = 00976149000005918948 (pallet ID)
   Q: = 24 (cases in pallet)

   M: = 01040329000062081007262126213 (prefix of case ID)   
   ccccc = 00040 (starting case ID)
   a = 4, subsequence case ID = 00040 + 4 = 00044
   b = 5, continue for 5 cases, case ID = 00044, 45, 46, 47 to 00048
   j = 2, subsequence case ID = 00048 + 2 = 00050
   a = 2, subsequence case ID = 00050 + 2 = 00052
   b = 5, continue for 6 cases, case ID = 00052, 53, 54, 55, 56 to 00057
   sssss = 24012933754
   
   M: = 01040329000062081007262126213 (prefix of case ID)   
   ccccc = 00004 (starting case ID)
   a = 4, subsequence case ID = 00004 + 1 = 00005
   b = 5, continue for 3 cases, case ID = 00005, 6, to 00007
   j = 3, subsequence case ID = 00007 + 3 = 00010
   j = 4, subsequence case ID = 00010 + 4 = 00014
   j = 2, subsequence case ID = 00014 + 2 = 00016
   a = 6, subsequence case ID = 00016 + 6 = 00022
   b = 4, continue for 4 cases, case ID = 00022, 23, 24 to 00025
   sssss = 24012933754
   
   010403290000620810072621262130004024012933754
   010403290000620810072621262130004424012933754
   010403290000620810072621262130004524012933754
   010403290000620810072621262130004624012933754
   010403290000620810072621262130004724012933754
   010403290000620810072621262130004824012933754
   010403290000620810072621262130005024012933754
   010403290000620810072621262130005224012933754
   010403290000620810072621262130005324012933754
   010403290000620810072621262130005424012933754
   010403290000620810072621262130005524012933754
   010403290000620810072621262130005624012933754
   010403290000620810072621262130005724012933754
   010405490000620810072863262130000424012933754
   010405490000620810072863262130000524012933754
   010405490000620810072863262130000624012933754
   010405490000620810072863262130000724012933754
   010405490000620810072863262130001024012933754
   010405490000620810072863262130001424012933754
   010405490000620810072863262130001624012933754
   010405490000620810072863262130002224012933754
   010405490000620810072863262130002324012933754
   010405490000620810072863262130002424012933754
   010405490000620810072863262130002524012933754
   */

   DECLARE @cCaseSet    NVARCHAR(MAX)
   DECLARE @cPalletID   NVARCHAR(MAX)
   DECLARE @cTotalCase  NVARCHAR(MAX)
   DECLARE @nCaseStart  INT
   DECLARE @nCaseEnd    INT
   DECLARE @nStart      INT
   DECLARE @nEnd        INT

   -- Get pallet ID
   /*
   SET @nStart = CHARINDEX( 'P:', @cBarcode)
   IF @nStart = 0
      GOTO Quit
   ELSE
      SET @nStart = @nStart + 2
   */
   SET @nStart = 3
   SET @nEnd = CHARINDEX( 'Q:', @cBarcode)
   IF @nEnd = 0
   BEGIN
      SET @cPalletID = SUBSTRING( @cBarcode, @nStart, LEN( @cBarcode))

      SET @nErrNo = 123801
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad pallet end
      GOTO Quit
   END
   ELSE
      SET @cPalletID = SUBSTRING( @cBarcode, @nStart, @nEnd-@nStart)

   -- Check pallet ID
   IF @cPalletID = ''
   BEGIN
      SET @nErrNo = 123802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank PalletID
      GOTO Quit
   END

   -- Total case
   SET @nStart = @nEnd + 2
   SET @nEnd = CHARINDEX( 'M:', @cBarcode)
   IF @nEnd = 0
   BEGIN
      SET @cTotalCase = SUBSTRING( @cBarcode, @nStart, LEN( @cBarcode))

      SET @nErrNo = 123803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Total end
      GOTO Quit
   END
   ELSE
      SET @cTotalCase = SUBSTRING( @cBarcode, @nStart, @nEnd-@nStart)

   -- Check pallet ID
   IF @cTotalCase = ''
   BEGIN
      SET @nErrNo = 123804
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BlankTotalCase
      GOTO Quit
   END

   -- 1st case set
   SET @nCaseStart = @nEnd + 2
   SET @nCaseEnd = CHARINDEX( 'M:', @cBarcode, @nCaseStart)
   IF @nCaseEnd = 0
      SET @nCaseEnd = LEN( @cBarcode) + 1
   SET @cCaseSet = SUBSTRING( @cBarcode, @nCaseStart, @nCaseEnd-@nCaseStart)

   -- Loop case set
   WHILE @cCaseSet <> ''
   BEGIN
      -- Process case set
      EXECUTE rdt.rdt_877DecodeSP01_2DPallet_CaseSet @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cCaseSet
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Find next case set
      SET @cCaseSet = ''
      SET @nCaseStart = @nCaseEnd + 2
      SET @nCaseEnd = CHARINDEX( 'M:', @cBarcode, @nCaseStart)
      IF @nCaseEnd = 0
      BEGIN
         -- End of string
         IF @nCaseStart > LEN( @cBarcode)
            BREAK
         ELSE
            SET @nCaseEnd = LEN( @cBarcode) + 1
      END
      SET @cCaseSet = SUBSTRING( @cBarcode, @nCaseStart, @nCaseEnd-@nCaseStart)
   END

Quit:

END

GO