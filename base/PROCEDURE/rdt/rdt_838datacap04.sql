SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DataCap04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 11-02-2022 1.0  Ung         WMS-18900 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_838DataCap04] (
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

   DECLARE @nL02_Count  INT
   DECLARE @nL04_Count  INT
   DECLARE @dLottable04 DATETIME
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cPickStatus NVARCHAR(1)
   DECLARE @cSKUDataCapture NVARCHAR(1)

   DECLARE @tPick TABLE
   (
      Lottable02 NVARCHAR( 18)   NOT NULL, 
      Lottable04 DATETIME        NOT NULL, 
      QTY        INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (Lottable02, Lottable04)
   )
   
   DECLARE @tPack TABLE
   (
      Lottable02 NVARCHAR( 18)   NOT NULL, 
      Lottable04 DATETIME        NOT NULL, 
      QTY        INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (Lottable02, Lottable04)
   )

   DECLARE @tBalance TABLE
   (
      Lottable02 NVARCHAR( 18)   NOT NULL, 
      Lottable04 DATETIME        NOT NULL, 
      QTY        INT             NOT NULL, 
      PRIMARY KEY CLUSTERED (Lottable02, Lottable04)
   )

   SET @cPackData1 = '' -- Batch no, L02
   SET @cPackData2 = '' -- Expiry date, L04
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

   -- Get pick
   INSERT INTO @tPick (Lottable02, Lottable04, QTY)
   SELECT LA.Lottable02, LA.Lottable04, ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
   WHERE PD.OrderKey = @cOrderKey
      AND PD.StorerKey = @cStorerKey
      AND PD.SKU = @cSKU
      AND PD.QTY > 0
      AND PD.Status = @cPickStatus
      AND PD.Status <> '4'
   GROUP BY LA.Lottable02, LA.Lottable04

   -- Get pack
   INSERT INTO @tPack (Lottable02, Lottable04, QTY)
   SELECT 
      UserDefine01, 
      rdt.rdtConvertToDate( UserDefine02), 
      ISNULL( SUM( QTY), 0)
   FROM dbo.PackDetailInfo WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
   GROUP BY UserDefine01, UserDefine02

   -- Get balance
   INSERT INTO @tBalance (Lottable02, Lottable04, QTY)
   SELECT Pick.Lottable02, Pick.Lottable04, Pick.QTY - ISNULL( Pack.QTY, 0)
   FROM @tPick Pick
      LEFT JOIN @tPack Pack ON (Pick.Lottable02 = Pack.Lottable02 AND Pick.Lottable04 = Pack.Lottable04)
   WHERE Pick.QTY - ISNULL( Pack.QTY, 0) > 0
   
   -- Get stat
   SELECT
      @nL02_Count = COUNT( DISTINCT Lottable02),
      @nL04_Count = COUNT( DISTINCT Lottable04)
   FROM @tBalance
   
   -- Auto default L02
   IF @nL02_Count = 1
   BEGIN
      SELECT TOP 1 @cPackData1 = Lottable02 FROM @tBalance
      SET @cPackAttr1 = 'O'
   END
   ELSE IF @nL02_Count > 1
   BEGIN
      SET @cPackData1 = '' -- force key-in
      SET @cPackAttr1 = ''
   END
   
   -- Auto default L04
   IF @nL04_Count = 1
   BEGIN
      SELECT TOP 1 
         @cPackData2 = CONVERT( NVARCHAR(8), Lottable04, 112) -- YYYYMMDD
      FROM @tBalance
      SET @cPackAttr2 = 'O'
   END
   ELSE IF @nL04_Count > 1
   BEGIN
      SET @cPackData2 = '' -- force key-in
      SET @cPackAttr2 = ''
   END

   IF @cPackData1 = '' OR @cPackData2 = ''
   BEGIN
      -- Cursor postion on next blank enable field
      IF @cPackData1 = '' AND @cPackAttr1 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1  
      ELSE IF @cPackData2 = '' AND @cPackAttr2 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- PackData2

      SET @cDataCapture = '1' -- need to capture
   END
   ELSE
      SET @cDataCapture = '0' -- don't need to capture

Quit:

END

GO