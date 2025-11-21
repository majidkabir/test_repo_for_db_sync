SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store procedure: rdt_1663ExtVal23                                          */  
/* Copyright      : LF Logistics                                              */  
/*                  Copy from     rdt_1663ExtVal11->23                        */ 
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */   
/* 2023-03-09 1.0  yeekung  WMS-21938 Created                                 */  
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1663ExtVal23](  
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cPalletKey    NVARCHAR( 20),   
   @cPalletLOC    NVARCHAR( 10),   
   @cMBOLKey      NVARCHAR( 10),   
   @cTrackNo      NVARCHAR( 20),   
   @cOrderKey     NVARCHAR( 10),   
   @cShipperKey   NVARCHAR( 15),    
   @cCartonType   NVARCHAR( 10),    
   @cWeight       NVARCHAR( 10),   
   @cOption       NVARCHAR( 1),    
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @tOrders TABLE  
   (  
      OrderKey   NVARCHAR( 10) NOT NULL,  
      --UserDefine04 NVARCHAR( 40) NOT NULL  --WinSern  
      TrackingNo NVARCHAR( 40) NOT NULL  --(james01)  
   )  
  
   IF @nFunc = 1663 -- TrackNoToPallet  
   BEGIN  
      IF @nStep = 3 -- Track no  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            DECLARE @cCCountry      NVARCHAR( 30)  
            DECLARE @cOrderType     NVARCHAR( 10)  
            DECLARE @cUserDefine02  NVARCHAR( 20)  
  
            DECLARE @cOtherOrderkey    NVARCHAR( 10)  
            DECLARE @cOtherCCountry    NVARCHAR( 30)  
            DECLARE @cOtherOrderType   NVARCHAR( 10)  
            DECLARE @cOtherUserDefine02 NVARCHAR( 20)  
            DECLARE @cOtherShipperkey  NVARCHAR( 20)  
            DECLARE @cCourrierGroup  NVARCHAR( 20)  
            DECLARE @cOtherCourrierGroup  NVARCHAR( 20) 
            DECLARE @cMContact2 NVARCHAR( 20)
            DECLARE @cOtherMContact2 NVARCHAR( 20)
  
            -- Get order info  
            SET @cUserDefine02 = ''  
            SET @cCCountry = ''  
            SET @cOrderType = ''  
            SELECT  
               @cUserDefine02 = ISNULL( RTRIM( UserDefine02), ''),   
               @cCCountry = ISNULL( RTRIM( C_Country), ''),   
               @cOrderType = ISNULL( RTRIM( Type), ''),
               @cMContact2 = ISNULL(M_Contact2,'')
             --  @cShipperkey =ISNULL( RTRIM( shipperkey), '')  
            FROM dbo.Orders WITH (NOLOCK)  
            WHERE OrderKey = @cOrderKey  
  
            SELECT @cCourrierGroup=short   
            FROM codelkup (NOLOCK)   
            where UDF01 = @cMContact2  
               AND storerkey = @cStorerkey  
               AND listname = 'CourierVal'  
  
            IF @@Rowcount=0  
            BEGIN  
               SET @nErrNo = 197651  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GroupNoSetup  
               GOTO QUIT  
            END  
  
            -- Get other order, on this pallet  
            SET @cOtherOrderKey = ''  
            SELECT TOP 1   
               @cOtherOrderKey = O.OrderKey  
            FROM dbo.MBOLDetail MD WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = MD.OrderKey)  
            WHERE MD.MBOLKey = @cMBOLKey  
               AND O.OrderKey <> @cOrderKey  
  
            -- Other order  
            IF @cOtherOrderKey <> ''  
            BEGIN  
               -- Get other order info  
               SET @cOtherUserDefine02 = ''  
               SET @cOtherCCountry = ''  
               SET @cOtherOrderType = ''  
               SET @cOtherCourrierGroup=''  
               SET @cOtherShipperkey=''  
               SELECT  
                  @cOtherUserDefine02 = ISNULL( RTRIM( UserDefine02), ''),   
                  @cOtherCCountry = ISNULL( RTRIM( C_Country), ''),   
                  @cOtherOrderType = ISNULL( RTRIM( Type), ''),  
                  @cOtherShipperkey =ISNULL( RTRIM( shipperkey), ''), 
                  @cOtherMContact2 = ISNULL(M_Contact2,'')
               FROM dbo.Orders WITH (NOLOCK)  
               WHERE OrderKey = @cOtherOrderKey  
  
               SELECT @cOtherCourrierGroup=short   
               FROM codelkup (NOLOCK)   
               where UDF01 = @cOtherMContact2  
                  and storerkey = @cStorerkey  
                  and listname = 'CourierVal'  
     
               -- Cannot Mix UserDefine02 --  
               IF @cUserDefine02 <> @cOtherUserDefine02  
               BEGIN  
                  SET @nErrNo = 197652  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UDF02 Diff  
                  GOTO QUIT  
               END  
     
               -- Cannot Mix CCountry --  
               IF @cCCountry <> @cOtherCCountry  
               BEGIN  
                  SET @nErrNo = 197653  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Country Diff  
                  GOTO QUIT  
               END  
     
               -- Cannot Mix OrderType --  
               IF @cOrderType <> @cOtherOrderType  
               BEGIN  
                  SET @nErrNo = 197654  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderTypeDiff  
                  GOTO QUIT  
               END  
  
               IF @cMContact2 <> @cOtherMContact2  
               BEGIN  
                  SET @nErrNo = 197655  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CourierGrpDiff  
                  GOTO QUIT  
               END  
  
            END  
              
            DECLARE @cOtherTrackNo NVARCHAR( 20)  
            DECLARE @nRowCount INT  
  
            -- Get other carton in order  
            SELECT @cOtherTrackNo = TrackingNo  
            FROM CartonTrack WITH (NOLOCK)   
            WHERE LabelNo = @cOrderKey  
               AND CarrierName = @cShipperKey  
               AND TrackingNo <> @cTrackNo  
            SET @nRowCount = @@ROWCOUNT  
              
            -- Order only 1 carton  
            IF @nRowCount = 0  
               GOTO Quit  
              
            -- Order has 2 cartons  
            ELSE IF @nRowCount = 1  
            BEGIN  
               -- Check other carton in another pallet  
               IF EXISTS( SELECT 1  
                  FROM PalletDetail WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                     AND CaseID = @cOtherTrackNo  
                     AND PalletKey <> @cPalletKey)  
               BEGIN  
                  SET @nErrNo = 197656  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT  
                  GOTO Quit  
               END  
            END  
              
            -- Order more then 2 cartons  
            ELSE   
            BEGIN  
               IF EXISTS( SELECT 1  
                  FROM PalletDetail WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                     AND CaseID IN (  
                        SELECT TrackingNo  
                        FROM CartonTrack WITH (NOLOCK)   
                        WHERE LabelNo = @cOrderKey  
                           AND CarrierName = @cShipperKey)  
                     AND PalletKey <> @cPalletKey)  
               BEGIN  
                  SET @nErrNo = 197657  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderInDiffPLT  
                  GOTO Quit  
               END  
            END  
         END  
      END  
   END  
  
Quit:  
  
END 

GO