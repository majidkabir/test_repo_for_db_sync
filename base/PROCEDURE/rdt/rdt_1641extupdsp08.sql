SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1641ExtUpdSP08                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Called from: rdtfnc_Pallet_Build                                     */ 
/*              Transfer 02->08                                         */ 
/*                                                                      */  
/* Purpose: Build pallet & palletdetail                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-10-29  1.0  YeeKung  WMS-15617 Created                          */
/* 2023-02-10  1.1  YeeKung  WMS-21738 Add UCC column (yeekung01)        */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1641ExtUpdSP08] (  
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
            @cRouteCode    NVARCHAR( 30),
            @cOrderKey     NVARCHAR( 10),
            @cPickSlipNo   NVARCHAR( 10),
            @cPalletLineNumber   NVARCHAR( 5),
            @cTrackingNumber01 NVARCHAR(20)='',
            @cTrackingNumber02 NVARCHAR(20)='', 
            @cTrackingNumber03 NVARCHAR(20)='',
            @cTrackingNumber04 NVARCHAR(20)='',
            @cTrackingNumber05 NVARCHAR(20)='',
            @cTrackingNumber06 NVARCHAR(20)='',
            @cTrackingNumber07 NVARCHAR(20)='', 
            @cPalletCaseID NVARCHAR(20)

   SELECT @nStep = Step,
          @nInputKey = InputKey
   FROM RDT.RDTMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_1641ExtUpdSP08
   
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
               SET @nErrNo = 160251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins plt fail
               GOTO RollBackTran
            END
         END

         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   CaseId = @cUCCNo
                     AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 160252
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn exists
            GOTO RollBackTran
         END

         SELECT TOP 1 @cRouteCode = RefNo2, 
                      @cPickSlipNo = PickSlipNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   RefNo = @cUCCNo

         SELECT @cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo

         SELECT @cPalletLineNumber = RIGHT( '00000' + CAST( CAST( ISNULL(MAX( PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PalletDetail WITH (NOLOCK)
         WHERE PalletKey = @cDropID

         SELECT @cSKU = SKU,
                @nPD_Qty = ISNULL( SUM( Qty), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   RefNo = @cUCCNo
         GROUP BY SKU

         INSERT INTO dbo.PalletDetail 
         (PalletKey, PalletLineNumber, CaseId, StorerKey, Sku, Qty, UserDefine01, UserDefine02) 
         VALUES
         (@cDropID, @cPalletLineNumber, @cUCCNo, @cStorerKey, @cSKU, @nPD_Qty, @cRouteCode, @cOrderKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 160253
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins pltdt fail
            GOTO RollBackTran
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
            SET @nErrNo = 160254
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
               SELECT @nPackCarton=MAX(cartonNo)
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
                  SET @nErrNo = 160257
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail  
                  
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
            SET @nErrNo = 160255
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
            SET @nErrNo = 160256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd pltdt fail
            GOTO RollBackTran
         END
      END
   END
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1641ExtUpdSP08


   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1641ExtUpdSP08

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