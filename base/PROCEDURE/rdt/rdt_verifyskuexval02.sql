SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_VerifySKUExVal02                                */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 18-03-2015  1.0  James        SOS333459. Created                     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKUExVal02]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerKey      NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @cType           NVARCHAR( 10),
   @cVerifySKUInfo  NVARCHAR( 20) OUTPUT,
   @cWeight         NVARCHAR( 10) OUTPUT,
   @cCube           NVARCHAR( 10) OUTPUT,
   @cLength         NVARCHAR( 10) OUTPUT,
   @cWidth          NVARCHAR( 10) OUTPUT,
   @cHeight         NVARCHAR( 10) OUTPUT,
   @cInnerPack      NVARCHAR( 10) OUTPUT,
   @cCaseCount      NVARCHAR( 10) OUTPUT,
   @cPalletCount    NVARCHAR( 10) OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU_Weight NVARCHAR( 10)  

   SET @nErrNo = 0

   SELECT @cSKU_Weight = STDGrossWGT   
   FROM dbo.SKU WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
   AND   SKU = @cSKU  

   -- If weight not captured for SKU, prompt for enter Weight
   -- If weight already captured then always prompt for enter Case
   IF ISNULL( CAST( @cSKU_Weight AS FLOAT), '0') <= 0  
   BEGIN
      SET @nErrNo = 52701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Weight      
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Weight
      GOTO Quit
   END

   IF EXISTS ( SELECT 1 FROM RDT.RDTMOBREC WITH (NOLOCK) 
               WHERE MOBILE = @nMobile
               AND   ( V_String33 = '' OR V_String33 = '0'))
   BEGIN
      SET @nErrNo = 52702
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Case      
      EXEC rdt.rdtSetFocusField @nMobile, 12 -- Case
      GOTO Quit
   END

Fail:

Quit:

END -- End Procedure

GO