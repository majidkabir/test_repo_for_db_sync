SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd05                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-09-17 1.0  James      WMS-10651 Created                         */  
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtUpd05] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cContainerKey             NVARCHAR( 10), 
   @cMBOLKey                  NVARCHAR( 10), 
   @cSSCCNo                   NVARCHAR( 20), 
   @cPalletKey                NVARCHAR( 18), 
   @cTrackNo                  NVARCHAR( 20), 
   @cOption                   NVARCHAR( 1), 
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount  INT
   DECLARE @nPickDQty   INT
   DECLARE @nCaseCnt    INT
   DECLARE @bSuccess    INT
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cExternOrderKey   NVARCHAR( 20)
   DECLARE @cCartonCount      NVARCHAR( 5)
   DECLARE @cContainerType    NVARCHAR( 10)
   DECLARE @cPalletID         NVARCHAR( 18)
   DECLARE @nMUID             INT

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 1637 -- Scan to container
   BEGIN
      IF @nStep = 3 -- PalletKey
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cContainerType = ContainerType 
            FROM dbo.CONTAINER WITH (NOLOCK)
            WHERE ContainerKey = @cContainerKey

            IF NOT EXISTS ( SELECT 1 FROM dbo.OTMIDTrack WITH (NOLOCK)
                            WHERE PalletKey = @cPalletKey
                            AND   MUStatus = '8') AND @cContainerType = 'LCLPLT'
            BEGIN
               SELECT TOP 1 @cOrderKey = OrderKey, @cSKU = SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND   ID = @cPalletKey
               AND   [Status] < '9'
               ORDER BY 1

               SELECT @cExternOrderKey = ExternOrderKey
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey

               SELECT @nPickDQty = ISNULL( SUM( Qty), 0)
               FROM dbo.PICKDETAIL WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND   ID = @cPalletKey
               AND   [Status] < '9'

               SELECT @nCaseCnt = CaseCnt
               FROM dbo.SKU SKU WITH (NOLOCK)
               JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
               WHERE SKU.StorerKey = @cStorerkey
               AND   SKU.SKU = @cSKU

               SELECT @cCartonCount = CEILING ( @nPickDQty/CONVERT( DECIMAL(4,2), @nCaseCnt))

               INSERT INTO dbo.OTMIDTrack 
                  ( PalletKey, Principal, MUStatus, OrderID, ShipmentID, Length, Width, Height, GrossWeight, GrossVolume, TruckID,
                    MUType, DropLoc, ExternOrderKey, ConsigneeKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05 )
               VALUES 
                  ( @cPalletKey, @cStorerKey, '8', @cExternOrderKey, @cOrderKey, 1, 1, 1 , 1, 1, @cOrderKey,
                    'OTMPLT', '', @cExternOrderKey, '', @cCartonCount, '', '', '', '' )

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 144001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS OTMIDT ERR
                  GOTO Quit
               END
            END
         END         
      END         

      IF @nStep = 6 -- Close Container
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cContainerType = ContainerType 
            FROM dbo.CONTAINER WITH (NOLOCK)
            WHERE ContainerKey = @cContainerKey

            IF @cContainerType = 'LCLPLT'
            BEGIN
               DECLARE CUR_OTMLog CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT DISTINCT PalletKey
               FROM dbo.ContainerDetail WITH (NOLOCK)
               WHERE ContainerKey = @cContainerKey
               ORDER BY 1
               OPEN CUR_OTMLog
               FETCH NEXT FROM CUR_OTMLog INTO @cPalletID
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SELECT @nMUID = MUID
                  FROM dbo.OTMIDTrack WITH (NOLOCK)
                  WHERE MUStatus = '8'
                  AND   PalletKey = @cPalletID 

                  EXEC dbo.ispGenOTMLog 
                     @c_TableName     = 'IDTCK5OTM', 
                     @c_Key1          = @nMUID, 
                     @c_Key2          = '', 
                     @c_Key3          = @cStorerKey, 
                     @c_TransmitBatch = '',
                     @b_Success       = @bSuccess OUTPUT,
                     @n_err           = @nErrNo   OUTPUT,
                     @c_errmsg        = @cErrMsg  OUTPUT    

                  IF @bsuccess <> 1        
                  BEGIN        
                     SET @nErrNo = 144002        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS OTMLOG ERR    
                     GOTO Quit  
                  END   

                  FETCH NEXT FROM CUR_OTMLog INTO @cPalletID
               END
               CLOSE CUR_OTMLog
               DEALLOCATE CUR_OTMLog
            END
         END
      END
   END

   GOTO Quit
   
RollBackTran:  
      ROLLBACK TRAN rdt_1637ExtUpd05  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  

GO