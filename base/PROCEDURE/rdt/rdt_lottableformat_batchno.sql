SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_LottableFormat_BatchNo                                */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check batch no                                                    */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 03-10-2020  Ung       1.0   WMS-20822 Created                              */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_LottableFormat_BatchNo]
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

   DECLARE @cMasterCase NVARCHAR( 60) = ''
   DECLARE @cBatchNo    NVARCHAR( 60) = ''
   DECLARE @cUPC        NVARCHAR( 30) = ''
   DECLARE @cLottable01 NVARCHAR( 18)

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
      @cUserDefine01 = @cBatchNo  OUTPUT, 
      @cUPC          = @cUPC      OUTPUT, 
      @nErrNo        = 0

   -- Check same batch no
   IF @cLottable01 <> @cBatchNo
   BEGIN
      SET @nErrNo = 192401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff BatchNo
      GOTO Quit
   END

   -- Check same SKU
   IF @cSKU <> @cUPC
   BEGIN
      SET @nErrNo = 192402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff SKU
      GOTO Quit
   END
   
   -- Don't need to save
   SET @cLottable = ''
   
Quit:
   
END

GO