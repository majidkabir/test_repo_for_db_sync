SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtValidSP21                                */
/* Purpose: FCR-1406 PUMA - Traceability                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev    Author     Purposes                                */
/* 2024-12-02 1.0.0  LJQ006     FCR-1406 Created                        */
/************************************************************************/

CREATE   PROC rdt.rdt_1641ExtValidSP21 (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE
   @cUCCWaveKey    NVARCHAR(10),
   @cDropIDWaveKey    NVARCHAR(10)

IF @nFunc = 1641
BEGIN
   IF @nStep = 3
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.Dropid WITH(NOLOCK) WHERE Dropid = @cDropID)
      BEGIN
         IF EXISTS(SELECT 1 FROM dbo.DropidDetail WITH(NOLOCK) WHERE Dropid = @cDropID)
         BEGIN
            SELECT @cUCCWaveKey = WaveKey FROM dbo.PICKDETAIL WHERE StorerKey = @cStorerKey AND DropID = @cUCCNo
            SELECT @cDropIDWaveKey = WaveKey 
            FROM dbo.PICKDETAIL pd WITH(NOLOCK)
            INNER JOIN dbo.DropIDDetail did ON  did.ChildID = pd.DropID
            WHERE did.Dropid = @cDropID
            IF @cUCCWaveKey <> @cDropIDWaveKey
            BEGIN
               SET @nErrNo = 229952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- WaveKey does not match
            END
         END
      END
   END
END

QUIT:

GO