SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922ExtUpd05                                     */
/* Purpose: Insert Transmitlog2 when pick = pack for the orders         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-03-23 1.0  James      WMS1377. Created                          */
/* 2017-09-19 1.1  James      WMS-3038 - Change insert transmilog2      */
/*                            tablename based on setup in codelkup      */
/*                            table (james01)                           */
/* 2018-08-09 1.2  James      WMS-5936 Support both conso & discrete    */
/*                            packing (james02)                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_922ExtUpd05] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerKey  NVARCHAR( 15), 
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cLabelNo    NVARCHAR( 20),
   @cPackInfo   NVARCHAR( 3), 
   @cWeight     NVARCHAR( 10),
   @cCube       NVARCHAR( 10),
   @cCartonType NVARCHAR( 10),
   @cDoor       NVARCHAR( 10),
   @cRefNo      NVARCHAR( 40),
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount           INT,
           @nPacked_Qty          INT,
           @nPicked_Qty          INT,
           @bSuccess             INT,
           @nTtlPacked_Qty       INT,
           @nTtlPicked_Qty       INT,
           @nPickPack_NotMatch   INT,
           @nCase_Qty            INT,
           @cPickSlipNo          NVARCHAR( 10),
           @cPackHeaderOrderKey  NVARCHAR( 10),
           @cCaseID              NVARCHAR( 20),
           @cFacility            NVARCHAR( 5),
           @cTableName           NVARCHAR( 30),
           @cConso               NVARCHAR( 1),
           @cTempOrderKey        NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_922ExtUpd05    

   IF @nFunc = 922
   BEGIN
      IF @nStep = 2 -- LabelNo/DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            --SELECT @nTtlPacked_Qty = ISNULL( SUM( Qty), 0)
            --FROM dbo.PackDetail WITH (NOLOCK)
            --WHERE StorerKey = @cStorerKey
            --AND   LabelNo = @cLabelNo

            -- (james02)
            SET @cTempOrderKey = ''
            SELECT TOP 1 @cTempOrderKey = PH.OrderKey
            FROM dbo.PackDetail PD WITH (NOLOCK) 
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.LabelNo = @cLabelNo
            ORDER BY 1 DESC   -- retrieve line with orderkey first
            
            IF ISNULL( @cTempOrderKey, '') = ''
               SET @cConso = '1'
            ELSE
               SET @cConso = '0'

            IF @cConso = '0'
               DECLARE CUR_INSTL2 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT DISTINCT PH.OrderKey
               FROM dbo.PackHeader PH WITH (NOLOCK)
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.LabelNo = @cLabelNo
               ORDER BY 1
            ELSE
               DECLARE CUR_INSTL2 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT DISTINCT PICKD.OrderKey
               FROM dbo.PickDetail PICKD WITH (NOLOCK)
               WHERE PICKD.StorerKey = @cStorerKey
               AND   PICKD.CaseID = @cLabelNo
               AND   [Status] < '9'
               AND   EXISTS ( SELECT 1 
                              FROM dbo.PackHeader PH WITH (NOLOCK)
                              JOIN dbo.PackDetail PD WITH (NOLOCK) 
                                 ON ( PH.PickSlipNo = PD.PickSlipNo)
                              WHERE PD.StorerKey = PICKD.StorerKey
                              AND   PD.LabelNo = PICKD.CaseID)
               ORDER BY 1

            OPEN CUR_INSTL2
            FETCH NEXT FROM CUR_INSTL2 INTO @cTempOrderKey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @nPickPack_NotMatch = 0

               -- If orders is blank in packheader then quit
               IF ISNULL( @cTempOrderKey, '') = ''
               BEGIN
                  SET @nErrNo = 107201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Label No Orders'
                  GOTO RollBackTran
               END                  

               -- If this orders not fully picked then no need further checking
               IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND   OrderKey = @cTempOrderKey
                           AND   [Status] < '3')
                  GOTO RollBackTran

               SELECT @nTtlPicked_Qty = ISNULL( SUM( QTY), 0)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cTempOrderKey
               AND   [Status] IN ('3', '5')

               -- Nike is pick by discrete orders
               SELECT @nTtlPacked_Qty = ISNULL( SUM( PD.Qty), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
               WHERE PD.StorerKey = @cStorerKey
               AND   PH.OrderKey = @cTempOrderKey

               -- If pick & pack not match then no need further checking
               IF @nTtlPicked_Qty <> @nTtlPacked_Qty
                  GOTO RollBackTran

               -- If orders not yet insert into transmitlog3 then check
               IF NOT EXISTS ( SELECT 1 
                               FROM dbo.TransmitLog2 WITH (NOLOCK) 
                               WHERE TableName = 'WSScan2TruckLog'
                               AND   Key1 = @cTempOrderKey
                               AND   Key2 = ''
                               AND   Key3 = @cStorerKey)
               BEGIN
                  DECLARE CHK_ORD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
                  SELECT CaseID, SUM( Qty)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   OrderKey = @cTempOrderKey
                  AND   [Status] IN ('3', '5')
                  GROUP BY CaseID
                  OPEN CHK_ORD
                  FETCH NEXT FROM CHK_ORD INTO @cCaseID, @nCase_Qty
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                                     WHERE StorerKey = @cStorerKey
                                     AND   LabelNo = @cCaseID
                                     GROUP BY LabelNo
                                     HAVING ( SUM( Qty)) = @nCase_Qty)
                     BEGIN
                        SET @nPickPack_NotMatch = 1
                        -- Once not match found, no need further checking
                        CLOSE CHK_ORD
                        DEALLOCATE CHK_ORD
                        GOTO RollBackTran
                     END

                     -- If any one of the label under this orders not yet scan to truck
                     -- then no need further checking
                     IF NOT EXISTS ( SELECT 1 FROM rdt.rdtScanToTruck WITH (NOLOCK)
                                     WHERE MBOLKey = @cMBOLKey
                                     AND   URNNo = @cCaseID)
                     BEGIN
                        SET @nPickPack_NotMatch = 1
                        -- Once not match found, no need further checking
                        CLOSE CHK_ORD
                        DEALLOCATE CHK_ORD
                        GOTO RollBackTran
                     END

                     FETCH NEXT FROM CHK_ORD INTO @cCaseID, @nCase_Qty
                  END
                  CLOSE CHK_ORD
                  DEALLOCATE CHK_ORD

               END

               IF @nPickPack_NotMatch = 0
               BEGIN
                  SELECT @cFacility = Facility
                  FROM dbo.Orders WITH (NOLOCK) 
                  WHERE OrderKey = @cTempOrderKey

                  SELECT @cTableName = Long
                  FROM   dbo.Codelkup WITH (NOLOCK)
                  WHERE ListName = 'RDTINSTL2' 
                  AND   StorerKey = @cStorerKey
                  AND   Code = @cFacility
                  AND   Code2 = @nFunc
                  AND   Short = 'Scan2Truck'

                  -- Insert transmitlog2 here
                  EXEC dbo.ispGenTransmitLog2 
                     @c_TableName      = @cTableName, 
                     @c_Key1           = @cTempOrderKey, 
                     @c_Key2           = '', 
                     @c_Key3           = @cStorerKey, 
                     @c_TransmitBatch  = '', 
                     @b_success        = @bSuccess    OUTPUT, 
                     @n_err            = @nErrNo      OUTPUT, 
                     @c_errmsg         = @cErrMsg     OUTPUT
                        
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 107202
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog2 Fail'
                     GOTO RollBackTran
                  END
               END
               FETCH NEXT FROM CUR_INSTL2 INTO @cTempOrderKey
            END
            CLOSE CUR_INSTL2
            DEALLOCATE CUR_INSTL2
         END
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_922ExtUpd05  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  


GO