SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdt_Pack_LVSUSA_PackConfirm                            */  
/* Copyright      : Maersk                                                 */  
/*                                                                         */
/* Purpose: New PackConfirm logic for LVSUSA                               */
/*                                                                         */  
/* Date       Rev    Author      Purposes                                  */  
/* 2024-10-20 1.0.0  JCH507      FCR-946 Created                           */ 
/* 2025-02-17 1.0.1  JCH507      UWP-30328 Set PackConfirm flag by mistake */   
/***************************************************************************/  
  
CREATE   PROC rdt.rdt_Pack_LVSUSA_PackConfirm (  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT  
   ,@nInputKey       INT  
   ,@cFacility       NVARCHAR( 5)  
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cPickSlipNo     NVARCHAR( 10)  
   ,@cFromDropID     NVARCHAR( 20)  
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@cLabelNo        NVARCHAR( 20)  
   ,@cPrintPackList  NVARCHAR( 1) OUTPUT  
   ,@nErrNo          INT            OUTPUT  
   ,@cErrMsg         NVARCHAR(250)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSQL           NVARCHAR(MAX)  
   DECLARE @cSQLParam      NVARCHAR(MAX)  
   DECLARE @cPackConfirmSP NVARCHAR(20)  
  
   -- Get storer configure  
   SET @cPackConfirmSP = rdt.RDTGetConfig( @nFunc, 'PackConfirmSP', @cStorerKey)  
   IF @cPackConfirmSP = '0'  
      SET @cPackConfirmSP = ''  
  
   /***********************************************************************************************  
                                              Custom pack confirm  
   ***********************************************************************************************/  
   -- Custom logic  
   IF @cPackConfirmSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cPackConfirmSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackConfirmSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cPackDtlDropID, @cLabelNo' +  
            ' @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +   
            ' @nFunc          INT,           ' +   
            ' @cLangCode      NVARCHAR( 3),  ' +   
            ' @nStep          INT,           ' +   
            ' @nInputKey      INT,           ' +   
            ' @cFacility      NVARCHAR( 5),  ' +   
            ' @cStorerKey     NVARCHAR( 15), ' +     
            ' @cPickSlipNo    NVARCHAR( 10), ' +     
            ' @cFromDropID    NVARCHAR( 20), ' +   
            ' @cPackDtlDropID NVARCHAR( 20), ' +
            ' @cLabelNo       NVARCHAR( 20), ' +   
            ' @cPrintPackList NVARCHAR( 1)  OUTPUT, ' +   
            ' @nErrNo         INT           OUTPUT, ' +   
            ' @cErrMsg        NVARCHAR(250) OUTPUT  '  
              
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cPackDtlDropID,   
            @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         GOTO Quit  
      END  
   END  
  
   /***********************************************************************************************  
                                          Standard pack confirm  
   ***********************************************************************************************/  
   DECLARE @bSuccess       INT  
   DECLARE @cLoadKey       NVARCHAR( 10)  
   DECLARE @cOrderKey      NVARCHAR( 10)  
   DECLARE @cZone          NVARCHAR( 18)  
   DECLARE @nPackQTY       INT  
   DECLARE @nPickQTY       INT  
   DECLARE @cPickStatus    NVARCHAR( 20)  
   DECLARE @cPackConfirm   NVARCHAR( 1)
   DECLARE @nCounter       INT = 0
   DECLARE @nMax           INT = 0
   DECLARE @bDebugFlag     BINARY = 0

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
  
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
   SET @cPackConfirm = '' 
   SET @cPickSlipNo = '' 
   SET @nPackQTY = 0  
   SET @nPickQTY = 0

   INSERT INTO @tPSNO (PickSlipNO)
      SELECT DISTINCT PickSlipNO
      FROM PackDetail  WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LabelNo = @cLabelNo
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
   --SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey) --v1.0.1

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

      IF EXISTS ( SELECT TOP 1 1  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            --AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  -- v1.0.1
            AND (PD.Status = '4' OR PD.Status = '0')) --V1.0.1
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
   
Quit:  

END

GO