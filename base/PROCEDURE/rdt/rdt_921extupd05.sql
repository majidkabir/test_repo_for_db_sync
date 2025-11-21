SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_921ExtUpd05                                     */  
/* Purpose: Pack confirm                                                */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2021-11-26 1.0  James      WMS-18433. Created                        */
/* 2022-02-10 1.1  Ung        WMS-18874 Add retrigger interface         */
/************************************************************************/  
CREATE PROC [RDT].[rdt_921ExtUpd05] (  
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cStorerKey     NVARCHAR( 15), 
   @cFacility      NVARCHAR( 5),  
   @cDropID        NVARCHAR( 20), 
   @cLabelNo       NVARCHAR( 20), 
   @cOrderKey      NVARCHAR( 10), 
   @cCartonNo      NVARCHAR( 5),  
   @cPickSlipNo    NVARCHAR( 10), 
   @cCartonType    NVARCHAR( 10), 
   @cCube          NVARCHAR( 20), 
   @cWeight        NVARCHAR( 20), 
   @cLength        NVARCHAR( 20), 
   @cWidth         NVARCHAR( 20), 
   @cHeight        NVARCHAR( 20), 
   @cRefNo         NVARCHAR( 20), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nTranCount  INT
   DECLARE @nCartonNo   INT
   DECLARE @nTempCtnNo  INT = 1
   DECLARE @nTempCtnCnt INT
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cSKUGroup   NVARCHAR( 10)
   DECLARE @cTempCtnType   NVARCHAR( 10)
   DECLARE @fWeight        FLOAT
   DECLARE @fCartonCube    FLOAT
   DECLARE @fCartonWeight  FLOAT
   DECLARE @fTtlWeight     FLOAT
   DECLARE @cCartonGroup   NVARCHAR( 10) = ''
   
   SET @nTranCount = @@TRANCOUNT
   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_921ExtUpd05 -- For rollback or commit only our own transaction

   IF @nFunc = 921 -- Capture PackInfo
   BEGIN  
      IF @nStep = 2 -- Packinfo
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1 
               @cSKU = SKU, 
               @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo 
            AND   CartonNo = @cCartonNo
            ORDER BY 1

            SELECT @cSKUGroup = SKUGROUP
            FROM dbo.SKU WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   Sku = @cSKU
            
            SELECT @cCartonGroup = CL.UDF01 
            FROM dbo.CODELKUP CL WITH (NOLOCK)
            JOIN dbo.CARTONIZATION CZ WITH (NOLOCK) ON ( CL.UDF01 = CZ.CartonizationGroup)
            WHERE CL.LISTNAME = 'SKUGROUP'
            AND   CL.Code = @cSKUGroup  
            AND   CL.Storerkey = @cStorerKey
            AND   CZ.CartonType = @cCartonType
            
            IF ISNULL( @cCartonGroup, '') = ''
            BEGIN
               SET @nErrNo = 179501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Ctn Type
               GOTO RollBackTran
            END
            
            SELECT 
               @fCartonWeight = CartonWeight, 
               @fCartonCube = [Cube]
            FROM dbo.CARTONIZATION WITH (NOLOCK)
            WHERE CartonizationGroup = @cCartonGroup
            AND   CartonType = @cCartonType
               
            SELECT @fWeight = ISNULL( SUM(SKU.STDNETWGT * PD.Qty), 0)
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.Sku)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND   PD.LabelNo = @cLabelNo
               
            SET @fWeight = @fWeight + @fCartonWeight
               
            UPDATE dbo.PackInfo SET 
               WEIGHT = @fWeight, 
               [Cube] = @fCartonCube, 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
               
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 179502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PkInf Fail
               GOTO RollBackTran
            END

            SELECT @fTtlWeight = ISNULL( SUM( [Weight]), 0)
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            
            UPDATE dbo.PackHeader SET 
               CtnTyp1 = CASE WHEN @nCartonNo = 1 THEN @cCartonType ELSE CtnTyp1 END,
               CtnTyp2 = CASE WHEN @nCartonNo = 2 THEN @cCartonType ELSE CtnTyp2 END,
               CtnTyp3 = CASE WHEN @nCartonNo = 3 THEN @cCartonType ELSE CtnTyp3 END,
               CtnTyp4 = CASE WHEN @nCartonNo = 4 THEN @cCartonType ELSE CtnTyp4 END,
               CtnTyp5 = CASE WHEN @nCartonNo = 5 THEN @cCartonType ELSE CtnTyp5 END, 
               TotCtnWeight = @fTtlWeight
            WHERE PickSlipNo = @cPickSlipNo
               
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 179503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PkHdr Fail
               GOTO RollBackTran
            END

            DECLARE @curCtnCnt   CURSOR
            SET @curCtnCnt = CURSOR LOCAL FAST_FORWARD FOR 
            SELECT CartonType, COUNT(1)
            FROM dbo.PackInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            GROUP BY CartonType
            ORDER BY CartonType
            OPEN @curCtnCnt
            FETCH NEXT FROM @curCtnCnt INTO @cTempCtnType, @nTempCtnCnt
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.PackHeader SET
                  CtnCnt1 = CASE WHEN @nTempCtnNo = 1 THEN @nTempCtnCnt ELSE CtnCnt1 END,
                  CtnCnt2 = CASE WHEN @nTempCtnNo = 2 THEN @nTempCtnCnt ELSE CtnCnt2 END,
                  CtnCnt3 = CASE WHEN @nTempCtnNo = 3 THEN @nTempCtnCnt ELSE CtnCnt3 END,
                  CtnCnt4 = CASE WHEN @nTempCtnNo = 4 THEN @nTempCtnCnt ELSE CtnCnt4 END,
                  CtnCnt5 = CASE WHEN @nTempCtnNo = 5 THEN @nTempCtnCnt ELSE CtnCnt5 END
               WHERE PickSlipNo = @cPickSlipNo
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 179504
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PkHdr Fail
                  GOTO RollBackTran
               END
               
               SET @nTempCtnNo = @nTempCtnNo + 1
               IF @nTempCtnNo > 5
                  BREAK

               FETCH NEXT FROM @curCtnCnt INTO @cTempCtnType, @nTempCtnCnt
            END
            
            -- Odd size carton
            IF @cCartonType = '999'
            BEGIN
               -- Record the L,W,H
               UPDATE dbo.PackInfo SET 
                  Length = @cLength, 
                  Width = @cWidth, 
                  Height = @cHeight, 
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 179507
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PkInf Fail
                  GOTO RollBackTran
               END

               -- Get Order
               DECLARE @cStatus NVARCHAR( 10)
               SELECT 
                  @cOrderKey = OrderKey, 
                  @cStatus = Status
               FROM PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo
                  AND StorerKey = @cStorerKey
               
               -- Get order info
               IF EXISTS( SELECT 1 
                  FROM Orders WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey 
                     AND Status >= '5'
                     AND DocType = 'E')
               BEGIN
                  DECLARE @cTransmitLogKey NVARCHAR( 10) = ''
                  DECLARE @cTransmitFlag NVARCHAR( 5) = ''
                  
                  -- Get transmit log info
                  SELECT 
                     @cTransmitLogKey = TransmitLogKey, 
                     @cTransmitFlag = TransmitFlag
                  FROM dbo.TransmitLog2 WITH (NOLOCK)
                  WHERE TableName = 'WSCRPCKGHN'
                     AND Key1 = @cOrderKey
                     AND Key2 = @cStatus
                     AND Key3 = @cStorerKey
                  
                  /*
                     Retrigger scenario:
                        T2 record not found, may be archived. Insert again
                        T2 status = 0, not yet process. Don't insert, it will send out with latest info
                        T2 status > 0, in middle of processing. Insert new one, it will send with latest info
                        T2 status = 9, finish process. Insert new one
                  */
                  IF @cTransmitLogKey = '' OR @cTransmitFlag <> '0'
                  BEGIN
                     /* Cannot use generic SP, as it check duplicate record
                     EXEC dbo.ispGenTransmitLog2 'WSCRPCKGHN', @cOrderKey, '5', @cStorerKey, ''
                        , @bSuccess OUTPUT
                        , @nErrNo   OUTPUT
                        , @cErrMsg  OUTPUT
                     */

                     -- Get key
                     DECLARE @bSuccess INT
                     EXECUTE nspg_getkey  
                         'TransmitlogKey2'
                        ,10  
                        ,@cTransmitlogKey OUTPUT  
                        ,@bSuccess        OUTPUT  
                        ,@nErrNo          -- OUTPUT  
                        ,@cErrMsg         -- OUTPUT  
                     IF @bSuccess <> 1
                     BEGIN
                        SET @nErrNo = 179505
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey fail
                        GOTO RollBackTran
                     END
                     
                     -- Insert log
                     INSERT INTO TransmitLog2( TransmitLogKey, TableName, Key1, Key2, Key3, TransmitFlag, TransmitBatch)  
                     VALUES (@cTransmitlogKey, 'WSRDTUOGHN', @cOrderKey, '5', @cStorerKey, '0', '')
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 179506
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
                        GOTO RollBackTran
                     END
                  END
               END
            END
         END
                        
         COMMIT TRAN rdt_921ExtUpd05
         GOTO Quit
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_921ExtUpd05 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO