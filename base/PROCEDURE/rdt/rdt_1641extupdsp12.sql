SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1641ExtUpdSP12                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Called from: rdtfnc_Pallet_Build                                     */ 
/*              Transfer 02->08                                         */ 
/*                                                                      */  
/* Purpose: Build pallet & palletdetail                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author    Purposes                                  */  
/* 2021-11-05  1.0  Chermaine WMS-18186 Created                         */
/* 2022-05-20  1.1  YeeKung   WMS-19685 Left country,2 (yeekung01)      */
/* 2022-12-01  1.2  YeeKung   WMS-21215 Add userdefine10(yeekung02)     */
/* 2023-02-10  1.3  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1641ExtUpdSP12] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
   @cStorerKey  NVARCHAR( 15),  
   @cDropID     NVARCHAR( 20), 
   @cUCCNo      NVARCHAR( 20),
   @nErrNo      INT          OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @nStep         INT,
            @nInputKey     INT,
            @nTranCount    INT,
            @bSuccess      INT,
            @nPD_Qty       INT,
            @cSKU          NVARCHAR( 20),
            @cDocType      NVARCHAR( 1),
            @cRouteCode    NVARCHAR( 30),
            @cOrderKey     NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cMarketPlace      NVARCHAR( 30),
            @cSalesMan         NVARCHAR( 30),
            @cShipperKey       NVARCHAR( 15),
            @cRoute            NVARCHAR( 30), 
            @cOdrCountry       NVARCHAR( 30),
            @cPalletLineNumber NVARCHAR( 5),
            @cTrackingNumber01 NVARCHAR(20)='',
            @cTrackingNumber02 NVARCHAR(20)='', 
            @cTrackingNumber03 NVARCHAR(20)='',
            @cTrackingNumber04 NVARCHAR(20)='',
            @cTrackingNumber05 NVARCHAR(20)='',
            @cTrackingNumber06 NVARCHAR(20)='',
            @cTrackingNumber07 NVARCHAR(20)='', 
            @cPalletCaseID NVARCHAR(20),
            @cOrderGroup   NVARCHAR(20),
            @cBID          NVARCHAR(20) --(yeekung02)

   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP12
   
   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check if pallet id exists before
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.Pallet WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cDropID
                         AND   [Status] < '9')
         BEGIN
            -- Insert Pallet info
            INSERT INTO dbo.Pallet (PalletKey, StorerKey) VALUES (@cDropID, @cStorerKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 178551
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
               GOTO RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 178552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn exists
            GOTO RollBackTran
         END

         SELECT TOP 1 @cRouteCode = RefNo2, 
                      @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND (RefNo = @cUCCNo OR Dropid = @cUCCNo)  

         SELECT @cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo
         
         SELECT 
            @cDocType = DocType,
            @cOdrCountry  = C_Country,
            @cRoute = ROUTE,
            @cShipperKey = shipperKey,
            @cSalesMan = Salesman,
            @cOrderGroup = ordergroup,
            @cBID    = userdefine10
         FROM Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey =  @cOrderKey

         IF @cOrderGroup<>'aCommerce'
         BEGIN
            SELECT @cMarketPlace = Long 
            FROM codelkup WITH (NOLOCK) 
            WHERE listName = 'COURIERLBL' 
               AND storerKey = @cStorerKey 
               AND code = @cSalesMan
         END
         ELSE
         BEGIN
            SELECT 
               @cMarketPlace = oi.Platform 
            FROM Orders O WITH (NOLOCK)
               JOIN orderinfo OI (Nolock) ON O.orderkey=OI.orderkey
            WHERE StorerKey = @cStorerKey
               AND o.OrderKey =  @cOrderKey
         END

         SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cDropID

         IF @cDocType = 'N' --b2b
         BEGIN
         	SELECT @cSKU = SKU,
                @nPD_Qty = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   DropID = @cUCCNo
            GROUP BY SKU
            
            INSERT INTO dbo.PalletDetail 
            (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02) 
            VALUES
            (@cDropID, @cPalletLineNumber, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cOdrCountry+@cRoute+@cBID, @cOrderKey)  --(yeekung02)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 178553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
               GOTO RollBackTran
            END
         END
         ELSE
         --b2c
         BEGIN
         	SELECT @cSKU = SKU,
                @nPD_Qty = ISNULL( SUM( Qty), 0)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   RefNo = @cUCCNo
            GROUP BY SKU
            
            INSERT INTO dbo.PalletDetail 
            (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02) 
            VALUES
            (@cDropID, @cPalletLineNumber, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, LEFT(@cOdrCountry,2)+@cShipperKey+@cMarketPlace, @cOrderKey) --yeekung01

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 178554
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
               GOTO RollBackTran
            END
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND   PalletKey = @cDropID
                         AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 178555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pkey not found
            GOTO RollBackTran
         END

         DECLARE @nPackCarton INT,
                  @nPalletCarton INT,
                  @cpalletorderkey nvarchar(10)


         DECLARE C_PalletOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT  DISTINCT UserDefine02  
         FROM dbo.PalletDetail WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   PalletKey = @cDropID  
         AND   [Status] < '9' 

         OPEN C_PalletOrder    
         FETCH NEXT FROM C_PalletOrder INTO @cpalletorderkey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT @nPackCarton=COUNT(DISTINCT PD.LabelNo) 
            from packdetail PD(Nolock) join
            packheader PH (nolock) ON PD.PickSlipNo=PH.PickSlipNo
            where PH.StorerKey=@cStorerKey
            and PH.OrderKey=@cpalletorderkey

            SELECT @nPalletCarton=count(1)
            from palletdetail (nolock)
            where UserDefine02=@cpalletorderkey
            and storerkey=@cStorerKey

            IF (@nPalletCarton<>@nPackCarton)
            BEGIN  
               SET @nErrNo = 178556
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Short scan 
                  
               IF ISNULL(@cTrackingNumber07 ,'')=''
               BEGIN
                  DECLARE C_PalletCaseID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT caseid
                  from palletdetail (nolock)
                  where UserDefine02=@cpalletorderkey
                  and storerkey=@cStorerKey    
                  and caseid in (SELECT refno
                                 from packdetail PD(Nolock) join
                                 packheader PH (nolock) ON PD.PickSlipNo=PH.PickSlipNo
                                 where PH.StorerKey=@cStorerKey
                                 and PH.OrderKey=@cpalletorderkey)

                  OPEN C_PalletCaseID
                  FETCH NEXT FROM C_PalletCaseID INTO @cPalletCaseID
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF ISNULL(@cTrackingNumber07,'')<>''
                        BREAK;

                     IF ISNULL(@cTrackingNumber01,'')=''
                        SET @cTrackingNumber01 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber02,'')=''
                        SET @cTrackingNumber02 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber03,'')=''
                        SET @cTrackingNumber03 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber04,'')=''
                        SET @cTrackingNumber04 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber05,'')=''
                        SET @cTrackingNumber05 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber06,'')=''
                        SET @cTrackingNumber06 = @cPalletCaseID 
                     ELSE IF ISNULL(@cTrackingNumber07,'')=''
                        SET @cTrackingNumber07 = @cPalletCaseID 

                     FETCH NEXT FROM C_PalletCaseID INTO @cPalletCaseID
                  END
                  CLOSE C_PalletCaseID;
                  DEALLOCATE C_PalletCaseID;
               END
            END  

            FETCH NEXT FROM C_PalletOrder INTO @cpalletorderkey
         END
            
         CLOSE C_PalletOrder;
         DEALLOCATE C_PalletOrder;

         IF @nErrNo<>''
         BEGIN
            GOTO RollBackTran
         END

         -- Insert transmitlog2 here
         EXEC ispGenTransmitLog2 
            @c_TableName      = 'WSPALLETCFMLOG', 
            @c_Key1           = @cStorerKey,
            @c_Key2           = '', 
            @c_Key3           = @cDropID, 
            @c_TransmitBatch  = '', 
            @b_Success        = @bSuccess    OUTPUT,
            @n_err            = @nErrNo      OUTPUT,
            @c_errmsg         = @cErrMsg     OUTPUT    
      
         IF @bSuccess <> 1 
            GOTO RollBackTran

         UPDATE dbo.PALLETDETAIL WITH (ROWLOCK) SET 
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 178557
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
            GOTO RollBackTran
         END

         UPDATE dbo.PALLET WITH (ROWLOCK) SET 
            [Status] = '9'
         WHERE StorerKey = @cStorerKey
         AND   PalletKey = @cDropID
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 178558
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd plt fail
            GOTO RollBackTran
         END
      END
   END
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP12


   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP12

      IF ISNULL(@cTrackingNumber01,'')<>''
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  
            @cTrackingNumber01 ,
            @cTrackingNumber02 ,
            @cTrackingNumber03 ,
            @cTrackingNumber04 ,
            @cTrackingNumber05 ,
            @cTrackingNumber06 ,
            @cTrackingNumber07
  
Fail:  
END  

GO