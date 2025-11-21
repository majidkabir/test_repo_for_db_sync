SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1720ExtValidSP01                                */  
/* Purpose: Validate                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-04-21 1.2  ChewKP     SOS#368705 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1720ExtValidSP01] (  
     @nMobile        INT, 
      @nFunc          INT, 
      @cLangCode      NVARCHAR( 3),  
      @nStep          INT, 
      @cStorerKey     NVARCHAR( 15), 
      @cFacility      NVARCHAR( 5), 
      @cFromPalletID  NVARCHAR( 20), 
      @cToPalletID    NVARCHAR( 20), 
      @cDropID        NVARCHAR( 20), 
      @nErrNo         INT           OUTPUT, 
      @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1720  
BEGIN  
   
    DECLARE @cConsigneeKey   NVARCHAR(15)
           ,@cToConsigneeKey NVARCHAR(15)
    
    IF @nStep = 2
    BEGIN
         SET @cConsigneeKey = ''

         SELECT TOP 1 @cConsigneeKey = O.M_ISOCntryCode
         FROM dbo.PalletDetail PLTD WITH (NOLOCK)
         JOIN dbo.PackDetail PACKD WITH (NOLOCK) ON (PLTD.StorerKey = PACKD.StorerKey AND PLTD.CaseID = PACKD.LabelNo)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PACKD.StorerKey = PH.StorerKey AND PACKD.PickSlipNo = PH.PickSlipNo)
         JOIN dbo.Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND PH.LoadKey = O.LoadKey)
         WHERE PLTD.PalletKey = @cFromPalletID
            AND PLTD.StorerKey = @cStorerKey
         
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE PalletKey = @cToPalletID ) 
         BEGIN 
            SELECT TOP 1 @cToConsigneeKey = O.M_ISOCntryCode
            FROM dbo.PalletDetail PLTD WITH (NOLOCK)
            JOIN dbo.PackDetail PACKD WITH (NOLOCK) ON (PLTD.StorerKey = PACKD.StorerKey AND PLTD.CaseID = PACKD.LabelNo)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PACKD.StorerKey = PH.StorerKey AND PACKD.PickSlipNo = PH.PickSlipNo)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.StorerKey = O.StorerKey AND PH.LoadKey = O.LoadKey)
            WHERE PLTD.PalletKey = @cToPalletID
               AND PLTD.StorerKey = @cStorerKey   
   
            IF ISNULL(@cConsigneeKey,'' ) <> ISNULL(@cToConsigneeKey,'' ) 
            BEGIN
               SET @nErrNo = 99101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DiffConsignee
               GOTO QUIT
            END 
         END
    END
    
    
    

   
END  
  
QUIT:  

 

GO