SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: rdt_LottableCode_954ValidateL2_01                    */
/* Copyright      : LF                                                   */
/*                                                                       */
/* Purpose: Validate L2 exists on the pallet id                          */
/*                                                                       */
/*                                                                       */
/* Date         Rev  Author      Purposes                                */
/* 17-OCT-2016  1.0  James       WMS506. Created                         */
/*************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_LottableCode_954ValidateL2_01]  
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
  
   DECLARE @cID            NVARCHAR( 18),
           @cFacility      NVARCHAR( 5), 
           @cLOT           NVARCHAR( 10),
           @cLottable02    NVARCHAR( 18),
           @nL02_StartPos  INT

   SELECT @cID = V_ID
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF ISNULL( @cLottableValue, '') = ''
   BEGIN
      SET @nErrNo = 104901
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv serial #
      GOTO Fail
   END

   SELECT @nL02_StartPos = CHARINDEX( 'S', @cLottableValue)

   IF @nL02_StartPos = 0
   BEGIN
      SET @nErrNo = 104902
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv serial #
      GOTO Fail
   END

   SELECT @cLottable02 = SUBSTRING( @cLottableValue, @nL02_StartPos + 1, LEN( RTRIM( @cLottableValue)) - @nL02_StartPos)

   -- Check if lottable02 exists on the pallet
   IF NOT EXISTS ( SELECT 1 FROM dbo.LOTAttribute LA WITH (NOLOCK)
                   JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON LA.LOT = LLI.LOT
                   WHERE LA.StorerKey = @cStorerKey
                   AND   LA.SKU = @cSKU
                   AND   LA.Lottable02 = @cLottable02
                   AND   LLI.ID = @cID
                   AND   (LLI.Qty - LLI.QtyPicked > 0))
   BEGIN
      SET @nErrNo = 104903
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv serial #
      GOTO Fail
   END

   SELECT @cLottable = @cLottable02

   GOTO Quit

Fail:  

Quit:  

END -- End Procedure  

GO