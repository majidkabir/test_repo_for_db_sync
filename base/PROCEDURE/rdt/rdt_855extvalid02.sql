SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_855ExtValid02                                   */
/* Purpose: Check if user login with printer                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2018-12-06 1.0  James     WMS-6842 Created                           */
/* 2018-11-19 1.1  Ung       WMS-6932 Add ID param                      */
/* 2019-03-29 1.2  James     WMS-8002 Add TaskDetailKey param (james01) */
/* 2019-04-22 1.3  James     WMS-7983 Add VariableTable (james02)       */
/************************************************************************/

CREATE PROC [RDT].[rdt_855ExtValid02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5),
   @cRefNo      NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cLoadKey    NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cID         NVARCHAR( 18) = '',
   @cTaskDetailKey    NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey INT
   
   -- Get session info
   SELECT @nInputKey = InputKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 855 -- PPA by DropID
   BEGIN
      IF @nStep = 1 -- Drop ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check outstanding
            IF EXISTS( SELECT TOP 1 1
               FROM PickDetail (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cDropID
                  AND QTY > 0
                  AND Status IN ('0', '4'))
            BEGIN
               SET @nErrNo = 133101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Carton NotDone
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO