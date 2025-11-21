SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_852ExtVal01                                     */
/* Purpose: Check if user login with printer                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 2021-07-06 1.0  yeekung    WMS17278 Created                          */	  
/************************************************************************/

CREATE PROC [RDT].[rdt_852ExtVal01] (
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
   @cTaskDetailKey   NVARCHAR( 10) = '',  
   @tExtValidate   VariableTable READONLY   
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey INT
          ,@cUserName NVARCHAR(20)
          ,@cMQty     NVARCHAR(5)
          ,@nCountOrder INT

   IF @nFunc = 852 -- Post pick audit (Pallet ID)
   BEGIN
      IF @nStep = 1 -- Pallet ID
      BEGIN
         -- Get session info
         SELECT @nInputKey = InputKey,@cUserName=username FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

         IF @nInputKey = 1 -- ENTER
         BEGIN

            IF NOT EXISTS (SELECT 1
                           FROM dbo.PickHeader WITH (NOLOCK)
                           WHERE PickHeaderKey = @cPickSlipNo)
            BEGIN
               DECLARE @cdateformat NVARCHAR(20)

               IF NOT EXISTS (SELECT 1 FROM codelkup(NOLOCK) 
                          WHERE listname = 'PPARCODE'
                          AND code=@cPickSlipNo
                          AND Storerkey=@cStorerKey)
               BEGIN
                  SET @nErrNo = 176551   
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP')
                  GOTO quit
               END

               SET @cdateformat=rdt.rdtformatdate(getdate())

               EXEC RDT.rdt_STD_EventLog  
                 @cActionType = '3', -- Sign in function  
                 @cUserID     = @cUserName,  
                 @nMobileNo   = @nMobile,  
                 @nFunctionID = @nFunc,  
                 @cFacility   = @cFacility,  
                 @cStorerKey  = @cStorerkey,
                 @cReasonKey  = @cpickslipno,
                 @cLoadKey    = @cdateformat

                 GOTO quit
            END
            
         END
      END
   END

Quit:


GO