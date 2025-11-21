SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtVal11                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */ 
/* 2020-08-26 1.0  yeekung  WMS-14798 Created                                 */
/* 2021-10-12 1.1  James    WMS-18058 Add validation based codelkup (james01) */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtVal11](  
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
      ShipperKey NVARCHAR( 15) NOT NULL  
   )  

   DECLARE @cCourrierGroup NVARCHAR( 20) 
   DECLARE @cOtherOrderKey NVARCHAR(20) 
   DECLARE @cOtherCourrierGroup NVARCHAR(20)
   DECLARE @cOtherShipperkey NVARCHAR(20)
   DECLARE @cCode          NVARCHAR( 10) = ''
   DECLARE @cLong          NVARCHAR( 60) = ''
   DECLARE @nMisMatch      INT = 0
   DECLARE @nTtlPickedQty  INT = 0
   DECLARE @nTtlOrderQty   INT = 0
   DECLARE @cPickSlipNo    NVARCHAR( 10) = ''
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @cErrMsg3       NVARCHAR( 20)
   DECLARE @cErrMsg4       NVARCHAR( 20)
   DECLARE @cErrMsg5       NVARCHAR( 20)
   
   IF @nFunc = 1663 -- TrackNoToPallet  
   BEGIN  
      IF @nStep = 3 -- Tracking No  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  

            SELECT @cCourrierGroup=short 
            FROM codelkup (NOLOCK) 
            where code=@cShipperkey
            and storerkey=@cstorerkey
            and listname='CourierVal'

            IF @@Rowcount=0
            BEGIN
               SET @nErrNo = 158501
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
               SET @cOtherCourrierGroup=''
               SET @cOtherShipperkey=''
               SELECT
                  @cOtherShipperkey =ISNULL( RTRIM( shipperkey), '')
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOtherOrderKey

               SELECT @cOtherCourrierGroup=short 
               FROM codelkup (NOLOCK) 
               where code=@cOtherShipperkey
               and storerkey=@cstorerkey
               and listname='CourierVal'

               IF @cOtherCourrierGroup<>@cCourrierGroup
               BEGIN
                  SET @nErrNo = 158502
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CourierGrpDiff
                  GOTO QUIT
               END
            END
            
            -- (james01)
            DECLARE @curCheck CURSOR
            SET @curCheck = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Code, Long 
            FROM dbo.CODELKUP WITH (NOLOCK) 
            WHERE LISTNAME = 'CHKPK4SORT' 
            AND Storerkey = @cStorerKey 
            AND Short = @cFacility
            OPEN @curCheck
            FETCH NEXT FROM @curCheck INTO @cCode, @cLong
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @cCode = '1'
               BEGIN
                  SELECT @nTtlPickedQty = ISNULL( SUM( Qty), 0)
                  FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  AND   [Status] = '5'
                  
                  SELECT @nTtlOrderQty = ISNULL( SUM( EnteredQTY), 0)
                  FROM dbo.ORDERDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  
                  IF @nTtlPickedQty <> @nTtlOrderQty
                  BEGIN
                     SET @nMisMatch = 1
                     BREAK
                  END
               END
               
               IF @cCode = '2' 
               BEGIN
                  SELECT @cPickSlipNo = PickSlipNo
                  FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  
                  IF @cPickSlipNo = ''
                     SET @nMisMatch = 1
                  ELSE
                  BEGIN
                     IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                                     WHERE PickSlipNo = @cPickSlipNo)
                        SET @nMisMatch = 1

                     IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                                     WHERE PickSlipNo = @cPickSlipNo) 
                        SET @nMisMatch = 1
                  END
                  
                  IF @nMisMatch = 1
                     BREAK   
               END
               
               IF @cCode = '3'
               BEGIN
                  DECLARE @tPick TABLE ( SKU NVARCHAR( 20) NOT NULL, Qty INT)
                  DECLARE @tPack TABLE ( SKU NVARCHAR( 20) NOT NULL, Qty INT)
                  
                  INSERT INTO @tPick ( SKU, Qty)
                  SELECT SKU, ISNULL( SUM( Qty), 0)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  GROUP BY SKU
                  
                  INSERT INTO @tPack ( SKU, Qty)
                  SELECT PD.SKU, ISNULL( SUM( PD.Qty), 0)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
                  WHERE PH.OrderKey = @cOrderKey
                  GROUP BY PD.SKU
                  
                  IF EXISTS ( SELECT 1 FROM @tPick Pick 
                              JOIN @tPack Pack ON ( Pick.SKU = Pack.SKU)
                              GROUP BY Pick.SKU, Pack.SKU
                              HAVING SUM( Pick.Qty) <> SUM( Pack.Qty))
                  BEGIN
                     SET @nMisMatch = 1
                     BREAK
                  END

                  SELECT @cPickSlipNo = PickSlipNo
                  FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  
                  DECLARE @TempPickTable  TABLE
                     (
                       RowRef          Int IDENTITY(1,1) Primary key,
                       PickSlipNo      NVARCHAR(10),
                       SKU             NVARCHAR(20) NULL,
                       PickQty         INT  NULL ,
                       PackQty         INT NULL      )
     
                  INSERT INTO @TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                  SELECT @cPickSlipNo, PickDetail.SKU, SUM(Qty) As PickedQty , PK.PackedQty
                  FROM PickDetail WITH (NOLOCK)
                  LEFT JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                        FROM PACKDETAIL WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        GROUP BY PickSlipNo, SKU) AS PK
                        ON PK.PickSlipNo = @cPickSlipNo AND PK.SKU = PickDetail.SKU
                  WHERE OrderKey = @cOrderKey
                  AND   STATUS IN ('5','6','7','8','9')
                  Group By PickDetail.SKU, PK.PackedQty
                    
                  INSERT INTO @TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                  SELECT PickSlipNo, SKU, 0, SUM(QTY) AS PackedQty
                  FROM   PACKDETAIL WITH (NOLOCK)
                  WHERE  PickSlipNo = @cPickSlipNo
                  AND NOT EXISTS(SELECT 1 FROM @TempPickTable TP2 WHERE TP2.PickSlipNo = PACKDETAIL.PickSlipNo
                                 AND TP2.SKU = PACKDETAIL.SKU)
                  GROUP BY PickSlipNo, SKU

                  IF EXISTS ( 
                     SELECT 1 FROM @TempPickTable
                     WHERE PickSlipNo = @cPickSlipNo
                     Having SUM(PickQty) <> SUM(PackQty))
                  BEGIN
                     SET @nMisMatch = 1
                     BREAK
                  END
               END
               
               FETCH NEXT FROM @curCheck INTO @cCode, @cLong
            END
            
            IF @nMisMatch = 1
            BEGIN
               --IF LEN( @cLong) > 20
               --   SET @cErrMsg2 = SUBSTRING( @cLong, 21, 20)
                     
               --SET @cErrMsg1 = SUBSTRING( @cLong, 1, 20)
                     
               --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
               SET @nErrNo = 158504
               SET @cErrMsg = SUBSTRING( @cLong, 1, 20)--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Validate Fail   
                           
               GOTO Quit
            END
         END  
      END  
        
      IF @nStep = 6 -- Close pallet?  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
               IF @cOption = '1' -- Yes  
            BEGIN  
               DECLARE @nPalletTrackNo INT  
               DECLARE @nOrderTrackNo INT  
  
               -- Get pallet info  
               SELECT @nPalletTrackNo = COUNT(1) FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey  
  
               -- Get order in pallet  
               INSERT INTO @tOrders (OrderKey, ShipperKey)  
               SELECT DISTINCT O.OrderKey, O.ShipperKey  
               FROM PalletDetail PD WITH (NOLOCK)  
                  JOIN CartonTrack CT WITH (NOLOCK) ON (PD.StorerKey = @cStorerKey AND PD.CaseID = CT.TrackingNo)  
                  JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey AND O.ShipperKey LIKE CT.CarrierName + '%')  
               WHERE PD.PalletKey = @cPalletKey  
                 
               -- Get all orders track no  
               SELECT @nOrderTrackNo = COUNT(1)  
               FROM CartonTrack CT WITH (NOLOCK)  
                  JOIN @tOrders O ON (CT.LabelNo = O.OrderKey AND O.ShipperKey LIKE CT.CarrierName + '%')  
  
               -- Check all track no scanned  
               IF @nPalletTrackNo <> @nOrderTrackNo  
               BEGIN  
                  SET @nErrNo = 158503 
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllScanned  
                  GOTO Quit  
               END  
            END  
         END  
      END  
   END  
  
Quit:  
  
END  

GO