SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdtANFSAPExtValid01                                 */    
/* Purpose: Make sure user close carton (to print label) if no more     */
/*          task for current consigneekey + loadkey combination         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2014-05-21 1.0  Chee       Created                                   */
/* 2014-07-24 1.1  Chee       Change @nFunc to 547 (Chee01)             */
/************************************************************************/    
    
CREATE PROC [RDT].[rdtANFSAPExtValid01] (    
   @nMobile       INT,    
   @nFunc         INT,     
   @cLangCode     NVARCHAR( 3),     
   @nStep         INT,    
   @cUserName     NVARCHAR( 18), 
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),     
   @cSKU          NVARCHAR( 20),  
   @cLoadKey      NVARCHAR( 10),     
   @cConsigneeKey NVARCHAR( 15),     
   @cPickSlipNo   NVARCHAR( 10),  
   @cOrderKey     NVARCHAR( 10),  
   @cLabelNo      NVARCHAR( 20),  
   @nErrNo        INT           OUTPUT,     
   @cErrMsg       NVARCHAR( 20) OUTPUT  
)    
AS    
BEGIN

   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    

   IF @nFunc = 547--540 -- (Chee01)
      AND @nStep = 5
   BEGIN    
      DECLARE 
         @cOrderType        NVARCHAR(20)

      SET @nErrNo          = 0   
      SET @cErrMsg         = ''  

      -- Get OrderType 
      SELECT @cOrderType = O.[Type]
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      WHERE LPD.LoadKey = @cLoadKey

      IF ISNULL(@cPickSlipNo, '') = ''
         SELECT TOP 1 
            @cPickSlipNo = PD.PickSlipNo
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey   
           AND PD.StorerKey = @cStorerKey
           AND PD.SKU = @cSKU
           AND PD.Status IN ('3', '5')
           AND OD.Userdefine02 = @cConsigneeKey

      -- If no more task for this consignee in this load, check user printed label or not
      IF NOT EXISTS(SELECT 1
                    FROM dbo.PickDetail PD WITH (NOLOCK) 
                    JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                    JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
                    JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (O.OrderKey = LPD.OrderKey)
                    WHERE LPD.LoadKey = @cLoadKey   
                      AND PD.StorerKey = @cStorerKey
                      AND PD.Status IN ('3', '5')
                      AND OD.Userdefine02 = @cConsigneeKey
                      AND PD.SKU = CASE WHEN @cOrderType = 'DCToDC' THEN @cSKU ELSE PD.SKU END -- DCToDC cannot mix sku
                      AND ISNULL(PD.CaseID, '') = '')
      BEGIN
         IF EXISTS(SELECT 1 
                   FROM dbo.PackDetail PD WITH (NOLOCK)
                   JOIN dbo.DropID D WITH (NOLOCK) ON (D.DropID = PD.LabelNo)
                   JOIN dbo.DropIDDetail DD WITH (NOLOCK) ON (D.DropID = DD.DropID)
                   WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.StorerKey = @cStorerKey
                     AND ((D.DropIDType = '0' AND D.DropLoc = '') OR D.DropIDType = 'PTS')
                     AND D.LabelPrinted <> 'Y'
                     AND D.Status <> '9'
                     AND DD.UserDefine01 = @cConsigneeKey)
         BEGIN
            SET @nErrNo = 88501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelNotPrint
            GOTO Quit
         END
      END -- IF NOT EXISTS
   END -- IF @nFunc = 547 AND @nStep = 5

QUIT:
END

GO