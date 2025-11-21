SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKUExVal01                                */
/* Copyright      : LF Logistic                                         */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 08-09-2014  1.0  Ung          SOS320350. Created                     */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKUExVal01]
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

   DECLARE @cBUSR10 NVARCHAR(30)
   SET @cBUSR10 = ''
   
   -- Get SKU info
   SELECT @cBUSR10 = BUSR10 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   IF @cBUSR10 = 'Y'
      SET @nErrNo = -1

Fail:

END -- End Procedure


GO