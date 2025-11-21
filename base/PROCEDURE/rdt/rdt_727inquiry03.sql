SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry03                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-03-05 1.0  Ung      WMS-4201 Created                               */
/* 2019-09-20 1.1  YeeKung  WMS-10536 Change the parameter                 */  
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry03] (
 	 @nMobile    		INT,               
	 @nFunc      		INT,               
	 @nStep      		INT,                
	 @cLangCode  		NVARCHAR( 3),      
	 @cStorerKey 		NVARCHAR( 15),      
	 @cOption    		NVARCHAR( 1),      
	 @cParam1Label    NVARCHAR(20), 
	 @cParam2Label    NVARCHAR(20),   
	 @cParam3Label    NVARCHAR(20),   
	 @cParam4Label    NVARCHAR(20),  
	 @cParam5Label    NVARCHAR(20),  
	 @cParam1         NVARCHAR(20),   
	 @cParam2         NVARCHAR(20),   
	 @cParam3         NVARCHAR(20),   
	 @cParam4         NVARCHAR(20),   
	 @cParam5         NVARCHAR(20),          
	 @cOutField01  	NVARCHAR(20) OUTPUT,    
	 @cOutField02  	NVARCHAR(20) OUTPUT,    
	 @cOutField03  	NVARCHAR(20) OUTPUT,    
	 @cOutField04  	NVARCHAR(20) OUTPUT,    
	 @cOutField05  	NVARCHAR(20) OUTPUT,    
	 @cOutField06  	NVARCHAR(20) OUTPUT,    
	 @cOutField07  	NVARCHAR(20) OUTPUT,    
	 @cOutField08  	NVARCHAR(20) OUTPUT,    
	 @cOutField09  	NVARCHAR(20) OUTPUT,    
	 @cOutField10  	NVARCHAR(20) OUTPUT,
	 @cOutField11  	NVARCHAR(20) OUTPUT,
	 @cOutField12  	NVARCHAR(20) OUTPUT,
	 @cFieldAttr02 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr04 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr06 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr08 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr10 	NVARCHAR( 1) OUTPUT,        
	 @nNextPage    	INT          OUTPUT,    
	 @nErrNo     		INT 			 OUTPUT,        
	 @cErrMsg    		NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0

   IF @cOption = '1' -- KA outbound VAS
   BEGIN
      IF @nStep = 2
      BEGIN
         DECLARE @cID         NVARCHAR( 18)
         DECLARE @cPickSlipNo NVARCHAR( 10)
         DECLARE @cSKU        NVARCHAR( 20)
         DECLARE @cConsigneeKey NVARCHAR( 15)
         
         DECLARE @cUDF01      NVARCHAR( 30)
         DECLARE @cUDF02      NVARCHAR( 30)
         DECLARE @cUDF03      NVARCHAR( 30)
         DECLARE @cUDF04      NVARCHAR( 30)
         DECLARE @cUDF05      NVARCHAR( 30)

         -- Parameter mapping
         SET @cID = @cParam1
         SET @cPickSlipNo = @cParam2
         SET @cSKU = @cParam3

         -- Check both ID and PSNO blank
         IF @cID = '' AND @cPickSlipNo = ''
         BEGIN
            SET @nErrNo = 120451
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID/PSNO
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- ID
            GOTO QUIT
         END

         -- Check both ID and PSNO key-in
         IF @cID <> '' AND @cPickSlipNo <> ''
         BEGIN
            SET @nErrNo = 120452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either ID/PSNO
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- ID
            GOTO QUIT
         END
         
         -- ID
         IF @cID <> ''
         BEGIN
            -- Check ID valid
            IF NOT EXISTS( SELECT 1 
               FROM PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND DropID = @cID)
            BEGIN
               SET @nErrNo = 120453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
               EXEC rdt.rdtSetFocusField @nMobile, 2  -- ID
               GOTO QUIT
            END
         END
         
         -- PickSlipNo
         IF @cPickSlipNo <> ''
         BEGIN
            -- Get PickHeader info
            DECLARE @cOrderKey NVARCHAR(10)
            DECLARE @cLoadKey NVARCHAR(10)
            DECLARE @cZone NVARCHAR(18)
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cLoadKey = ExternOrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Check PSNO valid
            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 120454
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PSNO
               EXEC rdt.rdtSetFocusField @nMobile, 4  -- PickSlipNo
               GOTO Quit
            END

            -- Cross dock PickSlip
            IF @cZone IN ('XD', 'LB', 'LP')
            BEGIN
               -- Check diff storer
               IF EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = RKL.Orderkey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                    AND O.StorerKey <> @cStorerKey)
               BEGIN
                  SET @nErrNo = 120455
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
                  GOTO Quit
               END
            END
      
            -- Discrete PickSlip
            ELSE IF @cOrderKey <> ''
            BEGIN
               -- Get order info
               DECLARE @cChkStorerKey NVARCHAR(15)
               SELECT @cChkStorerKey = StorerKey
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               
               -- Check storer
               IF @cChkStorerKey <> @cStorerKey
               BEGIN
                  SET @nErrNo = 120456
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
                  GOTO Quit
               END
            END
               
            -- Conso PickSlip
            ELSE IF @cLoadKey <> ''
            BEGIN
               -- Check diff storer
               IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)    
                  WHERE LPD.LoadKey = @cLoadKey 
                     AND O.StorerKey <> @cStorerKey)
               BEGIN
                  SET @nErrNo = 120457
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer
                  GOTO Quit
               END
            END
         END
         
         -- SKU
         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 120458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
            EXEC rdt.rdtSetFocusField @nMobile, 6  -- SKU
            GOTO QUIT
         END
         
         -- Get consignee SKU info
         SET @cConsigneeKey = ''
         IF @cID <> ''
            SELECT TOP 1 
               @cConsigneeKey = ConsigneeKey 
            FROM Orders O WITH (NOLOCK) 
               JOIN Pickdetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE O.StorerKey  = @cStorerKey
               AND PD.DropID = @cID

         ELSE -- PickSlipNo
            SELECT TOP 1 
               @cConsigneeKey = O.ConsigneeKey
            FROM Orders O WITH (NOLOCK) 
               JOIN PickHeader PH WITH (NOLOCK) ON (O.OrderKey = PH.OrderKey)
            WHERE O.StorerKey  = @cStorerKey
               AND PH.PickHeaderKey = @cPickSlipNo

         -- Check consignee
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 120459
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Consignee 
            GOTO QUIT
         END
         
         -- Get consignee SKU info
         SELECT 
            @cUDF01 = UDF01, 
            @cUDF02 = UDF02, 
            @cUDF03 = UDF03, 
            @cUDF04 = UDF04, 
            @cUDF05 = UDF05 
         FROM ConsigneeSKU WITH (NOLOCK)
         WHERE ConsigneeKey = @cConsigneeKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU

         -- Check consignee SKU
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 120460
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoConsigneeSKU
            GOTO QUIT
         END
               
         SET @cOutfield01 = '1. ' + LEFT( @cUDF01, 17)
         SET @cOutField02 = '2. ' + LEFT( @cUDF02, 17)
         SET @cOutField03 = '3. ' + LEFT( @cUDF03, 17)
         SET @cOutField04 = '4. ' + LEFT( @cUDF04, 17)
         SET @cOutField05 = '5. ' + LEFT( @cUDF05, 17)
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         
         SET @nNextPage = 0  
      END
   END

Quit:

END

GO