SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_838ExtUpd18                                              */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: Extended Upd for Granite - Levis US                                  */
/*                                                                               */
/* Date       Rev  Author      Purposes                                          */
/* 2024-07-05 1.0  Jackc       FCR-392 Created                                   */
/* 2024-08-20 1.1  Jackc       FCR-392 Send IML based on conditions (FBR v1.5)   */
/* 2024-08-22 1.2  Jackc       FCR-392 Not allow to esc on step3 if repack       */
/*                             and update packinfo weight before send IML        */
/*********************************************************************************/

CREATE   PROC rdt.rdt_838ExtUpd18 (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @bDebugFlag             BINARY = 0,
            @nCartonQTY             INT,
            @cNotAllowEscOnSKUQty   NVARCHAR(10)

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 5 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cOption = 1 -- Yes
            BEGIN
               DECLARE @bSuccess             INT
               DECLARE @cTransmitLogKey      NVARCHAR( 10)
               DECLARE @c_QCmdClass          NVARCHAR( 10)   = '' 
               DECLARE @cShipperKey          NVARCHAR( 15)
               DECLARE @nCartonWgt           FLOAT = 0  
               DECLARE @b_Debug              INT = 0
               DECLARE @nTranCount           INT

               SELECT @cShipperKey = ORD.ShipperKey
               FROM ORDERS ORD WITH (NOLOCK) 
               INNER JOIN PICKHEADER PKH WITH (NOLOCK)
                  ON ORD.OrderKey = PKH.OrderKey
               WHERE PKH.PickHeaderKey = @cPickSlipNo

               IF @bDebugFlag = 1
                  SELECT 'ShipperKey', @cShipperKey

               IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
                           WHERE LISTNAME = 'WSCourier'
                              AND Notes = @cShipperKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Generate Transmit Log2', @cPickSlipNo AS PSNO, @cLabelNo AS LabelNo, @nCartonNo AS CartNo

                  --V1.2 Get upd carton weight to packinfo by JCH507
                  SELECT @nCartonWgt = SUM(a.WGT) + MAX(CartonWeight)
                  FROM
                     (SELECT PD.SKU AS SKU, SUM(PD.qty)* MAX(SKU.STDGROSSWGT) AS WGT,  MAX(CAT.CartonWeight) AS CartonWeight
                     FROM PackDetail PD WITH (NOLOCK)
                     INNER JOIN SKU WITH (NOLOCK)
                        ON PD.StorerKey = SKU.StorerKey
                        AND PD.SKU = SKU.Sku
                     INNER JOIN Storer WITH (NOLOCK)
                        ON PD.StorerKey = STORER.StorerKey
                     INNER JOIN PackInfo PI WITH (NOLOCK)
                        ON PD.PickSlipNo = PI.PickSlipNo
                        AND PD.CartonNo = PI.CartonNo
                     INNER JOIN CARTONIZATION CAT WITH (NOLOCK)
                        ON Storer.CartonGroup = CAT.CartonizationGroup AND PI.CartonType = CAT.CartonType
                     WHERE PD.PickSlipNo = @cPickSlipNo
                        AND PD.CartonNo = @nCartonNo
                        AND PD.LabelNo = @cLabelNo
                     GROUP BY PD.PickSlipNo, PD.LabelNo, PD.CartonNo, PD.SKU) a
                  --V1.2 Get upd carton weight to packinfo by JCH507  end

                  SET @nTranCount = @@TRANCOUNT  

                  BEGIN TRAN  
                  SAVE TRAN rdt_838ExtUpd18
                  
                  --V1.2 Get upd carton weight to packinfo by JCH507
                  UPDATE PackInfo SET Weight = @nCartonWgt
                  WHERE PickSlipNo = @cPickSlipNo
                     AND CartonNo = @nCartonNo
                  --V1.2 Get upd carton weight to packinfo by JCH507  end

                  EXECUTE ispGenTransmitLog2 
                  @c_TableName      = 'WSSOECL', 
                  @c_Key1           = @cLabelNo, 
                  @c_Key2           = @cLabelNo, 
                  @c_Key3           = @cStorerkey, 
                  @c_TransmitBatch  = '', 
                  @b_Success        = @bSuccess   OUTPUT,    
                  @n_err            = @nErrNo     OUTPUT,    
                  @c_errmsg         = @cErrMsg    OUTPUT

                  IF @nErrNo <> 0 OR @bSuccess <> 1
                        GOTO RollBackTran

                  SELECT @cTransmitLogKey = transmitlogkey
                  FROM dbo.TRANSMITLOG2 WITH (NOLOCK)
                  WHERE tablename = 'WSSOECL'
                     AND   key1 = @cLabelNo
                     AND   key2 = @cLabelNo
                     AND   key3 = @cStorerkey

                  EXEC dbo.isp_QCmd_WSTransmitLogInsertAlert 
                  @c_QCmdClass         = @c_QCmdClass, 
                  @c_FrmTransmitlogKey = @cTransmitLogKey, 
                  @c_ToTransmitlogKey  = @cTransmitLogKey, 
                  @b_Debug             = @b_Debug, 
                  @b_Success           = @bSuccess    OUTPUT, 
                  @n_Err               = @nErrNo      OUTPUT, 
                  @c_ErrMsg            = @cErrMsg     OUTPUT

                  IF @nErrNo <> 0 OR @bSuccess <> 1
                     GOTO RollbackTran

                  COMMIT TRAN rdt_838ExtUpd18
               END -- send iml end

               GOTO Quit

            END -- option=1
         END -- key=1
      END -- step5
      IF @nStep = 3 -- SKU Qty 
      BEGIN
         IF @nInputKey = 0
         BEGIN
            SET @cNotAllowEscOnSKUQty = rdt.rdtGetConfig( @nFunc, 'NotAllowEscOnSKUQty', @cStorerKey)
            IF @cNotAllowEscOnSKUQty = '0'
               SET @cNotAllowEscOnSKUQty = ''

            IF @nCartonNo > 0 AND @cNotAllowEscOnSKUQty = 1
            BEGIN
               SELECT
                  @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND LabelNo = @cLabelNo

               --Not allow to esc if carton is empty after repack
               IF @nCartonQTY = 0
               BEGIN
                  SET @nErrNo = 221601
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotAllowEscInRepack
                  GOTO Quit
               END 
            END -- cartonNo >0
         END -- key=0
      END--step3
   END -- 838

   GOTO Quit

   RollBackTran:  
         ROLLBACK TRAN rdt_838ExtUpd18  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN 


END--sp

GO