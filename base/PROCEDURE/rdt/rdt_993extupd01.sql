SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_993ExtUpd01                                              */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: Extended Upd for Granite - Levis US                                  */
/*                                                                               */
/* Date       Rev  Author      Purposes                                          */
/* 2024-11-01 1.0  JCH507      FCR-946 Created                                   */
/*********************************************************************************/

CREATE   PROC rdt.rdt_993ExtUpd01 (
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

   DECLARE  @bDebugFlag             BINARY = 0

   DECLARE  @nFromScn               INT
   DECLARE  @nFromStep              INT
   DECLARE  @cMasterLabelNo         NVARCHAR(20)

   SELECT @nFromScn = V_FromScn, @nFromStep = V_FromStep, @cMasterLabelNo = V_String3
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 993 -- Pack
   BEGIN
      IF @nStep = 6 -- Print label
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Execute pack confirmation after step 5
            IF @nFromScn = 6494 AND @nFromStep = 5
            BEGIN
               DECLARE @cLoadKey       NVARCHAR( 10)  
               DECLARE @cOrderKey      NVARCHAR( 10)  
               DECLARE @cZone          NVARCHAR( 18)  
               DECLARE @nPackQTY       INT  
               DECLARE @nPickQTY       INT  
               DECLARE @cPickStatus    NVARCHAR( 20)  
               DECLARE @cPackConfirm   NVARCHAR( 1)
               DECLARE @nCounter       INT = 0
               DECLARE @nMax           INT = 0

               DECLARE @tPSNO TABLE
               (
                  RowNumber   INT IDENTITY NOT NULL,
                  PickSlipNo  NVARCHAR(20) NOT NULL
               )

               DECLARE @tOrder TABLE
               (
                  RowNumber   INT IDENTITY NOT NULL,
                  PickSlipNo  NVARCHAR(20) NOT NULL,
                  OrderKey    NVARCHAR(10) NOT NULL
               )
               
               -- When option = 2, LabelNo will be empty, so fetch it from NewLabelNo
               SELECT @cLabelNo = V_String50
               FROM rdt.RDTMOBREC WITH(NOLOCK)
               WHERE Mobile = @nMobile

               SET @cOrderKey = ''  
               SET @cLoadKey = ''  
               SET @cZone = ''  
               SET @cPackConfirm = '' 
               SET @cPickSlipNo = '' 
               SET @nPackQTY = 0  
               SET @nPickQTY = 0
               -- Exclude PSNO in master carton
               INSERT INTO @tPSNO (PickSlipNO)
               SELECT DISTINCT PickSlipNO
               FROM dbo.PackDetail pd  WITH (NOLOCK)
               WHERE pd.StorerKey = @cStorerKey
                  AND pd.LabelNo = @cLabelNo
                  AND NOT EXISTS(
                     SELECT 1 
                     FROM dbo.PackDetail pd2 
                     WHERE pd2.PickSlipNo = pd.PickSlipNo 
                        AND pd2.LabelNo = @cMasterLabelNo
                        AND pd2.StorerKey = @cStorerKey
                  ) 
               ORDER BY PickSlipNo
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 226901  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No PSNO Found
                  GOTO Quit
               END

               IF @bDebugFlag = 1
               BEGIN
                  SELECT 'PSNO List', @cLabelNo AS LabelNo
                  SELECT * FROM @tPSNO
               END
               
               -- Get Order Info
               INSERT INTO @tOrder (PickSlipNo,OrderKey)
                  SELECT DISTINCT PickSlipNo, OrderKey
                  FROM PickHeader PKH WITH (NOLOCK)
                  JOIN @tPSNO PSNO
                  ON PKH.PickHeaderKey = PSNO.PickSlipNo
                  ORDER BY OrderKey
                  
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 226902  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- No Order Found
                  GOTO Quit
               END

               IF @bDebugFlag = 1
               BEGIN
                  SELECT 'Order List'
                  SELECT * FROM @tOrder
               END

               -- Check pack confirm already  
               IF NOT EXISTS( SELECT 1 FROM PackHeader PH WITH (NOLOCK)
                              JOIN @tPSNO PSNO 
                                 ON  PH.PickSlipNo = PSNO.PickSlipNo
                              WHERE Status <> '9')
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'All Confirmed. Quit'  
                  GOTO Quit
               END

               -- Storer config  
               SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey) 

               -- Go through each orderkey in the carton
               SET @nCounter = 1

               SELECT @nMax = COUNT(1)
               FROM @tOrder
               
               WHILE @nCounter <= @nMax
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT @nCounter AS Counter, @nMax AS Max

                  SET @cPickSlipNo = ''
                  SET @cOrderKey = ''
                  SET @cPackConfirm = ''
                  SET @nPackQTY = 0

                  SELECT @cPickSlipNo = PickSlipNo,
                     @cOrderKey = OrderKey
                  FROM @tOrder
                  WHERE RowNumber = @nCounter

                  IF @bDebugFlag = 1
                     SELECT @cPickSlipNo AS PSNO, @cOrderKey AS OrderKey

                  -- Calc pack QTY   
                  SELECT @nPackQTY = ISNULL( SUM( QTY), 0) 
                  FROM PackDetail PD WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo

                  IF EXISTS( SELECT TOP 1 1  
                     FROM dbo.PickDetail PD WITH (NOLOCK)  
                     WHERE PD.OrderKey = @cOrderKey  
                        AND PD.Status < '5'  
                        AND PD.QTY > 0  
                        AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  
                     SET @cPackConfirm = 'N'  
                  ELSE  
                     SET @cPackConfirm = 'Y'

                  IF @bDebugFlag = 1
                     SELECT 'PickDetail Check', @cPackConfirm AS PackConfirm

                  -- Check fully packed  
                  IF @cPackConfirm = 'Y'  
                  BEGIN  
                     SELECT @nPickQTY = SUM( PD.QTY)   
                     FROM dbo.PickDetail PD WITH (NOLOCK)   
                     WHERE PD.OrderKey = @cOrderKey  

                     IF @nPickQTY <> @nPackQTY  
                        SET @cPackConfirm = 'N'  
                  END

                  IF @bDebugFlag = 1
                     SELECT 'Compare Pick&Pack Qty', @cPackConfirm AS PackConfirm, @nPickQty AS PickQty, @nPackQty AS PackQty 

                  -- Close the PackHeader
                  IF @cPackConfirm = 'Y'
                  BEGIN TRY
                     UPDATE PackHeader WITH (ROWLOCK) SET   
                        Status = '9'   
                     WHERE PickSlipNo = @cPickSlipNo  
                        AND Status <> '9'  

                  END TRY
                  BEGIN CATCH
                     SET @nErrNo = @@ERROR
                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = 226903  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail  
                        GOTO Quit  
                     END
                  END CATCH

                  SET @nCounter = @nCounter + 1
               END -- Go through orderky
            END
            IF @cOption = 1 -- Yes
            BEGIN
               DECLARE @bSuccess             INT
               DECLARE @cTransmitLogKey      NVARCHAR( 10)
               DECLARE @c_QCmdClass          NVARCHAR( 10)   = '' 
               DECLARE @cShipperKey          NVARCHAR( 15)
               DECLARE @b_Debug              INT = 0
               DECLARE @nTranCount           INT

               
               IF @bDebugFlag = 1
                     SELECT 'Begining', @cPickSlipNo AS PSNO, @cLabelNo AS LabelNo, @nCartonNo AS CartNo
               
               SELECT TOP 1 @cShipperKey = ORD.ShipperKey
               FROM ORDERS ORD WITH (NOLOCK) 
               INNER JOIN PickDetail PD WITH (NOLOCK)
                  ON ORD.OrderKey = PD.OrderKey
               WHERE PD.Storerkey = @cStorerKey
                  AND PD.CaseID = @cLabelNo

               IF @bDebugFlag = 1
                  SELECT 'ShipperKey', @cShipperKey
               
               SET @nTranCount = @@TRANCOUNT  

               BEGIN TRAN  
               SAVE TRAN rdt_993ExtUpd01

               IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)
                           WHERE LISTNAME = 'WSCourier'
                              AND Notes = @cShipperKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Generate Transmit Log2', @cPickSlipNo AS PSNO, @cLabelNo AS LabelNo, @nCartonNo AS CartNo

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

                  COMMIT TRAN rdt_993ExtUpd01
               END -- send iml end

               GOTO Quit

            END -- option=1
         END -- key=1
      END -- step6
   END -- 993

   GOTO Quit

   RollBackTran:  
         ROLLBACK TRAN rdt_993ExtUpd01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN 


END--sp

GO