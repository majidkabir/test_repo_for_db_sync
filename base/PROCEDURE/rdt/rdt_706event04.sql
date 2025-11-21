SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/    
/* Store procedure: rdt_706Event04                                          */    
/*                                                                          */    
/* Modifications log:                                                       */    
/*                                                                          */    
/* Date       Rev  Author    Purposes                                       */    
/* 2021-07-05 1.0  James     WMS-17359 Created                              */   
/****************************************************************************/    
    
CREATE PROC [RDT].[rdt_706Event04] (    
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
    
   DECLARE @bSuccess       INT    
   DECLARE @cWayBillNo     NVARCHAR( 60)    
   DECLARE @cSKU           NVARCHAR( 20)    
   DECLARE @cReceiptKey    NVARCHAR( 20)    
   DECLARE @cErrMsg1       NVARCHAR( 20),      
           @cErrMsg2       NVARCHAR( 20),      
           @cErrMsg3       NVARCHAR( 20),      
           @cErrMsg4       NVARCHAR( 20),      
           @cErrMsg5       NVARCHAR( 20)    
   DECLARE @nDay           INT    
   DECLARE @nReceiptdate   Datetime    
   DECLARE @cSKUBarcode    NVARCHAR(20)     
   DECLARE @cOutfield02    NVARCHAR(20)    
   
   --(cc01)
   DECLARE @cReceiptType   NVARCHAR(1),
           @cLottable08    NVARCHAR(30),
           @cLottable09    NVARCHAR(30),
           @cLottable10    NVARCHAR(30),
           @cUserdefine02  NVARCHAR(30),
           @cExtField01    NVARCHAR(30),
           @cExtField02    NVARCHAR(30),
           @cExtField03    NVARCHAR(30),
           @nAsnCount      INT
            
   -- Parameter mapping            
   SET @cWayBillNo = @cValue1    
   SELECT @cTotalCaptr = O_Field11
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
    
   IF @nStep =2     
   BEGIN     
      IF @nInputKey='1'        
      BEGIN     
         -- Check WayBillNo blank          
         IF @cWayBillNo = ''          
         BEGIN          
            SET @nErrNo = 170101          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WayBill# req        
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit          
         END      
            
         -- Check barcode format        
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'WayBillNo', @cWayBillNo) = 0        
         BEGIN        
            SET @nErrNo = 170102       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format        
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            GOTO Quit           
         END      
         
         IF EXISTS ( SELECT 1 FROM rdt.rdtDataCapture WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   Facility = @cFacility
                     AND   V_String1 = @cWayBillNo)
         BEGIN        
            SET @nErrNo = 170103       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WayBill Exists        
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            GOTO Quit           
         END      
         
         INSERT INTO rdt.rdtDataCapture( StorerKey, Facility, V_String1) VALUES
         (@cStorerKey, @cFacility, @cWayBillNo)

         IF @@ERROR <> 0
         BEGIN        
            SET @nErrNo = 170103       
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WayBill UppdErr        
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            GOTO Quit           
         END  
         
         SET @cTotalCaptr = CAST( @cTotalCaptr AS INT) + 1    
      END    
   END    

   Quit:    
   -- Insert event        
   EXEC RDT.rdt_STD_EventLog        
      @cActionType   = '14',        
      @nMobileNo     = @nMobile,        
      @nFunctionID   = @nFunc,        
      @cFacility     = @cFacility,               
      @cStorerKey    = @cStorerKey,        
      @cRefNo1       = @cWayBillNo

GO