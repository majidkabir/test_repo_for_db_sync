SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdt_1864SwapID02                                            */
/* Copyright      : Maersk                                                      */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev      Author      Purposes                                     */
/* 2024-08-07 1.0      XGU017      UWP-25943 Created                            */
/* 2024-10-22 1.1.0    XGU017      UWP-25943 Updated                            */
/* 2024-11-20 1.2.0    PYU015      UWP-27308 allow to switch pallet             */
/*                                 per same pick slip ID                        */
/********************************************************************************/

CREATE     PROCEDURE [RDT].[rdt_1864SwapID02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 18),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cSuggID       NVARCHAR( 18) OUTPUT,
   @cID           NVARCHAR( 18) OUTPUT,
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL                 NVARCHAR( MAX)
   DECLARE @cSQLParam            NVARCHAR( MAX)      
   DECLARE @nTranCount           INT
   DECLARE @nRowCount            INT
   DECLARE @bSuccess             INT
   DECLARE @cLottableField       NVARCHAR( MAX) = ''
   DECLARE @cLottableCompare     NVARCHAR( MAX) = ''
  
   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cLoadKey             NVARCHAR( 10)
   DECLARE @cZone                NVARCHAR( 18)

   DECLARE @cSuggSKU             NVARCHAR( 20)
   DECLARE @cSuggLOT             NVARCHAR( 10)
   DECLARE @nSuggQTY             INT
   DECLARE @cActSKU              NVARCHAR( 20)
   DECLARE @cActLOT              NVARCHAR( 10)
   DECLARE @nActQTY              INT

   DECLARE @cPickDetailKey       NVARCHAR( 10)
   DECLARE @cNewPickDetailKey    NVARCHAR( 10)
   DECLARE @nQTY_Alloc           INT
   DECLARE @nQTY_Bal             INT
   DECLARE @nQTY_PD              INT
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @curPD                CURSOR
   
   IF OBJECT_ID( 'tempdb..#tSuggPD') IS NOT NULL DROP TABLE #tSuggPD
   CREATE TABLE #tSuggPD 
   (  PickSlipNo     NVARCHAR( 10) NOT NULL,
      PickDetailKey  NVARCHAR( 10) NOT NULL, 
      SKU            NVARCHAR( 20) NOT NULL, 
      QTY            INT           NOT NULL, 
      Lottable01     NVARCHAR( 18) NOT NULL,
      Lottable02     NVARCHAR( 18) NOT NULL,
      Lottable03     NVARCHAR( 18) NOT NULL,
      Lottable04     DATETIME      NULL,
      Lottable05     DATETIME      NULL,
      Lottable06     NVARCHAR( 30) NOT NULL,
      Lottable07     NVARCHAR( 30) NOT NULL,
      Lottable08     NVARCHAR( 30) NOT NULL,
      Lottable09     NVARCHAR( 30) NOT NULL,
      Lottable10     NVARCHAR( 30) NOT NULL,
      Lottable11     NVARCHAR( 30) NOT NULL,
      Lottable12     NVARCHAR( 30) NOT NULL,
      Lottable13     DATETIME      NULL,
      Lottable14     DATETIME      NULL,
      Lottable15     DATETIME      NULL,
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
   
   IF OBJECT_ID( 'tempdb..#tActPD') IS NOT NULL DROP TABLE #tActPD
   CREATE TABLE #tActPD 
   (  
      PickSlipNo     NVARCHAR( 10) NOT NULL,
      PickDetailKey  NVARCHAR( 10) NOT NULL, 
      SKU            NVARCHAR( 20) NOT NULL, 
      QTY            INT           NOT NULL, 
      Lottable01     NVARCHAR( 18) NOT NULL,
      Lottable02     NVARCHAR( 18) NOT NULL,
      Lottable03     NVARCHAR( 18) NOT NULL,
      Lottable04     DATETIME      NULL,
      Lottable05     DATETIME      NULL,
      Lottable06     NVARCHAR( 30) NOT NULL,
      Lottable07     NVARCHAR( 30) NOT NULL,
      Lottable08     NVARCHAR( 30) NOT NULL,
      Lottable09     NVARCHAR( 30) NOT NULL,
      Lottable10     NVARCHAR( 30) NOT NULL,
      Lottable11     NVARCHAR( 30) NOT NULL,
      Lottable12     NVARCHAR( 30) NOT NULL,
      Lottable13     DATETIME      NULL,
      Lottable14     DATETIME      NULL,
      Lottable15     DATETIME      NULL,
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
   
   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   SET @nTranCount = @@TRANCOUNT

   -- Check ID in LOC
   IF NOT EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cLOC
         AND ID = @cID
         AND QTY - QTYPicked > 0)
   BEGIN
      SET @nErrNo = 226701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not in LOC
      GOTO Quit
   END

   -- Check ID not fully available or fully allocated
   IF EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cLOC
         AND ID = @cID
         AND QTY - QTYAllocated - QTYPicked > 0 -- Available
         AND QTYAllocated > 0)                  -- Allocated
   BEGIN
      SET @nErrNo = 226718
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID part alloc
      GOTO Quit
   END

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Get suggest PickDetail
   BEGIN      
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
         INSERT INTO #tSuggPD (PickSlipNo,PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickSlipNo,PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE RKL.PickSlipNo = @cPickSlipNo 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0 
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
         INSERT INTO #tSuggPD (PickSlipNo,PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickSlipNo,PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE PD.OrderKey = @cOrderKey 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
         INSERT INTO #tSuggPD (PickSlipNo,PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickSlipNo,PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE LPD.LoadKey = @cLoadKey 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Custom PickSlip
      ELSE
         INSERT INTO #tSuggPD (PickSlipNo,PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickSlipNo,PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE PD.PickSlipNo = @cPickSlipNo 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
   END

   -- Get actual PickDetail
   INSERT INTO #tActPD (PickSlipNo,PickDetailKey, SKU, QTY, 
      Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
      Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
      Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT PD.PickSlipNo,PD.PickDetailKey, PD.SKU, PD.QTY, 
      LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
   WHERE PD.LOC = @cLOC 
      AND PD.ID = @cID 
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND PD.Status < @cPickConfirmStatus

   DECLARE
      @cChkL01 NVARCHAR(1) = '0', @cChkL02 NVARCHAR(1) = '0', @cChkL03 NVARCHAR(1) = '0', @cChkL04 NVARCHAR(1) = '0', @cChkL05 NVARCHAR(1) = '0', 
      @cChkL06 NVARCHAR(1) = '0', @cChkL07 NVARCHAR(1) = '0', @cChkL08 NVARCHAR(1) = '0', @cChkL09 NVARCHAR(1) = '0', @cChkL10 NVARCHAR(1) = '0', 
      @cChkL11 NVARCHAR(1) = '0', @cChkL12 NVARCHAR(1) = '0', @cChkL13 NVARCHAR(1) = '0', @cChkL14 NVARCHAR(1) = '0', @cChkL15 NVARCHAR(1) = '0'

   -- Get check lottable setting
   SELECT
      @cChkL01 = CASE WHEN Code = 'Lottable01' THEN '1' ELSE @cChkL01 END,
      @cChkL02 = CASE WHEN Code = 'Lottable02' THEN '1' ELSE @cChkL02 END,
      @cChkL03 = CASE WHEN Code = 'Lottable03' THEN '1' ELSE @cChkL03 END,
      @cChkL04 = CASE WHEN Code = 'Lottable04' THEN '1' ELSE @cChkL04 END,
      @cChkL05 = CASE WHEN Code = 'Lottable05' THEN '1' ELSE @cChkL05 END,
      @cChkL06 = CASE WHEN Code = 'Lottable06' THEN '1' ELSE @cChkL06 END,
      @cChkL07 = CASE WHEN Code = 'Lottable07' THEN '1' ELSE @cChkL07 END,
      @cChkL08 = CASE WHEN Code = 'Lottable08' THEN '1' ELSE @cChkL08 END,
      @cChkL09 = CASE WHEN Code = 'Lottable09' THEN '1' ELSE @cChkL09 END,
      @cChkL10 = CASE WHEN Code = 'Lottable10' THEN '1' ELSE @cChkL10 END,
      @cChkL11 = CASE WHEN Code = 'Lottable11' THEN '1' ELSE @cChkL11 END,
      @cChkL12 = CASE WHEN Code = 'Lottable12' THEN '1' ELSE @cChkL12 END,
      @cChkL13 = CASE WHEN Code = 'Lottable13' THEN '1' ELSE @cChkL13 END,
      @cChkL14 = CASE WHEN Code = 'Lottable14' THEN '1' ELSE @cChkL14 END,
      @cChkL15 = CASE WHEN Code = 'Lottable15' THEN '1' ELSE @cChkL15 END
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'SwapID'
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility

   IF '1' IN (@cChkL01, @cChkL02, @cChkL03, @cChkL04, @cChkL05, 
              @cChkL06, @cChkL07, @cChkL08, @cChkL09, @cChkL10, 
              @cChkL11, @cChkL12, @cChkL13, @cChkL14, @cChkL15)
   BEGIN
      IF @cChkL01 = '1' SELECT @cLottableField += ', Lottable01', @cLottableCompare += ' AND S.Lottable01 = A.Lottable01'
      IF @cChkL02 = '1' SELECT @cLottableField += ', Lottable02', @cLottableCompare += ' AND S.Lottable02 = A.Lottable02'
      IF @cChkL03 = '1' SELECT @cLottableField += ', Lottable03', @cLottableCompare += ' AND S.Lottable03 = A.Lottable03'
      IF @cChkL04 = '1' SELECT @cLottableField += ', Lottable04', @cLottableCompare += ' AND S.Lottable04 = A.Lottable04'
      IF @cChkL05 = '1' SELECT @cLottableField += ', Lottable05', @cLottableCompare += ' AND S.Lottable05 = A.Lottable05'
      IF @cChkL06 = '1' SELECT @cLottableField += ', Lottable06', @cLottableCompare += ' AND S.Lottable06 = A.Lottable06'
      IF @cChkL07 = '1' SELECT @cLottableField += ', Lottable07', @cLottableCompare += ' AND S.Lottable07 = A.Lottable07'
      IF @cChkL08 = '1' SELECT @cLottableField += ', Lottable08', @cLottableCompare += ' AND S.Lottable08 = A.Lottable08'
      IF @cChkL09 = '1' SELECT @cLottableField += ', Lottable09', @cLottableCompare += ' AND S.Lottable09 = A.Lottable09'
      IF @cChkL10 = '1' SELECT @cLottableField += ', Lottable10', @cLottableCompare += ' AND S.Lottable10 = A.Lottable10'
      IF @cChkL11 = '1' SELECT @cLottableField += ', Lottable11', @cLottableCompare += ' AND S.Lottable11 = A.Lottable11'
      IF @cChkL12 = '1' SELECT @cLottableField += ', Lottable12', @cLottableCompare += ' AND S.Lottable12 = A.Lottable12'
      IF @cChkL13 = '1' SELECT @cLottableField += ', Lottable13', @cLottableCompare += ' AND S.Lottable13 = A.Lottable13'
      IF @cChkL14 = '1' SELECT @cLottableField += ', Lottable14', @cLottableCompare += ' AND S.Lottable14 = A.Lottable14'
      IF @cChkL15 = '1' SELECT @cLottableField += ', Lottable15', @cLottableCompare += ' AND S.Lottable15 = A.Lottable15'
   END

/*--------------------------------------------------------------------------------------------------
                                                Swap UCC
--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. ID is not alloc           swap
   2. ID on other PickDetail    swap
*/

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1864SwapID02 -- For rollback or commit only our own transaction


   SET @nRowCount = 0
   SELECT @nRowCount = 1
   FROM 
   (
       SELECT PickSlipNo,COUNT(1) ts
         FROM #tSuggPD
        GROUP BY PickSlipNo
    ) S FULL JOIN 
   (
       SELECT PickSlipNo,COUNT(1) ts
         FROM #tActPD
        GROUP BY PickSlipNo
    ) A ON (S.PickSlipNo = A.PickSlipNo)
   WHERE S.PickSlipNo IS NULL
      OR A.PickSlipNo IS NULL

   IF @nRowCount =  1
   BEGIN
       SET @nErrNo = 226721
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUQTYLOT Diff
       GOTO Quit
   END




   COMMIT TRAN rdt_1864SwapID02
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1864SwapID02
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO