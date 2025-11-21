SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo4                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Sort and pack extended info to display                      */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-01-02 1.0  James    SOS299153 Created                           */  
/* 2014-05-06 1.1  Chee     Add Additional Error Parameters (Chee01)    */  
/* 2014-05-26 1.2  Chee     Add Mobile Parameter (Chee02)               */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo4]  
   @cLoadKey         NVARCHAR(10),  
   @cOrderKey        NVARCHAR(10),  
   @cConsigneeKey    NVARCHAR(15),  
   @cLabelNo         NVARCHAR(20) OUTPUT,  
   @cStorerKey       NVARCHAR(15),  
   @cSKU             NVARCHAR(20),  
   @nQTY             INT,   
   @cExtendedInfo    NVARCHAR(20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,
   @cLangCode        NVARCHAR(3),
   @bSuccess         INT          OUTPUT,
   @nErrNo           INT          OUTPUT,
   @cErrMsg          NVARCHAR(20) OUTPUT,
   @nMobile          INT                   -- (Chee02)     
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nPickQty       INT, 
           @nPackQty       INT, 
           @nCons_PickQTY  INT, 
           @nCons_PackQTY  INT  

  
   SET @cExtendedInfo  = ''  
   SET @cExtendedInfo2 = ''  

   -- Get pickdetail qty for current load
   SELECT @nPickQty = ISNULL( SUM( PD.Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
   WHERE LPD.LoadKey = @cLoadKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         --AND PD.Status = '0'   no need consider pickdetail status as it will update by pack confirm
         AND PD.QTY > 0
         AND ISNULL(OD.UserDefine04, '') <> 'M'

   -- Get packdetail qty for current load   
   SELECT @nPackQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PH.OrderKey = OD.OrderKey AND PD.SKU = OD.SKU)
   WHERE PH.LoadKey = @cLoadKey
   AND   PH.StorerKey = @cStorerKey
   AND   PD.SKU = @cSKU
   AND   ISNULL( OD.UserDefine04, '') <> 'M'  
   
   SET @nCons_PickQTY = @nPickQty
   SET @nCons_PackQTY = @nPackQTY
   EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nCons_PickQTY OUTPUT
   EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nCons_PackQTY OUTPUT

   SET @cExtendedInfo = 'DEFAULT QTY:' + RTRIM( CAST( @nQTY AS NVARCHAR( 5))) 
   SET @cExtendedInfo2 = 'PACK BLA: ' + RTRIM( CAST( @nCons_PackQTY AS NVARCHAR( 5))) + 
                        '/' + 
                        RTRIM( CAST( @nCons_PickQTY AS NVARCHAR( 5)))


QUIT:  
END -- End Procedure

GO