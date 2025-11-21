SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt.rdt_855ExtInfo07                                */
/* Copyright      : Maersk                                              */
/* Purpose        : FCR-1109 for LVSUSA                                 */
/*                                                                      */
/* Date       Rev    Author   Purposes                                  */
/* 2024-11-15 1.0.0  LJQ006   FCR-1109 Created                          */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_855ExtInfo07
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cCartonType         NVARCHAR(10),
      @cDropID             NVARCHAR(20),
      @nScn                INT

   -- Variable mapping
   SELECT @cDropID = Value FROM @tExtInfo WHERE Variable = '@cDropID'

   SELECT @nScn = Scn FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 855 -- PPA by DropID
   BEGIN
      IF @nStep = 1 OR (@nStep = 99 AND @nScn = 814)-- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            -- get CartonType by CaseID 
            SELECT TOP 1 @cCartonType = PKI.CartonType
            FROM dbo.PackInfo PKI WITH(NOLOCK)
            INNER JOIN dbo.PickDetail PKD WITH(NOLOCK) ON ISNULL(PKI.RefNo, '') = ISNULL(PKD.CaseID, '-1')
            WHERE PKD.StorerKey = @cStorerKey
               AND ISNULL(RefNo, '') = @cDropID

            SET @cExtendedInfo = 'CARTON TYPE: ' + TRIM(SUBSTRING(@cCartonType, 1, 8))
            GOTO Quit
         END
      END
      IF @nStep = 4 AND @nInputKey = 0
      BEGIN
         -- get CartonType by CaseID 
         SELECT TOP 1 @cCartonType = PKI.CartonType
         FROM dbo.PackInfo PKI WITH(NOLOCK)
         INNER JOIN dbo.PickDetail PKD WITH(NOLOCK) ON ISNULL(PKI.RefNo, '') = ISNULL(PKD.CaseID, '-1')
         WHERE PKD.StorerKey = @cStorerKey
            AND ISNULL(RefNo, '') = @cDropID

         SET @cExtendedInfo = 'CARTON TYPE: ' + TRIM(SUBSTRING(@cCartonType, 1, 8))
         GOTO Quit
      END
   END
   
Quit:
   
END

GO