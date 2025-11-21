SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580DecodeLot01                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check lottable received                                           */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 20-01-2021  Chermaine 1.0   WMS-16015 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580DecodeLot01]
    @nMobile          INT
   ,@nFunc            INT
   ,@cLangCode        NVARCHAR( 3)
   ,@nStep            INT
   ,@nInputKey        INT
   ,@cFacility        NVARCHAR( 5)
   ,@cStorerKey       NVARCHAR( 15)
   ,@cBarcode         NVARCHAR( 60)
   ,@cToLOC           NVARCHAR( 10)
   ,@cToID            NVARCHAR( 18)
   ,@cLottable01Value NVARCHAR( 20)
   ,@cLottable02Value NVARCHAR( 20)
   ,@cLottable03Value NVARCHAR( 20)
   ,@cLottable04Value NVARCHAR( 16)
   ,@cTempLottable01  NVARCHAR( 20) OUTPUT
   ,@cTempLottable02  NVARCHAR( 20) OUTPUT
   ,@cTempLottable03  NVARCHAR( 20) OUTPUT
   ,@cTempLottable04  NVARCHAR( 16) OUTPUT
   ,@nErrNo           INT           OUTPUT
   ,@cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   IF @cToLOC IN ('NESPOVERC','NESPRETC')--New ASN Inbound / Return Coffee Product
   BEGIN
   	IF LEN(@cLottable02Value) < 10 
   	BEGIN
   		SET @nErrNo = 162601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrongBatchNo
         GOTO QUIT
   	END
   	
   	IF @cLottable03Value LIKE '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]' --YYYY.MM.DD
   	BEGIN
   		SET @cTempLottable03 = CONVERT(VARCHAR,TRY_CONVERT(date, @cLottable03Value),101) --DD/MM/YYYY
   	END
   	ELSE IF @cLottable03Value LIKE '[0-9][0-9].[0-9][0-9].[0-9][0-9]'--DD.MM.YY
   	BEGIN
   		SET @cTempLottable03 = STUFF(REPLACE(@cLottable03Value,'.','/'),7,0,LEFT(YEAR(GETDATE()),2)) --DD/MM/YYYY
   	END
   	ELSE IF @cLottable03Value LIKE '[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9][0-9]'--DD.MM.YYYY
   	BEGIN
   		SET @cTempLottable03 = REPLACE(@cLottable03Value,'.','/') --DD/MM/YYYY
   	END
   	ELSE IF @cLottable03Value NOT LIKE '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]'--DD/MM/YYYY
   	BEGIN
   		SET @nErrNo = 162603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrongDateFormat
         
         SET @cTempLottable04 = ''
         SET @cTempLottable03 = ''
         GOTO Quit
   	END
   	
   	SET @cTempLottable04 = @cTempLottable03
   	SET @cTempLottable01 = @cLottable01Value
   	SET @cTempLottable02 = @cLottable02Value
   END
   ELSE IF @cToLOC IN ('NESPOVERA','NESPRETA') --New ASN Inbound / Return Accessories Product
   BEGIN
   	IF LEN(@cLottable02Value) < 9 
   	BEGIN
   		SET @nErrNo = 162602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02-WrongFormat
         GOTO QUIT
   	END
   	ELSE
   	BEGIN
   		SET @cTempLottable02 = RIGHT(@cLottable02Value,5)
   	END
   	
   	IF NOT EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE listName ='NESPBATCH' AND code = LEFT(@cLottable02Value,4))
   	BEGIN
   		SET @nErrNo = 162604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02-WrongFormat
         GOTO QUIT
   	END
   	ELSE
   	BEGIN
   		SELECT @cTempLottable03 = short FROM codelkup WITH (NOLOCK) WHERE listName ='NESPBATCH' AND code = LEFT(@cLottable02Value,4)
   	END

   	SELECT @cTempLottable04 = CONVERT(NVARCHAR(10),DATEADD(YEAR,10,GETDATE()),103) --DD/MM/YYYY
   	
   	SET @cTempLottable01 = @cLottable01Value 
   END
   ELSE
   BEGIN
      --others loc cheking
      IF @cLottable02Value = '' 
      BEGIN
      	SET @nErrNo = 162605
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L02 Required
         GOTO QUIT
      END
      
      IF @cLottable03Value = '' 
      BEGIN
      	SET @nErrNo = 162606
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L03 Required
         GOTO QUIT
      END
      
      IF @cLottable04Value = ''
      BEGIN
      	SET @nErrNo = 162607
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L04 Required
         GOTO QUIT
      END
   END
   
Quit:

END

GO