SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_855ExtValid04                                   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Check user input qty vs system qty. If both value not same  */  
/*          prompt screen to alert user                                 */
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2019-04-17  1.0  James    WMS-17439. Created                         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_855ExtValid04] (  
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
           @nQTY           INT,
           @nQTY_PPA       INT,
           @nQTY_CHK       INT,
           @cPH_Status     NVARCHAR( 1)
           
   -- Variable mapping
   SELECT @nQTY = Value FROM @tExtValidate WHERE Variable = '@nQTY'
   SELECT @nQTY_PPA = Value FROM @tExtValidate WHERE Variable = '@nQTY_PPA'
   SELECT @nQTY_CHK = Value FROM @tExtValidate WHERE Variable = '@nQTY_CHK'
   SELECT @nInputKey = Value FROM @tExtValidate WHERE Variable = '@nInputKey'

   IF @nFunc = 855   -- Drop ID
   BEGIN
      IF @nStep = 1  -- Carton ID entered
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF EXISTS ( SELECT 1 FROM rdt.rdtPPA WITH (NOLOCK)
                        WHERE StorerKey = @cStorer
                        AND   DropID = @cDropID)
            BEGIN      
               SET @nErrNo = 183801      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PPA Done      
               GOTO Quit      
            END      

            SELECT TOP 1 @cPH_Status = PH.Status 
            FROM dbo.PackHeader PH WITH (NOLOCK)  
            JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
            WHERE PD.DropID = @cDropID  
            AND   PH.StorerKey = @cStorer
            ORDER BY 1 DESC
            
            IF @cPH_Status <> '9'
            BEGIN      
               SET @nErrNo = 183802      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not PackCfm      
               GOTO Quit      
            END   
         END
      END
   END

   Quit:      

END  


GO