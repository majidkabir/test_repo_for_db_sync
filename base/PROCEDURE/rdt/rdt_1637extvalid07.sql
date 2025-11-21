SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_1637ExtValid07                                  */      
/* Purpose: Validate pallet id before scanned to truck                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author     Purposes                                  */      
/* 2021-01-29 1.0  Chermaine  WMS-16152 Created                         */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1637ExtValid07] (      
   @nMobile                   INT,               
   @nFunc                     INT,               
   @cLangCode                 NVARCHAR( 3),      
   @nStep                     INT,               
   @nInputKey                 INT,               
   @cStorerkey                NVARCHAR( 15),     
   @cContainerKey             NVARCHAR( 10),     
   @cContainerNo              NVARCHAR( 20),     
   @cMBOLKey                  NVARCHAR( 10),     
   @cSSCCNo                   NVARCHAR( 20),     
   @cPalletKey                NVARCHAR( 18),     
   @cTrackNo                  NVARCHAR( 20),     
   @cOption                   NVARCHAR( 1),     
   @nErrNo                    INT           OUTPUT,      
   @cErrMsg                   NVARCHAR( 20) OUTPUT       
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
    
   IF @nInputKey = 1      
   BEGIN      
      IF @nStep = 3    
      BEGIN    
       --Export Pallet Have diff COO    
  
         IF EXISTS (SELECT OrderKey, SKU FROM  
               (SELECT DISTINCT PH.OrderKey, PD.SKU, PD.LOTTABLEVALUE,PH.PickSlipNo    
               FROM PalletDetail PLD WITH (NOLOCK)    
               JOIN PackDetail PD WITH (NOLOCK) ON PLD.caseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey    
               JOIN PackHeader PH WITH (NOLOCK) ON PD.PickslipNo = PH.PickslipNo AND PD.StorerKey = PH.StorerKey    
               JOIN Orders O WITH (NOLOCK) ON PH.orderKey = O.OrderKey AND PH.StorerKey = O.StorerKey    
               JOIN Storer S WITH (NOLOCK) ON PH.StorerKey = S.StorerKey    
               WHERE PH.StorerKey = @cStorerkey    
               AND PLD.PalletKey = @cPalletKey    
               AND O.C_Country <> S.Country ) onePallet  
                    GROUP BY OrderKey, SKU  
                    HAVING COUNT(*) > 1)  
   
         BEGIN    
          SET @nErrNo = 162751  --Pallet Mix Coo    
            GOTO Fail     
         END    
         ELSE    
         BEGIN    
          --Export Container Have diff COO    
         IF EXISTS (SELECT OrderKey, SKU FROM  
                  (SELECT DISTINCT PH.OrderKey, PD.SKU, PD.LOTTABLEVALUE,PH.PickSlipNo    
                  FROM ContainerDetail CD WITH (NOLOCK)    
                  JOIN PALLETDETAIL AS PLD WITH (NOLOCK) ON CD.PalletKey = PLD.PalletKey    
                  JOIN PackDetail PD WITH (NOLOCK) ON PLD.caseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey    
                  JOIN PackHeader PH WITH (NOLOCK) ON PD.PickslipNo = PH.PickslipNo AND PD.StorerKey = PH.StorerKey    
                  JOIN Orders O WITH (NOLOCK) ON PH.orderKey = O.OrderKey AND PH.StorerKey = O.StorerKey    
                  JOIN Storer S WITH (NOLOCK) ON PH.StorerKey = S.StorerKey    
                  WHERE PH.StorerKey = @cStorerkey    
                  AND CD.containerKey = @cContainerKey    
                  AND O.C_Country <> S.Country    
  
                  UNION  
                  SELECT DISTINCT PH.OrderKey, PD.SKU, PD.LOTTABLEVALUE,PH.PickSlipNo    
                  FROM PalletDetail PLD WITH (NOLOCK)    
                  JOIN PackDetail PD WITH (NOLOCK) ON PLD.caseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey    
                  JOIN PackHeader PH WITH (NOLOCK) ON PD.PickslipNo = PH.PickslipNo AND PD.StorerKey = PH.StorerKey    
                  JOIN Orders O WITH (NOLOCK) ON PH.orderKey = O.OrderKey AND PH.StorerKey = O.StorerKey    
                  JOIN Storer S WITH (NOLOCK) ON PH.StorerKey = S.StorerKey    
                  WHERE PH.StorerKey = @cStorerkey   
                  AND PLD.PalletKey = @cPalletKey    
                  AND O.C_Country <> S.Country   
  
                  ) onePallet    
                    GROUP BY OrderKey, SKU  
                    HAVING COUNT(*) > 1)  
   
            BEGIN    
          SET @nErrNo = 162752  --ContainerMixCoo    
            GOTO Fail     
            END    
         END    
      END    
   END      
      
Fail: 

GO