SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1666ExtValid03                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2020-01-30  1.0  YeeKung     WMS-11912 Created                       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1666ExtValid03] (  
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
   DECLARE @cPalletID      NVARCHAR( 30)  
   DECLARE @cStatus        NVARCHAR( 10)  
   DECLARE @cOtherMbolKey  NVARCHAR( 20)    
   DECLARE @cOrderKey      NVARCHAR( 20)   
   DECLARE @cOrderGroup    NVARCHAR( 10)  
   DECLARE @cMBOLCarrieragen  NVARCHAR(20)  
   DECLARE @cDestinationCountry  NVARCHAR(20)  
   DECLARE @cOrderCountry NVARCHAR(20)  
   DECLARE @cOrderShipperKey NVARCHAR(20)  
   DECLARE @cMBOLTransm NVARCHAR(20)  
  
   -- Variable mapping  
   SELECT @cMbolKey = Value FROM @tExtValidate WHERE Variable = '@cMbolKey'  
   SELECT @cPalletID = Value FROM @tExtValidate WHERE Variable = '@cPalletID'  
  
   IF @nStep = 2 -- Pallet  
   BEGIN  
      SET @cStatus = ''  
      SELECT TOP 1   
         @cStatus = Status  
      FROM dbo.PALLETDETAIL WITH (NOLOCK)  
      WHERE PalletKey = @cPalletID  
  
      IF @cStatus <> '9'  
      BEGIN  
         SET @nErrNo = 154851  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet Not Close  
         GOTO Quit  
      END  
  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
         CREATE TABLE #OrdersOnPallet (  
            RowRef      INT IDENTITY(1,1) NOT NULL,  
            OrderKey    NVARCHAR(10)  NULL)  
  
         DECLARE @curORD CURSOR    
         SET @curORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT UserDefine02  
         FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE PalletKey = @cPalletID  
         AND   Status = '9'  
         OPEN @curORD  
         FETCH NEXT FROM @curORD INTO @cOrderKey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            INSERT INTO #OrdersOnPallet ( OrderKey) VALUES ( @cOrderKey)  
  
            FETCH NEXT FROM @curORD INTO @cOrderKey  
         END  
  
         SET @cOtherMbolKey = ''  
  
         SELECT TOP 1 @cOtherMbolKey = o.MBOLKey,  
                     @cOrderGroup=o.ordergroup,  
                     @cOrderShipperKey  = (RTRIM(O.shipperkey)+ISNULL(O.M_Company,'')),  
                     @cOrderCountry=o.C_ISOCntryCode   
         FROM dbo.Orders O WITH (NOLOCK)  
         JOIN #OrdersOnPallet T WITH (NOLOCK) ON ( O.OrderKey = T.OrderKey)  
  
         -- Exists in other mbol  
         IF @cOtherMbolKey <> ''  
         BEGIN  
            SET @nErrNo = 154852  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Scanned  
            GOTO Quit  
         END  
  
         SELECT   @cDestinationCountry = DestinationCountry,    
                  @cMBOLCarrieragen = Carrieragent,  
                  @cMBOLTransm = TransMethod    
         FROM dbo.MBOL WITH (NOLOCK)      
         WHERE MbolKey = @cMbolKey     
  
         IF (@cOrderGroup='ECOM')   
         BEGIN  
            IF (@cMBOLTransm<>@cOrderShipperKey) OR (@cOrderCountry<>@cDestinationCountry)   
            BEGIN  
               SET @nErrNo = 154853  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong country  
               GOTO Quit  
            END  
         END  
         ELSE  
         BEGIN  
              
            IF NOT EXISTS (SELECT 1 from dbo.storer (NOLOCK) WHERE susr1 <>@cMBOLCarrieragen and storerkey=@cStorerKey)  
            BEGIN  
               SET @nErrNo = 154854  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong country  
               GOTO Quit  
            END  
         END  
      END  
   END  
   Quit:  
  
END  

GO