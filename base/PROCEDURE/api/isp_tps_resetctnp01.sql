SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: isp_TPS_ResetCtnP01                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-07-01   1.0  YeeKung  TPS-657 Created                                 */
/******************************************************************************/

CREATE    PROC [API].[isp_TPS_ResetCtnP01] (
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
   @cSQLParam        NVARCHAR(4000)

   --CREATE TABLE #ResetCartonList (  
   DECLARE @ResetCartonList TABLE (  
      SKU   NVARCHAR( 20)  
   )

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN isp_TPS_ResetCtnP01 

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
         --INSERT INTO @errMsg(nErrNo,cErrMsg)  
         SET @b_Success = 0  
         SET @n_Err = @n_Err  
      --   SET @c_ErrMsg = @c_ErrMsg  
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

  
      --Decode pickslipNo Json Format  
      SELECT @cScanNoType = ScanNoType, @cpickslipNo = PickslipNo, @cDropID = DropID,  @cOrderKey=ISNULL(OrderKey,''), @cLoadKey = LoadKey, @cZone = Zone--, @EcomSingle = EcomSingle  
      --, @cDynamicRightName1 = DynamicRightName1, @cDynamicRightValue1 = DynamicRightValue1  
      --,@pickSkuDetailJson = PickSkuDetail  
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
      SELECT @cScanNoType as ScanNoType, @cpickslipNo as PickslipNo, @cDropID as DropID,  @cOrderKey as OrderKey, @cLoadKey as LoadKey, @cZone as Zone--, @EcomSingle as EcomSingle  

  
      SELECT @cPickSlipNo AS pickslipno  
      --SELECT * FROM @ResetCartonList 

 
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
  
          --  IF @nSkuToReset > @nSkuCount  
          --  BEGIN  
          --   SET @b_Success = 0  
          --     SET @n_Err = 100351  
          --     SET @c_ErrMsg = 'Reset error'  
  
          --     GOTO RollBackTran  
          --  END  

  
            DECLARE curSKU CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            select SKU FROM @ResetCartonList  
  
            OPEN curSKU;  
            FETCH NEXT FROM curSKU INTO @cSKU  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
  
               --SELECT @nCartonNo,@cPickSlipNo,@cStorerKey,@cSKU  
               IF EXISTS (SELECT TOP 1 1 FROM packDetail PD WITH (NOLOCK) WHERE PD.cartonNo = @nCartonNo AND PD.pickslipNo = @cPickSlipNo AND StorerKey = @cStorerKey AND SKU = @cSKU)  
               BEGIN  
                 --delete sku  
                  DELETE packDetail WHERE cartonNo = @nCartonNo AND pickslipNo = @cPickSlipNo AND sku = @cSKU  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 175629  
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                     GOTO RollBackTran  
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
                     EditWho = SUSER_NAME(),  
                     TrafficCop = NULL  
                     WHERE cartonNo = @nCartonNo  
                     AND PickSlipNo = @cPickSlipNo  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @b_Success = 0  
                        SET @n_Err = 175630  
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to update PackInfo. Function : isp_ResetCarton'  
  
                        GOTO RollBackTran  
                     END  
  
                  END  
                  --delete packInfo  
                  ELSE IF @nSkuToReset = @nSkuCount  
                  BEGIN  
                     SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

                     DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
                  
                     UPDATE UCC
                     SET status='3'
                     WHERE UCCNO = @cUCCNo
                        AND Status in ('1','2','3','4','6')


  
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @b_Success = 0  
                        SET @n_Err = 175631  
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackInfo. Function : isp_ResetCarton'  
  
                        GOTO RollBackTran  
                     END  
                  END  
               END  
  
               IF EXISTS(SELECT 1 FROM serialno (NOLOCK)    
                           WHERE pickslipno=@cpickslipno    
                              AND cartonNo = @nCartonNo    
                              AND storerkey=@cStorerKey)    
               BEGIN    


                  DECLARE CurSN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
                  SELECT serialno  
                  FROM serialno (nolock)  
                  WHERE pickslipno=@cpickslipno    
                     AND cartonNo = @nCartonNo    
                     AND storerkey=@cStorerKey 
                     AND Status <'6'
  
                  OPEN CurSN;  
                  FETCH NEXT FROM CurSN INTO @cSerialno  
                  WHILE @@FETCH_STATUS = 0  
                  BEGIN 
   
                     UPDATE SerialNo WITH (ROWLOCK)  
                     SET   STATUS='1',  
                           ORDERKEY='',
                           OrderLineNumber='',
                           LabelLine = '',
                           CartonNo = '',
                           pickslipno = ''
                     WHERE Storerkey = @cStorerKey    
                     AND SerialNo = @cSerialno   

                 
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @b_Success = 0  
                        SET @n_Err = 175629  
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                        GOTO RollBackTran  
                     END 
                     FETCH NEXT FROM CurSN INTO @cSerialno  
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

            IF EXISTS (  SELECT 1  
                        FROM serialno (nolock)  
                        WHERE pickslipno=@cpickslipno    
                           AND cartonNo = @nCartonNo    
                           AND storerkey=@cStorerKey 
                           AND Status <'6')
            BEGIN
               DECLARE CurSN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT serialno  
               FROM serialno (nolock)  
               WHERE pickslipno=@cpickslipno    
                  AND cartonNo = @nCartonNo    
                  AND storerkey=@cStorerKey 
                  AND Status <'6'
  
               OPEN CurSN;  
               FETCH NEXT FROM CurSN INTO @cSerialno  
               WHILE @@FETCH_STATUS = 0  
               BEGIN 
   
                  UPDATE SerialNo WITH (ROWLOCK)  
                  SET   STATUS='1',  
                        ORDERKEY='',
                        OrderLineNumber='',
                        LabelLine = '',
                        CartonNo = '',
                        pickslipno = ''
                  WHERE Storerkey = @cStorerKey    
                  AND SerialNo = @cSerialno   

                 
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @b_Success = 0  
                     SET @n_Err = 175629  
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                     GOTO RollBackTran  
                  END  

                  FETCH NEXT FROM CurSN INTO @cSerialno  
               END 
            END
            ELSE
            BEGIN
         
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
                  DECLARE CurSN2 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
                  SELECT serialno  
                  FROM serialno (nolock)  
                  WHERE Orderkey = @cOrderkey
                     AND STATUS IN( '1',  '6') 
                     AND storerkey = @cstorerkey   
  
                  OPEN CurSN2;  
                  FETCH NEXT FROM CurSN2 INTO @cSerialno  
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
                              OrderLineNumber='',
                              LabelLine = '',
                              CartonNo = '',
                              pickslipno = ''
                        WHERE storerkey = @cstorerkey    
                           AND SerialNo = @cSerialno   
                           AND STATUS IN( '1',  '6') 
                           AND ISNULL(ORDERKEY,'')<>''
                 
                        IF @@ERROR <> 0  
                        BEGIN  
                           SET @b_Success = 0  
                           SET @n_Err = 175629  
                           SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                           GOTO RollBackTran  
                        END  
                     END    
                     FETCH NEXT FROM CurSN2 INTO @cSerialno  
                  END
                  CLOSE CurSN  
                  DEALLOCATE CurSN  

               END
            END


            --delete packDetail  
            DELETE packDetail WHERE cartonNo = @nCartonNo AND pickslipNo = @cPickSlipNo  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 175632  
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
               GOTO RollBackTran  
            END  

            SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

            DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
            
            IF ISNULL(@cUCCNo,'') <>''
            BEGIN
               UPDATE UCC
               SET status='3'
               WHERE UCCNO = @cUCCNo
                  AND Status in ('1','2','3','4','6')
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = 175633  
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to update PackInfo. Function : isp_ResetCarton'  
  
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
            SET @n_Err = 175634  
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Packed Pickslip not able to reset. Function : isp_ResetCarton'  
  
            GOTO RollBackTran  
         END  
         ELSE  
         BEGIN  
                    
            DECLARE CurSN CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT serialno  
            FROM serialno (nolock)  
            WHERE pickslipno=@cpickslipno    
               AND storerkey=@cStorerKey 
               AND Status <'6'
  
            OPEN CurSN;  
            FETCH NEXT FROM CurSN INTO @cSerialno  
            WHILE @@FETCH_STATUS = 0  
            BEGIN 
   
               UPDATE SerialNo WITH (ROWLOCK)  
               SET   STATUS='1',  
                     ORDERKEY='',
                     OrderLineNumber='',
                     LabelLine = '',
                     CartonNo = '',
                     pickslipno = ''
               WHERE Storerkey = @cStorerKey    
               AND SerialNo = @cSerialno   

               IF @@ERROR <> 0  
               BEGIN  
                  SET @b_Success = 0  
                  SET @n_Err = 175629  
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                  GOTO RollBackTran  
               END  
               FETCH NEXT FROM CurSN INTO @cSerialno  
            END  

            IF ISNULL(@cOrderkey,'')=''
               SELECT @cOrderkey = orderkey
               FROM Pickheader (nolock)
               Where pickheaderkey = @cPickslipno

            IF EXISTS (SELECT 1
                        FROM serialno (nolock)
                        where Orderkey = @cOrderkey
                        AND STATUS IN( '1',  '6') 
                        AND storerkey = @cstorerkey  )
            BEGIN
               DECLARE CurSN2 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
               SELECT serialno  
               FROM serialno (nolock)  
               WHERE Orderkey = @cOrderkey
                  AND STATUS IN( '1',  '6') 
                  AND storerkey = @cstorerkey   
  
               OPEN CurSN2;  
               FETCH NEXT FROM CurSN2 INTO @cSerialno  
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
                           OrderLineNumber='',
                           LabelLine = '',
                           CartonNo = '',
                           pickslipno = ''
                     WHERE storerkey = @cstorerkey    
                        AND SerialNo = @cSerialno   
                        AND STATUS IN( '1',  '6') 
                        AND ISNULL(ORDERKEY,'')<>''
                 
                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @b_Success = 0  
                        SET @n_Err = 175629  
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
                        GOTO RollBackTran  
                     END  
                  END    
                  FETCH NEXT FROM CurSN2 INTO @cSerialno  
               END
               CLOSE CurSN  
               DEALLOCATE CurSN  

            END


            --delete packDetail  
            DELETE packDetail WHERE pickslipNo = @cPickSlipNo  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 175635  
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to delete PackDetail. Function : isp_ResetCarton'  
  
               GOTO RollBackTran  
            END  
  
            SELECT @cUCCNo =UCCNO FROM PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo  

            DELETE PackInfo WHERE cartonNo = @nCartonNo AND PickSlipNo = @cPickSlipNo 
                  
            UPDATE UCC
            SET status='3'
            WHERE UCCNO = @cUCCNo
               AND Status in ('1','2','3','4','6')
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_Err = 175636  
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Unable to update PackInfo. Function : isp_ResetCarton'  
  
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
      ROLLBACK TRAN isp_TPS_ResetCtnP01  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN isp_TPS_ResetCtnP01  

END


GO