SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DataCap05                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 11-02-2022 1.0  Ung         WMS-19000 Created                        */
/* 12-09-2022 1.1  Ung         WMS-20521 Add capture PackData3          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838DataCap05] (
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
   @cPackData1       NVARCHAR( 30)  OUTPUT, 
   @cPackData2       NVARCHAR( 30)  OUTPUT, 
   @cPackData3       NVARCHAR( 30)  OUTPUT,
   @cPackLabel1      NVARCHAR( 20)  OUTPUT,   
   @cPackLabel2      NVARCHAR( 20)  OUTPUT,   
   @cPackLabel3      NVARCHAR( 20)  OUTPUT,  
   @cPackAttr1       NVARCHAR( 1)   OUTPUT,   
   @cPackAttr2       NVARCHAR( 1)   OUTPUT,   
   @cPackAttr3       NVARCHAR( 1)   OUTPUT, 
   @cDataCapture     NVARCHAR( 1)   OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nKeyCount         INT
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cPickStatus       NVARCHAR( 1)
   DECLARE @cSKUDataCapture   NVARCHAR( 1)

   DECLARE @tPick TABLE
   (
      KeyData  NVARCHAR( 18)   NOT NULL, 
      QTY      INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (KeyData)
   )
   
   DECLARE @tPack TABLE
   (
      KeyData  NVARCHAR( 18)   NOT NULL, 
      QTY      INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (KeyData)
   )

   DECLARE @tBalance TABLE
   (
      KeyData  NVARCHAR( 18)   NOT NULL, 
      QTY      INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (KeyData)
   )

   SET @cPackData1 = '' -- Batch no, L02
   SET @cPackData2 = '' -- L01
   SET @cPackData3 = ''

   -- Get SKU info
   SELECT @cSKUDataCapture = DataCapture
   FROM SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Check need data capture
   IF @cSKUDataCapture NOT IN ('1', '3')
      GOTO Quit

   -- Storer config
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerkey)

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo


   /***************************************************************************************************
                                                   PackData1
   ***************************************************************************************************/
   -- Get pick
   INSERT INTO @tPick (KeyData, QTY)
   SELECT LA.Lottable02, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
   WHERE PD.OrderKey = @cOrderKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.QTY > 0
      AND PD.Status = @cPickStatus
      AND PD.Status <> '4'
   GROUP BY LA.Lottable02

   -- Get pack
   INSERT INTO @tPack (KeyData, QTY)
   SELECT UserDefine01, ISNULL( SUM( QTY), 0)
   FROM dbo.PackDetailInfo WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
   GROUP BY UserDefine01

   -- Get balance
   INSERT INTO @tBalance (KeyData, QTY)
   SELECT Pick.KeyData, Pick.QTY - ISNULL( Pack.QTY, 0)
   FROM @tPick Pick
      LEFT JOIN @tPack Pack ON (Pick.KeyData = Pack.KeyData)
   WHERE Pick.QTY - ISNULL( Pack.QTY, 0) > 0
   
   -- Get stat
   SELECT @nKeyCount = COUNT( DISTINCT KeyData)
   FROM @tBalance
   
   -- Auto default / force key-in
   IF @nKeyCount = 1
   BEGIN
      SELECT TOP 1 @cPackData1 = KeyData FROM @tBalance
      SET @cPackAttr1 = 'O'
   END
   ELSE IF @nKeyCount > 1
   BEGIN
      SET @cPackData1 = '' -- force key-in
      SET @cPackAttr1 = ''
   END
   
   
   /***************************************************************************************************
                                                   PackData2
   ***************************************************************************************************/
   IF @cPackData1 <> ''
   BEGIN
      SELECT TOP 1 
         @cPackData2 = LA.Lottable01 -- 1 SKU + Batch, only 1 L01
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.QTY > 0
         AND PD.Status = @cPickStatus
         AND PD.Status <> '4'
         AND LA.Lottable02 = @cPackData1
   END


   /***************************************************************************************************
                                                   PackData3
   ***************************************************************************************************/
   DELETE @tPick
   DELETE @tPack
   DELETE @tBalance
   
   -- Get pick
   INSERT INTO @tPick (KeyData, QTY)
   SELECT OD.ExternLineNo, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
   WHERE PD.OrderKey = @cOrderKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.QTY > 0
      AND PD.Status = @cPickStatus
      AND PD.Status <> '4'
   GROUP BY OD.ExternLineNo

   -- Get pack
   INSERT INTO @tPack (KeyData, QTY)
   SELECT UserDefine03, ISNULL( SUM( QTY), 0)
   FROM dbo.PackDetailInfo WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
   GROUP BY UserDefine03

   -- Get balance
   INSERT INTO @tBalance (KeyData, QTY)
   SELECT Pick.KeyData, Pick.QTY - ISNULL( Pack.QTY, 0)
   FROM @tPick Pick
      LEFT JOIN @tPack Pack ON (Pick.KeyData = Pack.KeyData)
   WHERE Pick.QTY - ISNULL( Pack.QTY, 0) > 0
   
   -- Get stat
   SELECT @nKeyCount = COUNT( DISTINCT KeyData)
   FROM @tBalance
   
   -- Auto default / force key-in
   IF @nKeyCount = 1
   BEGIN
      SELECT TOP 1 @cPackData3 = KeyData FROM @tBalance
      SET @cPackAttr3 = 'O'
   END
   ELSE IF @nKeyCount > 1
   BEGIN
      SET @cPackData3 = '' -- force key-in
      SET @cPackAttr3 = ''
   END
   

   /***************************************************************************************************
                                          Decide capture / not capture
   ***************************************************************************************************/
   IF @cPackData1 = '' OR @cPackData3 = ''
   BEGIN
      IF @cPackData1 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PackData1  
      ELSE IF @cPackData3 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- PackData3 
      
      SET @cDataCapture = '1' -- need to capture
   END
   
Quit:
   
END

GO