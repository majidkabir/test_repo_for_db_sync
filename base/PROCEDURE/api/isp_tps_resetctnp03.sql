SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ResetCtnP03                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-12-29   1.0  YeeKung  TPS-805 Created                                 */
/* 2025-01-28   1.1  YeeKung   UWP-29489 Change API Username (yeekung01)      */
/******************************************************************************/

CREATE    PROC [API].[isp_TPS_ResetCtnP03] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1        OUTPUT,
   @n_Err      INT = 0        OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
BEGIN
   DECLARE  
  
   @nMobile          INT,  
   @nStep            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT,  
   @cSerialno        NVARCHAR(30),  
  
   @cStorerKey       NVARCHAR( 15),  
   @cFacility        NVARCHAR( 5),  
   @nFunc            INT,  
   @cUserName        NVARCHAR( 128),  
   @cScanNo          NVARCHAR( 50),  
   @cDropID          NVARCHAR( 50),  
   @cPickSlipNo      NVARCHAR( 30),  
   @nCartonNo        INT,  
   @cCartonID        NVARCHAR( 20),  
   @cType            NVARCHAR( 30),  
   @nQTY             INT,  
   @cSKU             NVARCHAR( 20),  
   @nWeight          FLOAT,  
   @nCube            FLOAT,  
   @cResetCartonJson NVARCHAR( MAX),  
   @cResetAll        NVARCHAR( 1),  
   @cLoadKey         NVARCHAR( 10),  
   @cOrderKey        NVARCHAR( 10),  
   @nTranCount       INT,  
   @cSQLWhere        NVARCHAR( 250),  
   @cSQLUpdate       NVARCHAR( 500),  
   @cScanNoType      NVARCHAR( 30),  
   @cZone            NVARCHAR( 18),
   @cUCCNo           NVARCHAR( 20),
   @cExtResetCartonSP   NVARCHAR(20),
   @cSQL             NVARCHAR(4000),
   @cSQLParam        NVARCHAR(4000),
   @cTrackingNo      NVARCHAR(20)

   DECLARE @cCurCartonTrack CURSOR 

   --CREATE TABLE #ResetCartonList (  
   DECLARE @ResetCartonList TABLE (  
      SKU   NVARCHAR( 20)  
   )

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN isp_TPS_ResetCtnP03 

   SELECT @cStorerKey = StorerKey, @cFacility = Facility,@nFunc = Func,@cUserName = UserName,@cLangCode = LangCode,@cScanNo = ScanNo,@nCartonNo = CartonNo, @ctype = cType, @cResetCartonJson=ResetCarton, @cResetAll = ResetAll  
   FROM OPENJSON(@json)  
   WITH (  
      StorerKey   NVARCHAR( 30),  
      Facility    NVARCHAR( 30),  
      Func        NVARCHAR( 5),  
      UserName    NVARCHAR( 15),  
      LangCode    NVARCHAR( 3),  
      ScanNo      NVARCHAR( 30),  
      CartonNo    INT,  
      CartonID    NVARCHAR( 20),  
      cType       NVARCHAR( 30),  
      ResetCarton NVARCHAR( max) as JSON,  
      ResetAll    NVARCHAR( 1)  
   )  
  
   SELECT @cStorerKey AS StorerKey, @cFacility AS Facility,@nFunc AS Func,@cUserName AS UserName,@cScanNo AS ScanNo,@nCartonNo AS CartonNo, @cResetAll as ResetAll  
  
   --INSERT INTO #ResetCartonList  
   INSERT INTO @ResetCartonList  
   SELECT *  
   FROM OPENJSON(@cResetCartonJson)  
   WITH (  
         SKU             NVARCHAR( 20)    '$.SKU'  
   )  
  
   --convert login  
   SET @n_Err = 0  
   EXEC [WM].[lsp_SetUser] @c_UserName = @cUserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT  
  
   EXECUTE AS LOGIN = @cUserName  
  
   IF @n_Err <> 0  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = @n_Err  
      SET @c_ErrMsg = @c_ErrMsg  
      GOTO ROLLBACKTRAN  
   END  
  
   --check pickslipNo  
   EXEC [API].[isp_GetPicklsipNo] @cStorerKey,@cFacility,@nFunc,@cLangCode,@cScanNo,@cType,@cUserName, @jResult OUTPUT,@b_Success OUTPUT,@n_Err OUTPUT,@c_ErrMsg OUTPUT  
  
   IF @n_Err <>0  
   BEGIN  
      SET @jResult = ''  
      SET @b_Success = 0  
      SET @n_Err = @n_Err  
      SET @c_ErrMsg = @c_ErrMsg  
  
      GOTO ROLLBACKTRAN  
   END  

   SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=ISNULL(OrderKey,''), @cLoadKey = LoadKey, @cZone = Zone  
   FROM OPENJSON(@jResult)  
   WITH (  
         ScanNoType        NVARCHAR( 30),  
         PickslipNo        NVARCHAR( 30),  
         DropID            NVARCHAR( 30),  
         OrderKey          NVARCHAR( 10),  
         LoadKey           NVARCHAR( 10),  
         Zone              NVARCHAR( 18),  
         EcomSingle        NVARCHAR( 1),  
         DynamicRightName1    NVARCHAR( 30),  
         DynamicRightValue1   NVARCHAR( 30),  
         PickSkuDetail     NVARCHAR( MAX) as json  
   )  
   SELECT @cScanNoType as ScanNoType, @cpickslipNo as PickslipNo, @cDropID as DropID,  @cOrderKey as OrderKey, @cLoadKey as LoadKey, @cZone as Zone 

  
   SELECT @cPickSlipNo AS pickslipno  
   --reset 1 carton  
   IF @cResetAll <> '1'  
   BEGIN  
      -- if hav SKU  
      IF EXISTS (SELECT TOP 1 1 FROM @ResetCartonList)  
      BEGIN  
         DECLARE @nSkuCount   INT  
         DECLARE @nSkuToReset INT  
  
         SELECT @nSkuCount = COUNT(SKU) FROM packDetail WITH (NOLOCK) WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  
         SELECT @nSkuToReset = COUNT(*) FROM @ResetCartonList  

  
         DECLARE curSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
         select SKU FROM @ResetCartonList  
  
         OPEN curSKU;  
         FETCH NEXT FROM curSKU INTO @cSKU  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
  
            --SELECT @nCartonNo,@cPickSlipNo,@cStorerKey,@cSKU  
            IF EXISTS (SELECT TOP 1 1 FROM packDetail PD WITH (NOLOCK) WHERE PD.cartonNo = @nCartonNo AND PD.pickslipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND SKU = @cSKU)  
            BEGIN  

               SET @cCurCartonTrack = CURSOR FOR
               SELECT labelno  
               FROM packDetail (nolock)  
               WHERE cartonNo = @nCartonNo
                  AND pickslipNo = @cPickSlipNo
                  AND storerkey = @cstorerkey  
                  AND sku = @cSKU
                 
               OPEN @cCurCartonTrack;  
               FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno   
               WHILE @@FETCH_STATUS = 0  
               BEGIN 
                  DELETE cartontrack WHERE trackingno = @cTrackingno

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000201  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete CartonTrack. Function : isp_TPS_ResetCtnP03'  
                     GOTO RollBackTran  
                  END 

                  FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno  
               END

  
               --reset the qty : update packInfo  
               IF @nSkuToReset < @nSkuCount  
               BEGIN  
                  SELECT @nQty = SUM(Qty),@nWeight = SUM(Qty)*ISNULL(SUM(sku.WEIGHT),0),@nCube = SUM(Qty)*SUM(sku.CUBE)  
                  FROM packDetail PD WITH (NOLOCK)  
                  JOIN SKU sku WITH (NOLOCK) ON sku.sku = PD.sku AND SKU.StorerKey = PD.StorerKey  
                  WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo AND PD.StorerKey = @cStorerKey  
  
                  UPDATE packInfo WITH (ROWLOCK)  
                  SET Qty = @nQty,  
                     WEIGHT = @nWeight,  
                     CUBE = @nCube,  
                     EditDate = GETDATE(),  
                     EditWho = @cUserName,  
                     TrafficCop = NULL  
                  WHERE cartonNo = @nCartonNo  
                     AND PickSlipNo = @cPickSlipNo  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000202  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update packinfo. Function : isp_TPS_ResetCtnP03' 
                     GOTO RollBackTran  
                  END  
  
               END  
               --delete packInfo  
               ELSE IF @nSkuToReset = @nSkuCount  
               BEGIN  
                  SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

                  DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
                  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000203  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packinfo. Function : isp_TPS_ResetCtnP03' 
                     GOTO RollBackTran  
                  END

                  UPDATE UCC
                  SET status='3',
                     EditDate = GETDATE(),  
                     EditWho = @cUserName
                  WHERE UCCNO = @cUCCNo
                     AND Status in ('1','2','3','4','6')

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000204  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update ucc. Function : isp_TPS_ResetCtnP03' 
                     GOTO RollBackTran  
                  END
               END  

               IF EXISTS(SELECT 1 FROM packserialno (NOLOCK)    
                        WHERE pickslipno=@cpickslipNo    
                           AND storerkey=@cStorerKey    
                           AND sku=@csku)    
               BEGIN    
                  SELECT @cSerialno=serialno  
                  FROM packserialno (nolock)  
                  WHERE pickslipno=@cpickslipNo    
                  AND storerkey=@cStorerKey    
                  AND sku=@csku  
  
                  DELETE packserialno  
                  WHERE pickslipno=@cpickslipNo    
                     AND storerkey=@cStorerKey    
                     AND sku=@csku  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000210  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packserialno. Function : isp_TPS_ResetCtnP03' 
                     GOTO RollBackTran   
                  END  
  
                  IF EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)      
                        WHERE Storerkey = @cStorerKey          
                        AND SKU = @cSKU      
                        AND SerialNo = @cSerialno   
                        AND STATUS IN( '1','6'))    
                  BEGIN    
                     UPDATE SerialNo WITH (ROWLOCK)  
                     SET   STATUS='1',  
                           ORDERKEY='',
                           OrderLineNumber='',
                           EditDate = GETDATE(),  
                           EditWho = @cUserName  
                     WHERE Storerkey = @cStorerKey  
                     AND SKU = @cSKU      
                     AND SerialNo = @cSerialno   
                     AND STATUS  IN( '1','6'  )
                 
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @b_Success = 0  
                        SET @n_Err = 1000211  
                        SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update serialno. Function : isp_TPS_ResetCtnP03' 
                        GOTO RollBackTran   
                     END  
                  END    
               END  

               --delete sku  
               DELETE packDetail WHERE cartonNo = @nCartonNo AND pickslipNo = @cPickSlipNo AND sku = @cSKU  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = 1000205  
                  SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packdetail. Function : isp_TPS_ResetCtnP03' 
                  GOTO RollBackTran  
               END 

            END  
  
            FETCH NEXT FROM curSKU INTO @cSKU  
         END  
         CLOSE curSKU  
         DEALLOCATE curSKU  

      END  
      ELSE  
      -- no SKU to reset: reset all  
      BEGIN  

               
         SELECT @cSKU = SKU  FROM packDetail WITH (NOLOCK) WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

            
         SET @cCurCartonTrack = CURSOR FOR
         SELECT labelno  
         FROM packDetail (nolock)  
         WHERE cartonNo = @nCartonNo
            AND pickslipNo = @cPickSlipNo
            AND storerkey = @cstorerkey  
                 
         OPEN @cCurCartonTrack;  
         FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno   
         WHILE @@FETCH_STATUS = 0  
         BEGIN 
            DELETE cartontrack WHERE trackingno = @cTrackingno

            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 1000206  
               SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete cartontrack. Function : isp_TPS_ResetCtnP03' 
               GOTO RollBackTran  
            END 

            FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno  
         END

         
         IF EXISTS(SELECT 1 FROM packserialno (NOLOCK)    
            WHERE pickslipno=@cpickslipNo    
            AND storerkey=@cStorerKey    
            AND sku=@csku)    
         BEGIN    
            SELECT @cSerialno=serialno  
            FROM packserialno (nolock)  
            WHERE pickslipno=@cpickslipNo    
            AND storerkey=@cStorerKey    
            AND sku=@csku  
  
            DELETE packserialno  
            WHERE pickslipno=@cpickslipNo    
               AND storerkey=@cStorerKey    
               AND sku=@csku  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 1000212  
               SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packserialno. Function : isp_TPS_ResetCtnP03' 
               GOTO RollBackTran 
            END  
  
            IF EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey          
                  AND SKU = @cSKU      
                  AND SerialNo = @cSerialno   
                  AND STATUS IN( '1','6'))    
            BEGIN    
               UPDATE SerialNo WITH (ROWLOCK)  
               SET   STATUS='1',  
                     ORDERKEY='',
                     OrderLineNumber='',
                     ID  = '',
                     EditDate = GETDATE(),  
                     EditWho = @cUserName
               WHERE Storerkey = @cStorerKey  
               AND SKU = @cSKU      
               AND SerialNo = @cSerialno   
               AND STATUS  IN( '1','6'  )
                 
               IF @@ERROR <> 0  
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = 1000213  
                  SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update serialno. Function : isp_TPS_ResetCtnP03' 
                  GOTO RollBackTran 
               END  
            END    
         END  
         
         IF ISNULL(@cOrderkey,'')=''
            SELECT @cOrderkey = orderkey
            FROM Pickheader (nolock)
            Where pickheaderkey = @cPickslipno

         IF EXISTS (SELECT 1
                     FROM serialno (nolock)
                     where Orderkey = @cOrderkey
                        AND OrderLineNumber = ''
                        AND STATUS IN( '1',  '6') 
                        AND storerkey = @cstorerkey  )
         BEGIN
            DECLARE CurSN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT serialno  
            FROM serialno (nolock)  
            WHERE Orderkey = @cOrderkey
               AND STATUS IN( '1',  '6') 
               AND storerkey = @cstorerkey   
  
            OPEN CurSN;  
            FETCH NEXT FROM CurSN INTO @cSerialno  
            WHILE @@FETCH_STATUS = 0  
            BEGIN 
               IF EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)      
                  WHERE StorerKey = @cStorerKey              
                  AND SerialNo = @cSerialno
                  AND ISNULL(ORDERKEY,'')<>''
                  AND STATUS IN( '1','6'))
               BEGIN    
                  UPDATE SerialNo WITH (ROWLOCK)  
                  SET   STATUS='1',  
                        ORDERKEY='',
                        OrderLineNumber = '',
                        ID  = '',
                        EditDate = GETDATE(),  
                        EditWho = @cUserName
                  WHERE storerkey = @cstorerkey    
                     AND SerialNo = @cSerialno   
                     AND STATUS IN( '1',  '6') 
                     AND ISNULL(ORDERKEY,'')<>''
                 
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 1000214  
                     SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update serialno. Function : isp_TPS_ResetCtnP03' 
                     GOTO RollBackTran 
                  END  
               END    
               FETCH NEXT FROM CurSN INTO @cSerialno  
            END
            CLOSE CurSN  
            DEALLOCATE CurSN  

         END


         --delete packDetail  
         DELETE packDetail WHERE cartonNo = @nCartonNo AND pickslipNo = @cPickSlipNo  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = 1000207  
            SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packdetail. Function : isp_TPS_ResetCtnP03' 
            GOTO RollBackTran  
         END 

         SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

         DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
          
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = 1000208  
            SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packinfo. Function : isp_TPS_ResetCtnP03' 
            GOTO RollBackTran  
         END 

         IF ISNULL(@cUCCNo,'') <>''
         BEGIN
            UPDATE UCC
            SET   status='3',
                  EditDate = GETDATE(),  
                  EditWho = @cUserName  
            WHERE UCCNO = @cUCCNo
               AND Status in ('1','2','3','4','6')
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 1000209  
               SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update UCC. Function : isp_TPS_ResetCtnP03' 
               GOTO RollBackTran  
            END  
         END
      END  
   END  
  
   --reset all carton  
   IF @cResetAll = '1'  
   BEGIN  
      IF EXISTS (SELECT 1 FROM packHeader WITH (NOLOCK) WHERE pickslipNo = @cPickSlipNo AND storerKey = @cStorerKey AND STATUS = '9')  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 1000215  
         SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Packed Closed. Function : isp_TPS_ResetCtnP03' 
         GOTO RollBackTran   
      END  
      ELSE  
      BEGIN 
            
         SET @cCurCartonTrack = CURSOR FOR
         SELECT labelno  
         FROM packDetail (nolock)  
         WHERE cartonNo = @nCartonNo
            AND pickslipNo = @cPickSlipNo
            AND storerkey = @cstorerkey  
                 
         OPEN @cCurCartonTrack;  
         FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno   
         WHILE @@FETCH_STATUS = 0  
         BEGIN 
            DELETE cartontrack WHERE trackingno = @cTrackingno

            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 1000216  
               SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete cartontrack. Function : isp_TPS_ResetCtnP03' 
               GOTO RollBackTran  
            END 

            FETCH NEXT FROM @cCurCartonTrack INTO @cTrackingno  
         END
                    
         IF ISNULL(@cOrderkey,'')=''
            SELECT @cOrderkey = orderkey
            FROM Pickheader (nolock)
            Where pickheaderkey = @cPickslipno
  
         SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

         DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = 1000217  
            SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packinfo. Function : isp_TPS_ResetCtnP03' 
            GOTO RollBackTran  
         END  

         UPDATE UCC
         SET   status='3',
               EditDate = GETDATE(),  
               EditWho = @cUserName
         WHERE UCCNO = @cUCCNo
            AND Status in ('1','2','3','4','6')
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = 1000218  
            SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to update UCC. Function : isp_TPS_ResetCtnP03' 
            GOTO RollBackTran   
         END  

         --delete packDetail  
         DELETE packDetail WHERE pickslipNo = @cPickSlipNo  

         IF @@ERROR <> 0  
         BEGIN  
            SET @b_Success = 0  
            SET @n_Err = 1000219  
            SET @c_ErrMsg = api.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete packdetail. Function : isp_TPS_ResetCtnP03' 
            GOTO RollBackTran  
         END  
      END  
   END  
   --COMMIT TRAN isp_ResetCarton  
   SET @b_Success = 1  
   SET @jResult = '[{Success}]'  
   GOTO Quit  


   RollBackTran:  
   --Revert  
   ROLLBACK TRAN isp_TPS_ResetCtnP03  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN isp_TPS_ResetCtnP03  

END

GO