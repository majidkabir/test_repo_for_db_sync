SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Store procedure: rdt_1638ExtVal03                                    */  
/* Copyright: LFLogistics                                               */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 05-03-2021  1.0  YeeKung  CREATED                                     */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1638ExtVal03] (  
   @nMobile      INT,             
   @nFunc        INT,             
   @nStep        INT,  
   @nInputKey    INT,             
   @cLangCode    NVARCHAR( 3),    
   @cFacility    NVARCHAR( 5),    
   @cStorerkey   NVARCHAR( 15),   
   @cPalletKey   NVARCHAR( 30),   
   @cCartonType  NVARCHAR( 10),   
   @cCaseID      NVARCHAR( 20),   
   @cLOC         NVARCHAR( 10),   
   @cSKU         NVARCHAR( 20),   
   @nQTY         INT,              
   @cLength      NVARCHAR(5),      
   @cWidth       NVARCHAR(5),      
   @cHeight      NVARCHAR(5),      
   @cGrossWeight NVARCHAR(5),      
   @nErrNo       INT           OUTPUT,  
   @cErrMsg      NVARCHAR( 20) OUTPUT   
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nFunc = 1638 -- Scan to pallet  
   BEGIN  
      IF @nStep = 3 -- CaseID  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Get 1st case on pallet  
            IF EXISTS (SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey=@cPalletKey)  
    BEGIN  
     DECLARE @c_ChkCode NVARCHAR(20)  
     SET @c_ChkCode = ''  
     SELECT TOP 1 @c_ChkCode = isnull(o.ExternOrderKey,'')  
     FROM dbo.PALLETDETAIL pkd WITH (NOLOCK) JOIN dbo.PackDetail pld ON pld.LabelNo = pkd.CaseId  
     JOIN dbo.PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pld.PickSlipNo  
     JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey=ph.OrderKey  
     WHERE PalletKey=@cPalletKey AND pkd.PalletLineNumber='00001'  
      
     IF @c_ChkCode <> ''  
      BEGIN  
       declare @c_Code NVARCHAR(20)  
       SET @c_Code = ''         
      
       SELECT TOP 1 @c_Code = isnull(o.ExternOrderKey,'')  
       FROM dbo.PackDetail pd WITH (NOLOCK) JOIN dbo.PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo  
       JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey  
       WHERE pd.LabelNo = @cCaseID  
      
      
  
         IF @c_Code <> @c_ChkCode  
          BEGIN  
          SET @nErrNo = 103251  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Consignee  
          GOTO Quit  
          END  
      END  
    END  
   END  
  END  
 END  
  
  
Quit:  
  
END

GO