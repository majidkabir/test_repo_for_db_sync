SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store procedure: rdt_LottableFormat_IDSMEDValidateL2L4                */
/* Copyright      : LF                                                   */
/*                                                                       */
/* Purpose: Validate L2 & L4 against the PPA type keyed in               */
/*                                                                       */
/*                                                                       */
/* Date        Rev  Author      Purposes                                 */
/* 07-09-2016  1.0  James       SOS374911. Created                       */
/*************************************************************************/
  
CREATE PROCEDURE [RDT].[rdt_LottableFormat_IDSMEDValidateL2L4]  
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
            @cSSCC         NVARCHAR( 60),
            @cPPAType      NVARCHAR(1),
            @cOrderkey     NVARCHAR( 10),
            @cDropID       NVARCHAR( 20)


   SELECT @cPPAType = V_String18, 
          @cOrderKey = V_String1,
          @cDropID = V_String12
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cLottable = @cLottableValue

   IF @cPPAType = '3'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.Orderkey = @cOrderkey
         AND   PD.SKU = @cSKU
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottableValue ELSE Lottable02 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 THEN @cLottableValue ELSE ISNULL( Lottable04, 0) END)
      BEGIN
         SET @nErrNo = 96301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
         GOTO Fail
      END
   END

   IF @cPPAType = '4'
   BEGIN
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Storerkey = @cStorerKey
         AND   PD.SKU = @cSKU
         AND   PD.DropID = @cDropID
         AND   Lottable02 = CASE WHEN @nLottableNo = 2 THEN @cLottableValue ELSE Lottable02 END
         AND   ISNULL( Lottable04, 0) = CASE WHEN @nLottableNo = 4 THEN @cLottableValue ELSE ISNULL( Lottable04, 0) END)
      BEGIN
         SET @nErrNo = 96301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Prefix
         GOTO Fail
      END
   END

   GOTO Quit

Fail:  
   SET @cLottable = ''

Quit:  
  
END -- End Procedure  

GO