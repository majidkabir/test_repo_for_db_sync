SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
            
/************************************************************************/      
/* Store procedure: rdt_1666ExtValid04                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date        Rev  Author      Purposes                                */      
/* 2021-06-18  1.0  James       WMS-17300 Created                       */    
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_1666ExtValid04] (      
   @nMobile        INT,      
   @nFunc          INT,      
   @cLangCode      NVARCHAR( 3),      
   @nStep          INT,      
   @nInputKey      INT,      
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),      
   @tExtValidate   VariableTable READONLY,      
   @nErrNo         INT           OUTPUT,      
   @cErrMsg        NVARCHAR( 20) OUTPUT      
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @cMbolKey       NVARCHAR( 10)      
   DECLARE @cOrderKey      NVARCHAR( 10)      
   DECLARE @cOtherMbolKey  NVARCHAR( 10)      
   DECLARE @cPalletID      NVARCHAR( 30)      
   DECLARE @cStatus        NVARCHAR( 10)      
   DECLARE @cDestinationCountry        NVARCHAR( 30)      
   DECLARE @cOtherDestinationCountry   NVARCHAR( 30)     
   DECLARE @cOrderCompany              NVARCHAR( 20)    
   DECLARE @cMBOLCompany               NVARCHAR( 20)   
   DECLARE @cMBOLCarrier               NVARCHAR( 20)  
   DECLARE @cOrderCarrier              NVARCHAR( 20)  
   DECLARE @cUserdefine03              NVARCHAR( 20)  
   DECLARE @cTransMethod   NVARCHAR( 30)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cPlatform      NVARCHAR( 20)
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @cErrMsg3       NVARCHAR( 20)
   DECLARE @cDocType       NVARCHAR( 1)
   
   -- Variable mapping      
   SELECT @cMbolKey = Value FROM @tExtValidate WHERE Variable = '@cMbolKey'      
   SELECT @cPalletID = Value FROM @tExtValidate WHERE Variable = '@cPalletID'      
      
   IF @nStep = 1 -- MBOLKey      
   BEGIN      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
         SET @cDestinationCountry = ''      
         SELECT @cDestinationCountry = DestinationCountry      
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey      
      
         IF ISNULL( @cDestinationCountry, '') = ''      
         BEGIN      
            SET @nErrNo = 169351      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Dest Ctry      
            GOTO Quit      
         END      
      END      
   END      
      
   IF @nStep = 2 -- Pallet      
   BEGIN      
      SET @cStatus = ''      
      SELECT TOP 1       
         @cStatus = Status      
      FROM dbo.PALLETDETAIL WITH (NOLOCK)      
      WHERE PalletKey = @cPalletID      
      
      IF @cStatus <> '9'      
      BEGIN      
         SET @nErrNo = 169352      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Not Close      
         GOTO Quit      
      END      
      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
         CREATE TABLE #OrdersOnPallet (      
            RowRef      INT IDENTITY(1,1) NOT NULL,      
            OrderKey    NVARCHAR(10)  NULL,  
            userdefine03 NVARCHAR(20) NULL)     
      
         DECLARE @curORD CURSOR        
         SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT DISTINCT UserDefine02,Userdefine03      
         FROM dbo.PalletDetail WITH (NOLOCK)      
         WHERE PalletKey = @cPalletID      
         AND   Status = '9'      
         OPEN @curORD      
         FETCH NEXT FROM @curORD INTO @cOrderKey,@cUserdefine03      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            INSERT INTO #OrdersOnPallet ( OrderKey,Userdefine03) VALUES ( @cOrderKey,@cUserdefine03)      
      
            FETCH NEXT FROM @curORD INTO @cOrderKey,@cUserdefine03      
         END      
      
         IF EXISTS ( SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                     JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)      
                     WHERE O.Status = '9')      
         BEGIN      
            SET @nErrNo = 169353      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Orders Shipped      
            GOTO Quit      
         END      
      
         SET @cOtherMbolKey = ''      
         SET @cOtherDestinationCountry = ''    
         SET @cOrderCompany   = ''      
         SELECT TOP 1 @cOtherMbolKey = MBOLKey,       
                      @cOtherDestinationCountry = O.C_Country,    
                      @cOrderCompany   = (O.M_company),  
                      @cOrderCarrier = OI.DeliveryMode,
                      @cShipperKey = O.ShipperKey, 
                      @cPlatform = OI.Platform, 
                      @cDocType = O.DocType
         FROM dbo.Orders O WITH (NOLOCK)   
         JOIN dbo.Orderinfo OI WITH (NOLOCK) ON (OI.orderkey=O.orderkey)     
         JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)      
      
         -- Exists in other mbol      
         IF @cOtherMbolKey <> ''      
         BEGIN      
            SET @nErrNo = 169354      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Scanned      
            GOTO Quit      
         END      

         SELECT @cDestinationCountry = DestinationCountry, 
                @cTransMethod = TransMethod      
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey      
      
         IF ( @cDestinationCountry <> @cOtherDestinationCountry OR 
            (RTRIM( @cPlatform) + @cShipperKey) <> @cTransMethod) AND
            @cDocType = 'E'
         BEGIN      
            SET @cErrMsg1 = rdt.rdtgetmessage( 169355, @cLangCode, 'DSP') --Wrong Country/
            SET @cErrMsg2 = rdt.rdtgetmessage( 169356, @cLangCode, 'DSP') --Marketplace/
            SET @cErrMsg3 = rdt.rdtgetmessage( 169357, @cLangCode, 'DSP') --Carrier
               
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
                                 
            SET @nErrNo = 169355      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Country      
            GOTO Quit      
         END      

      END      
   END      
   Quit:      
      
END 

GO