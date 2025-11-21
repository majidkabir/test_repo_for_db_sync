SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_GetNextTask             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Setup print job                                             */
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 20-Jun-2008 1.0  UngDH       Created                                 */
/* 18-Sep-2008 1.1  Shong       Performance Tuning                      */
/* 08-Dec-2011 1.2  Ung         SOS230234 Change status from 4 to 3     */
/* 19-Apr-2013 1.3  Ung         SOS276057 Add PickSlipNo6               */
/* 17-Jul-2013 1.4  Ung         SOS283844 Add PickSlipNo7-9             */
/*                              Add DispStyleColorSize                  */
/*                              Sort by Logical, LOC, SKU, L1-4, PSNO   */
/* 28-Jul-2016 1.5  Ung         SOS375224 Add LoadKey, Zone optional    */
/* 05-Jul-2017 1.6  SPChin      IN00380482 - Bug Fixed                  */
/* 27-Aug-2021 1.7  James       Urgent fix. Replace SKU.Descr with      */
/*                              SKU.AltSKU (james01)                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_GetNextTask] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickZone     NVARCHAR( 10),
   @cFromLoc      NVARCHAR( 10),
   @cToLoc        NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cPickSlipType NVARCHAR( 1),
   @cPickSlipNo1  NVARCHAR( 10),
   @cPickSlipNo2  NVARCHAR( 10),
   @cPickSlipNo3  NVARCHAR( 10),
   @cPickSlipNo4  NVARCHAR( 10),
   @cPickSlipNo5  NVARCHAR( 10),
   @cPickSlipNo6  NVARCHAR( 10),
   @cPickSlipNo7  NVARCHAR( 10),
   @cPickSlipNo8  NVARCHAR( 10),
   @cPickSlipNo9  NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10) OUTPUT,
   @cSKU          NCHAR( 20) OUTPUT,	--IN00380482
   @cSKUDescr     NVARCHAR( 60) OUTPUT,
   @cLottable01   NCHAR( 18) OUTPUT,	--IN00380482
   @cLottable02   NCHAR( 18) OUTPUT,	--IN00380482
   @cLottable03   NCHAR( 18) OUTPUT,	--IN00380482
   @dLottable04   DATETIME      OUTPUT,
   @nQTY          INT           OUTPUT, -- QTY to pick, of the task.
   @nBal          INT           OUTPUT, -- QTY to pick in PickSlip, from next location onwards, in the loc range
   @nTotal        INT           OUTPUT, -- QTY of the PickSlip, in the loc range
   @cType         NVARCHAR( 1),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @dZero     DATETIME
   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   DECLARE @nRowCount INT
   DECLARE @cPSField  NVARCHAR( 20)
   
   SET @dZero = 0  -- 1900-01-01
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- Get logical LOC
   DECLARE @cLogicalLOC NVARCHAR(18)
   SET @cLogicalLOC = ''
   SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

   DECLARE @cDynCheckUOM NVARCHAR(1)
   SET @cDynCheckUOM = rdt.RDTGetConfig( @nFunc, 'DynCheckUOM', @cStorerKey)

   -- Performance tuning
   SET @cSQL = 
      ' DECLARE @tPickSlip TABLE (PickSlipNo NVARCHAR(10)) ' + 
      ' IF @cPickSlipNo1 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo1) ' + 
      ' IF @cPickSlipNo2 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo2) ' + 
      ' IF @cPickSlipNo3 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo3) ' + 
      ' IF @cPickSlipNo4 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo4) ' + 
      ' IF @cPickSlipNo5 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo5) ' + 
      ' IF @cPickSlipNo6 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo6) ' + 
      ' IF @cPickSlipNo7 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo7) ' + 
      ' IF @cPickSlipNo8 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo8) ' + 
      ' IF @cPickSlipNo9 <> '''' INSERT INTO @tPickSlip (PickSlipNo) VALUES (@cPickSlipNo9) '

   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
   BEGIN
      SET @cSQL = @cSQL +
         ' SELECT TOP 1 ' + 
         '    @cPickSlipNo = RKL.PickSlipNo, ' + 
         '    @cSKU        = PD.SKU, ' + 
         '    @cLottable01 = LA.Lottable01, ' + 
         '    @cLottable02 = LA.Lottable02, ' + 
         '    @cLottable03 = LA.Lottable03, ' + 
         '    @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120), ' + 
         '    @nQTY        = SUM( PD.QTY) ' + 
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailkey) ' + 
         '    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
         '    JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo) ' + 
         ' WHERE PD.LOC = @cLOC ' + 
         '    AND PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '
      SET @cPSField = 'RKL.PickSlipNo'
   END

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      SET @cSQL = @cSQL +
         ' SELECT TOP 1 ' + 
         '    @cPickSlipNo = PH.PickHeaderKey, ' + 
         '    @cSKU        = PD.SKU, ' + 
         '    @cLottable01 = LA.Lottable01, ' + 
         '    @cLottable02 = LA.Lottable02, ' + 
         '    @cLottable03 = LA.Lottable03, ' + 
         '    @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120), ' + 
         '    @nQTY        = SUM( PD.QTY) ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.LOC = @cLOC ' + 
         '    AND PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '
      SET @cPSField = 'PH.PickHeaderKey'
   END

   ELSE IF @cPickSlipType = 'C'
   BEGIN
      SET @cSQL = @cSQL +
         ' SELECT TOP 1 ' + 
         '    @cPickSlipNo = PH.PickHeaderKey, ' + 
         '    @cSKU        = PD.SKU, ' + 
         '    @cLottable01 = LA.Lottable01, ' + 
         '    @cLottable02 = LA.Lottable02, ' + 
         '    @cLottable03 = LA.Lottable03, ' + 
         '    @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120), ' + 
         '    @nQTY        = SUM( PD.QTY) ' + 
         ' FROM dbo.PickHeader PH WITH (NOLOCK) ' + 
         '    JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey) ' + 
         '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' + 
         '    JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT) ' + 
         '    JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo) ' + 
         ' WHERE PD.LOC = @cLOC ' + 
         '    AND PD.Status < ''3'' ' + 
         '    AND PD.QTY > 0 '
      SET @cPSField = 'PH.PickHeaderKey'
   END
   
   IF @cDynCheckUOM = '1'
      SET @cSQL = @cSQL + ' AND PD.UOM <> ''2'' ' 

   IF @cType = 'L' -- From LOC screen to SKU screen
      SET @cSQL = @cSQL +
         ' GROUP BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo ' + 
         --' ORDER BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '	--IN00380482
         ' ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '								--IN00380482
   
   ELSE IF @cType = 'S' -- Loop within SKU screen
      SET @cSQL = @cSQL +
         --'    AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo > ' + 	--IN00380482
         --'''' +   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo + '''' + 	--IN00380482
         '    AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) > ' + 							--IN00380482
         '''' +   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + '''' + 							--IN00380482
         ' GROUP BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo ' + 
         --' ORDER BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '													--IN00380482
         ' ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '																				--IN00380482

   ELSE IF @cType = 'C' -- From close case
      SET @cSQL = @cSQL +
         --'    AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= ' +	--IN00380482 
         --'''' +   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo + '''' + 	--IN00380482
         '    AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) >= ' +							--IN00380482 
         '''' +   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + '''' + 							--IN00380482
         ' GROUP BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo ' + 
         --' ORDER BY ' + @cPSField + ' ,PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '													--IN00380482
         ' ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo '																				--IN00380482

   SET @cSQL  = @cSQL  + ' SET @nRowCount = @@ROWCOUNT ' 

   SET @cSQLParam = 
      '@cPickSlipNo1    NVARCHAR(10), ' + 
      '@cPickSlipNo2    NVARCHAR(10), ' + 
      '@cPickSlipNo3    NVARCHAR(10), ' + 
      '@cPickSlipNo4    NVARCHAR(10), ' + 
      '@cPickSlipNo5    NVARCHAR(10), ' + 
      '@cPickSlipNo6    NVARCHAR(10), ' + 
      '@cPickSlipNo7    NVARCHAR(10), ' + 
      '@cPickSlipNo8    NVARCHAR(10), ' + 
      '@cPickSlipNo9    NVARCHAR(10), ' + 
      '@cLOC            NVARCHAR(10), ' + 
      '@dZero           DATETIME,     ' + 
      '@cPickSlipNo     NVARCHAR(10) OUTPUT, ' + 
      '@cSKU            NCHAR(20) OUTPUT, ' +	--IN00380482 
      '@cLottable01     NCHAR(18) OUTPUT, ' + 	--IN00380482
      '@cLottable02     NCHAR(18) OUTPUT, ' + 	--IN00380482
      '@cLottable03     NCHAR(18) OUTPUT, ' + 	--IN00380482
      '@dLottable04     DATETIME     OUTPUT, ' + 
      '@nQTY            INT          OUTPUT, ' +
      '@nRowCount       INT          OUTPUT  ' 

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
      @cPickSlipNo1   = @cPickSlipNo1, 
      @cPickSlipNo2   = @cPickSlipNo2, 
      @cPickSlipNo3   = @cPickSlipNo3, 
      @cPickSlipNo4   = @cPickSlipNo4, 
      @cPickSlipNo5   = @cPickSlipNo5, 
      @cPickSlipNo6   = @cPickSlipNo6, 
      @cPickSlipNo7   = @cPickSlipNo7, 
      @cPickSlipNo8   = @cPickSlipNo8, 
      @cPickSlipNo9   = @cPickSlipNo9, 
      @cLOC           = @cLOC, 
      @dZero          = @dZero, 
      @cPickSlipNo    = @cPickSlipNo OUTPUT, 
      @cSKU           = @cSKU        OUTPUT, 
      @cLottable01    = @cLottable01 OUTPUT, 
      @cLottable02    = @cLottable02 OUTPUT, 
      @cLottable03    = @cLottable03 OUTPUT, 
      @dLottable04    = @dLottable04 OUTPUT, 
      @nQTY           = @nQTY        OUTPUT, 
      @nRowCount      = @nRowCount   OUTPUT
      
/*
   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
   BEGIN
      IF @cType = 'L' -- From LOC screen to SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'S' -- Loop within SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'C' -- From close case
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (RKL.PickSlipNo = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END
   END

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      IF @cType = 'L' -- From LOC screen to SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'S' -- Loop within SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'C' -- From close case
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END
   END

   -- Conso PickSlip
   ELSE IF @cPickSlipType = 'C'
   BEGIN
      IF @cType = 'L' -- From LOC screen to SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'S' -- Loop within SKU screen
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), ISNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), ISNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END

      ELSE IF @cType = 'C' -- From close case
      BEGIN
         IF @cDynCheckUOM = '1'
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.UOM <> '2'
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
         ELSE
            SELECT TOP 1
               @cPickSlipNo = PD.PickSlipNo,
               @cSKU        = PD.SKU,
               @cLottable01 = LA.Lottable01,
               @cLottable02 = LA.Lottable02,
               @cLottable03 = LA.Lottable03,
               @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120),
               @nQTY        = SUM( PD.QTY)
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               JOIN @tPickSlip t ON (PH.PickHeaderKey = t.PickSlipNo)
            WHERE PD.LOC = @cLOC
               AND PD.Status < '3'
               AND PD.QTY > 0
               AND PD.SKU + LA.Lottable01 + LA.Lottable02 + LA.Lottable03 + CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120) + PD.PickSlipNo >= --Equal is to get the splitted PickDetail
                   @cSKU  + @cLottable01  + @cLottable02  + @cLottable03  + CONVERT( NVARCHAR( 10), IsNULL(@dLottable04, @dZero), 120) + @cPickSlipNo
            GROUP BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
            ORDER BY PD.SKU, LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, PD.PickSlipNo
      END
   END
*/
   
   -- Check if any task
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 64501
      SET @cErrMsg = rdt.rdtgetmessage( 64501, @cLangCode, 'DSP') --'No more TASK'
      GOTO Quit
   END

   IF @dLottable04 = '1900-01-01 00:00:00.000'
      SET @dLottable04 = NULL

   -- Get SKU description
   DECLARE @cDispStyleColorSize NVARCHAR(1)
   DECLARE @cReplaceSKUDescrWithAltSku NVARCHAR(1)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   SET @cReplaceSKUDescrWithAltSku = rdt.RDTGetConfig( @nFunc, 'ReplaceSKUDescrWithAltSku', @cStorerKey)
   SELECT @cSKUDescr = CASE WHEN @cDispStyleColorSize = '1' THEN Style + Color + Size + Measurement 
                            WHEN @cReplaceSKUDescrWithAltSku = '1' THEN ALTSKU 
                            ELSE Descr END  
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
      AND SKU = @cSKU

   -- Get statistic
   SET @nBal = 0
   EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cPickSlipType
      ,@cPickSlipNo
      ,@cPickZone
      ,@cFromLoc
      ,@cToLoc
      ,'Balance' -- Type
      ,@nBal     OUTPUT
      ,@nErrNo   OUTPUT
      ,@cErrMsg  OUTPUT

   SET @nTotal = 0
   EXEC rdt.rdt_DynamicPick_PickAndPack_GetStat @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cPickSlipType
      ,@cPickSlipNo
      ,@cPickZone
      ,@cFromLoc
      ,@cToLoc
      ,'Total'  -- Type
      ,@nTotal  OUTPUT
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT

Quit:

END

GO