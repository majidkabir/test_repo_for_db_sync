SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/    
/* Store procedure: rdt_706Event05                                          */    
/*                                                                          */    
/* Modifications log:                                                       */    
/*                                                                          */    
/* Date       Rev  Author    Purposes                                       */    
/* 2021-07-05 1.0  James     WMS-19464 Created                              */   
/****************************************************************************/    
    
CREATE PROC [RDT].[rdt_706Event05] (    
   @nMobile       INT,              
   @nFunc         INT,              
   @cLangCode     NVARCHAR( 3),           
   @nInputKey     INT,              
   @cFacility     NVARCHAR( 5),     
   @cStorerKey    NVARCHAR( 15),    
   @cOption       NVARCHAR( 1),     
   @cRetainValue  NVARCHAR( 10),    
   @cTotalCaptr   INT           OUTPUT,          
   @nStep         INT           OUTPUT,           
   @nScn          INT           OUTPUT,      
   @cLabel1       NVARCHAR( 20) OUTPUT,    
   @cLabel2       NVARCHAR( 20) OUTPUT,    
   @cLabel3       NVARCHAR( 20) OUTPUT,    
   @cLabel4       NVARCHAR( 20) OUTPUT,    
   @cLabel5       NVARCHAR( 20) OUTPUT,    
   @cValue1       NVARCHAR( 60) OUTPUT,    
   @cValue2       NVARCHAR( 60) OUTPUT,    
   @cValue3       NVARCHAR( 60) OUTPUT,    
   @cValue4       NVARCHAR( 60) OUTPUT,    
   @cValue5       NVARCHAR( 60) OUTPUT,    
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,    
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,    
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,    
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,    
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,
   @cExtendedinfo NVARCHAR( 20) OUTPUT,    
   @nErrNo        INT           OUTPUT,    
   @cErrMsg       NVARCHAR( 20) OUTPUT    
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cInputFacility NVARCHAR( 5)
   DECLARE @cInputCarrier  NVARCHAR( 20)
   DECLARE @cInputLabelNo  NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @dOrdUDF10      DATETIME
   DECLARE @cIntermodalVehicle   NVARCHAR( 30)
   DECLARE @cRefNo         NVARCHAR( 20)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cUserName      NVARCHAR( 18)
   
   -- Parameter mapping            
   SET @cInputFacility = @cValue1
   SET @cInputCarrier = @cValue2
   SET @cInputLabelNo = @cValue3    
   
   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nStep =2     
   BEGIN     
      IF @nInputKey='1'        
      BEGIN     
      	SELECT TOP 1 
      	   @cPickSlipNo = PH.PickSlipNo, 
      	   @cRefNo = PD.RefNo,
      	   @cOrderKey = O.OrderKey,
            @dOrdUDF10 = O.UserDefine10, 
            @cIntermodalVehicle = O.IntermodalVehicle, 
            @cStatus = O.Status
      	FROM dbo.PackDetail PD WITH (NOLOCK)
      	JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      	JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey)
      	WHERE PD.LabelNo = @cInputLabelNo
      	AND   PH.StorerKey = @cStorerKey
      	ORDER BY 1
      	
         -- Check if Label No exists          
         IF @cPickSlipNo = ''          
         BEGIN          
            SET @nErrNo = 186101          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Label        
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit          
         END      

         IF CAST( @dOrdUDF10 AS DATE) <> CAST( GETDATE() AS DATE)
         BEGIN          
            SET @nErrNo = 186102          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UDF10        
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit          
         END 
         
         IF @cIntermodalVehicle <> @cInputCarrier
         BEGIN          
            SET @nErrNo = 186103          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Carrier        
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit          
         END 
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtDataCapture WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   V_ID = @cInputLabelNo
                     AND   V_String3 = '706')
         BEGIN          
            SET @nErrNo = 186104          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Label Exists        
            EXEC rdt.rdtSetFocusField @nMobile, 6
            GOTO Quit          
         END 
         
         IF @cRefNo <> @cInputFacility
         BEGIN          
            SET @nErrNo = 186105          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Fac        
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit          
         END 
         
         IF @cStatus IN ( '9', 'CANC')
         BEGIN          
            SET @nErrNo = 186106          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OrdStatus        
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit          
         END 

         INSERT INTO rdt.rdtDataCapture( StorerKey, Facility, V_ID, V_String1, V_String2, V_String3, AddWho, AddDate) VALUES 
         ( @cStorerKey, @cFacility, @cInputLabelNo, @cInputCarrier, @cInputFacility, '706', @cUserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 186107     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins Rec Fail    
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit     
         END
         
         SELECT @cTotalCaptr = COUNT( DISTINCT V_ID)
         FROM rdt.rdtDataCapture WITH (NOLOCK)
         WHERE Facility = @cFacility
         AND   StorerKey = @cStorerKey
         AND   V_String1 = @cInputCarrier
         AND   V_String2 = @cInputFacility
         AND   CAST( AddDate AS DATE) = CAST( GETDATE() AS DATE)
         AND   AddWho = @cUserName
         GROUP BY Facility, StorerKey, V_String1, V_String2, AddWho
         
         EXEC rdt.rdtSetFocusField @nMobile, 6

         --SET @cTotalCaptr = CAST( @cTotalCaptr AS INT) + 1    
      END    
   END    

   Quit:    

GO