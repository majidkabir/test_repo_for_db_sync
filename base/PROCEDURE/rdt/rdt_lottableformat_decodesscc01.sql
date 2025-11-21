SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: rdt_LottableFormat_DecodeSSCC01                      */
/* Copyright      : LF                                                   */
/*                                                                       */
/* Purpose: User scan Lottable03. Remove prefix of Lottable03 (SSCC code)*/
/*          should be based on the prefix mantain at the codelkup table. */
/*                                                                       */
/*          Data capture in RDT E.g. 00350110130088942137105310B2004     */
/*          Input into system 350110130088942137 18 character            */
/*          Use codelkup to determine the prefix and length of digits to */
/*          take. Then use SUBSTRING method to get the correct value     */
/*                                                                       */
/* Date        Rev  Author      Purposes                                 */
/* 26-01-2015  1.0  James       SOS361419. Created                       */
/*************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_DecodeSSCC01]  
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
  

   DECLARE  @nStart        INT,
            @nLength2Take  INT, 
            @cCode         NVARCHAR( 10),
            @cShort        NVARCHAR( 10),
            @cLong         NVARCHAR( 250),
            @cUDF01        NVARCHAR( 60),
            @cSSCC         NVARCHAR( 60)

   SET @cLottable = @cLottableValue

   SELECT @cCode = Code,
          @cShort = Short,
          @cLong = Long,   -- Exception Value
          @cUDF01 = UDF01  -- Actual barcode prefix
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE ListName = 'SSCCDECODE'
   AND   StorerKey =  @cStorerkey

   IF @cLottable = @cLong
      GOTO Quit

   -- Check valid prefix
   IF rdt.rdtIsValidQty(@cCode, 0) <> 1
   BEGIN
      SET @nErrNo = 96301
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
      GOTO Fail
   END

   -- Check valid length
   IF rdt.rdtIsValidQty(@cShort, 0) <> 1
   BEGIN
      SET @nErrNo = 96302
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Length
      GOTO Fail
   END

   SET @nStart = LEN( RTRIM( @cCode)) + 1
   SET @nLength2Take = @cShort

   -- If barcode length < defined length to take then error   
   IF LEN( RTRIM( @cLottable)) < @nLength2Take
   BEGIN
      SET @nErrNo = 96303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Barcode
      GOTO Fail
   END

   -- If same length, no need decode. Prevent double decode
   IF LEN( RTRIM( @cLottable)) = @nLength2Take
      GOTO Quit

   SET @cSSCC = SUBSTRING( @cLottable, @nStart, @nLength2Take)

   -- Check actual barcode prefix. Prevent scan wrong type of barcode
   IF ISNULL( @cUDF01, '') <> ''
   BEGIN
      IF @cUDF01 <> SUBSTRING( @cSSCC, 1, LEN( RTRIM( @cUDF01)))
      BEGIN
         SET @nErrNo = 96304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Barcode
         GOTO Fail
      END      
   END
   
   IF ISNULL( @cSSCC, '') <> ''
   BEGIN
      SET @cLottable = @cSSCC
      GOTO Quit
   END

Fail:  
   SET @cLottable = ''

Quit:  
  
END -- End Procedure  

GO