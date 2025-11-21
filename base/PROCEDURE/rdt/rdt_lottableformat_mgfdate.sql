SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_MgfDate                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check manufacturer date same                                      */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 03-10-2020  Ung       1.0   WMS-20822 Created                              */
/* 12-10-2022  YeeKung   1.1   WMS-20737 Add lottable15 validation(yeekung01) */ 
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableFormat_MgfDate]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cLottableCode    NVARCHAR( 30),
   @nLottableNo      INT,
   @cFormatSP        NVARCHAR( 50),
   @cLottableValue   NVARCHAR( 60),
   @cLottable        NVARCHAR( 60) OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable01 NVARCHAR( 18)
   DECLARE @cMasterCase NVARCHAR( 60) = ''
   DECLARE @cMFGDateYMD NVARCHAR( 60) = ''
   DECLARE @cMFGDate    NVARCHAR( 10)
   DECLARE @dMFGDate    DATETIME

   -- Get session info
   DECLARE @nStep INT
   DECLARE @cFacility NVARCHAR(5)
   SELECT
      @nStep = Step,
      @cFacility = Facility, 
      @cLottable01 = V_Lottable01
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Decode
   EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cLottableValue,
      @cUserDefine01 = @cMasterCase OUTPUT, 
      @cUserDefine02 = @cMFGDateYMD OUTPUT, 
      @nErrNo        = 0

   -- Check master case valid
   IF NOT EXISTS( SELECT 1
      FROM dbo.UPC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND UPC = @cMasterCase)
   BEGIN
      SET @nErrNo = 192351
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Master Case
      GOTO Quit
   END
   
   -- Convert to DMY
   SET @cMFGDate = 
      SUBSTRING( @cMFGDateYMD, 5, 2) + '/' + -- DD
      SUBSTRING( @cMFGDateYMD, 3, 2) + '/' + -- MM
      SUBSTRING( @cMFGDateYMD, 1, 2)         -- YY

   -- Check same MfgDate
   IF @cLottable01 <> @cMFGDate
   BEGIN
      SET @nErrNo = 192352
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff MfgDate
      GOTO Quit
   END

   -- Add century
   SET @cMFGDate = LEFT( @cMFGDate, 6) + '20' + RIGHT( @cMFGDate, 2)
   
   -- Check date valid
   IF rdt.rdtIsValidDate( @cMFGDate) = 0
   BEGIN
      SET @nErrNo = 192353
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidMfgDate
      GOTO Quit
   END
   
   -- Convert to date
   SET @dMFGDate = rdt.rdtConvertToDate( @cMFGDate)
   
   -- Check future date
   IF @dMFGDate > GETDATE()
   BEGIN
      SET @nErrNo = 192354
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Future MfgDate
      GOTO Quit
   END
   
   SET @cLottable = @cMFGDate
   
Quit:
   
END

GO