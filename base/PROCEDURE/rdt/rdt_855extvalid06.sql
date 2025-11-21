SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtValid06                                   */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/* Purpose: Block the user choose option 2                              */  
/*          prompt screen to alert user                                 */
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2024-03-28  1.0  yeekung  UWP-16421. Created                         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtValid06] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @cStorer        NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cRefNo         NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20),
   @cLoadKey       NVARCHAR( 10),
   @cPickSlipNo    NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cID            NVARCHAR( 18) = '',
   @cTaskDetailKey NVARCHAR( 10) = '',
   @tExtValidate   VariableTable READONLY

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nInputKey      INT,
           @cWavekey       NVARCHAR( 10),
           @cOption        NVARCHAR( 1)
   
   SELECT @cOption = Value FROM @tExtValidate WHERE Variable = '@cOption'
   -- Variable mapping

   IF @nFunc = 855   -- Drop ID
   BEGIN
      IF @nStep = 4  -- Discrepancy screen entered
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption ='2'            
            BEGIN
               SET @nErrNo = 213201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --WrongOpt
               GOTO Quit
            END
            
         END
      END
   END

   Quit:      

END  


GO