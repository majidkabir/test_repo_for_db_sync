SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PostPickAudit_Lottable_Confirm                  */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-03-2018  1.0  Ung         WMS-4238 Created                        */
/* 23-01-2020  1.1  Ung         INC1017711 Fix SkipChkPSlipMustScanOut  */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PostPickAudit_Lottable_Confirm]
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15), 
   @cMode            NVARCHAR( 10), --CHECK/INSERT/UPDATE
   @cType            NVARCHAR( 10), --SKU/LOTTABLE
   @cRefNo           NVARCHAR( 10), 
   @cPickSlipNo      NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 20),  
   @cOrderKey        NVARCHAR( 10),  
   @cDropID          NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @cDescr           NVARCHAR( 60),  
   @nQTY             INT,
   @cLottableCode    NVARCHAR( 30), 
   @cLottable01      NVARCHAR( 18),  
   @cLottable02      NVARCHAR( 18),  
   @cLottable03      NVARCHAR( 18),  
   @dLottable04      DATETIME,  
   @dLottable05      DATETIME,  
   @cLottable06      NVARCHAR( 30), 
   @cLottable07      NVARCHAR( 30), 
   @cLottable08      NVARCHAR( 30), 
   @cLottable09      NVARCHAR( 30), 
   @cLottable10      NVARCHAR( 30), 
   @cLottable11      NVARCHAR( 30),
   @cLottable12      NVARCHAR( 30),
   @dLottable13      DATETIME,
   @dLottable14      DATETIME,
   @dLottable15      DATETIME,
   @nRowRef          INT           OUTPUT, 
   @nPPA_QTY         INT           OUTPUT, 
   @nCHK_QTY         INT           OUTPUT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)
   
   -- Get RDT storer configure
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
   
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) + 
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, ' + 
            ' @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode,  ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
            ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
            ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
            ' @nRowRef OUTPUT, @nPPA_QTY OUTPUT, @nCHK_QTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam = 
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' + 
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cType         NVARCHAR( 10), ' + 
            '@cRefNo        NVARCHAR( 10), ' + 
            '@cPickSlipNo   NVARCHAR( 10), ' + 
            '@cLoadKey      NVARCHAR( 20), ' +  
            '@cOrderKey     NVARCHAR( 10), ' +  
            '@cDropID       NVARCHAR( 20), ' +  
            '@cSKU          NVARCHAR( 20), ' +  
            '@cDescr        NVARCHAR( 60), ' + 
            '@nQTY          INT,           ' + 
            '@cLottableCode NVARCHAR( 30), ' + 
            '@cLottable01   NVARCHAR( 18), ' +
            '@cLottable02   NVARCHAR( 18), ' +
            '@cLottable03   NVARCHAR( 18), ' +
            '@dLottable04   DATETIME,      ' +
            '@dLottable05   DATETIME,      ' +
            '@cLottable06   NVARCHAR( 30), ' +
            '@cLottable07   NVARCHAR( 30), ' +
            '@cLottable08   NVARCHAR( 30), ' +
            '@cLottable09   NVARCHAR( 30), ' +
            '@cLottable10   NVARCHAR( 30), ' +
            '@cLottable11   NVARCHAR( 30), ' +
            '@cLottable12   NVARCHAR( 30), ' +
            '@dLottable13   DATETIME,      ' +
            '@dLottable14   DATETIME,      ' +
            '@dLottable15   DATETIME,      ' +
            '@nRowRef       INT           OUTPUT, ' +
            '@nPPA_QTY      INT           OUTPUT, ' +
            '@nCHK_QTY      INT           OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '
         
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cType, 
            @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @cDescr, @nQTY, @cLottableCode, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
            @nRowRef  OUTPUT, 
            @nPPA_QTY OUTPUT, 
            @nCHK_QTY OUTPUT, 
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cWhere NVARCHAR( MAX)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cSkipChkPSlipMustScanOut NVARCHAR( 1)
   
   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus NOT IN ('3', '5')
      SET @cPickConfirmStatus = '5'
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorerKey)
   IF @cSkipChkPSlipMustScanOut = '1'
      SET @cPickConfirmStatus = '0'

   SET @nRowRef = 0
   SET @nPPA_QTY = 0
   SET @nCHK_QTY = 0
   SET @cWhere = ''

   -- Get lottable filter
   IF @cType = 'LOTTABLE'
      EXEC rdt.rdt_Lottable_GetCurrentSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLottableCode, 15, 'LA', 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
         @cWhere   OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

   -- Get PPA
   SET @cSQL = 
      ' SELECT TOP 1 ' + 
         ' @nRowRef = RowRef, ' +
         ' @nPPA_QTY = PQTY, ' +
         ' @nCHK_QTY = CQTY  ' +
      ' FROM rdt.rdtPPA LA WITH (NOLOCK) ' + 
      ' WHERE ' + 
         CASE 
            WHEN @cRefNo      <> '' THEN ' RefNo = @cRefNo ' 
            WHEN @cPickSlipNo <> '' THEN ' PickSlipNo = @cPickSlipNo ' 
            WHEN @cLoadKey    <> '' THEN ' LoadKey = @cLoadKey ' 
            WHEN @cOrderKey   <> '' THEN ' OrderKey = @cOrderKey ' 
            WHEN @cDropID     <> '' THEN ' DropID = @cDropID ' 
            ELSE '' 
         END + 
         ' AND StorerKey = @cStorerKey ' + 
         ' AND SKU = @cSKU ' + 
         CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
   
   SET @cSQLParam = 
      ' @cRefNo             NVARCHAR( 10), ' + 
      ' @cPickSlipNo        NVARCHAR( 10), ' + 
      ' @cLoadKey           NVARCHAR( 10), ' +  
      ' @cOrderKey          NVARCHAR( 10), ' +  
      ' @cDropID            NVARCHAR( 20), ' +  
      ' @cStorerKey         NVARCHAR( 15), ' +  
      ' @cSKU               NVARCHAR( 20), ' +  
      ' @cPickConfirmStatus NVARCHAR( 1),  ' +
      ' @cLottable01        NVARCHAR( 18), ' + 
      ' @cLottable02        NVARCHAR( 18), ' + 
      ' @cLottable03        NVARCHAR( 18), ' + 
      ' @dLottable04        DATETIME,      ' + 
      ' @dLottable05        DATETIME,      ' + 
      ' @cLottable06        NVARCHAR( 30), ' + 
      ' @cLottable07        NVARCHAR( 30), ' + 
      ' @cLottable08        NVARCHAR( 30), ' + 
      ' @cLottable09        NVARCHAR( 30), ' + 
      ' @cLottable10        NVARCHAR( 30), ' + 
      ' @cLottable11        NVARCHAR( 30), ' + 
      ' @cLottable12        NVARCHAR( 30), ' + 
      ' @dLottable13        DATETIME,      ' + 
      ' @dLottable14        DATETIME,      ' + 
      ' @dLottable15        DATETIME,      ' + 
      ' @nRowRef            INT OUTPUT,    ' + 
      ' @nPPA_QTY           INT OUTPUT,    ' + 
      ' @nCHK_QTY           INT OUTPUT     '  

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cPickConfirmStatus, 
      @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
      @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
      @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
      @nRowRef OUTPUT, @nPPA_QTY OUTPUT, @nCHK_QTY OUTPUT

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 122001
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GET PPA Fail
      GOTO Quit
   END
   
   -- Insert PPA
   IF @nRowRef = 0
   BEGIN
      -- RefNo
      IF @cRefNo <> ''
      BEGIN
         -- Get PQTY
         SET @cSQL = 
            ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' + 
               ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE LPD.UserDefine10 = @cRefNo ' + 
               ' AND PD.StorerKey = @cStorerKey ' + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.Status <> ''4''  ' + 
               ' AND PD.Status >= @cPickConfirmStatus ' + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
      END

      -- PickSlipNo
      IF @cPickSlipNo <> ''
      BEGIN
         -- Get pickheader info
         DECLARE @cZone NVARCHAR( 10)
         DECLARE @cPH_OrderKey NVARCHAR( 10)
         DECLARE @cExternOrderKey NVARCHAR( 20)
         SELECT TOP 1
            @cExternOrderKey = ExternOrderkey,
            @cPH_OrderKey = OrderKey,
            @cZone = Zone
         FROM dbo.PickHeader WITH (NOLOCK)
         WHERE PickHeaderKey = @cPickSlipNo
         
         -- Cross dock
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
            SET @cSQL = 
               ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' + 
                  ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) ' + 
                  ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
                  ' AND PD.StorerKey = @cStorerKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status <> ''4''  ' + 
                  ' AND PD.Status >= @cPickConfirmStatus ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
         
         -- Discrete
         ELSE IF @cPH_OrderKey <> ''
            SET @cSQL = 
               ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                  ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE OrderKey = ''' + @cPH_OrderKey + '''' + 
                  ' AND PD.StorerKey = @cStorerKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status <> ''4''  ' + 
                  ' AND PD.Status >= @cPickConfirmStatus ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
         
         -- Conso
         ELSE
            SET @cSQL = 
               ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
                  ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' + 
                  ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE LPD.LoadKey = ''' + @cExternOrderKey + '''' + 
                  ' AND PD.StorerKey = @cStorerKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status <> ''4''  ' + 
                  ' AND PD.Status >= @cPickConfirmStatus ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
      END

      -- LoadKey
      IF @cLoadKey <> ''
      BEGIN
         SET @cSQL = 
            ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' + 
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' + 
               ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE LPD.LoadKey = @cLoadKey ' + 
               ' AND PD.StorerKey = @cStorerKey ' + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.Status <> ''4''  ' + 
               ' AND PD.Status >= @cPickConfirmStatus ' + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
      END

      -- OrderKey
      IF @cOrderKey <> ''
      BEGIN
         SET @cSQL = 
            ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
               ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
            ' WHERE OrderKey = @cOrderKey ' + 
               ' AND PD.StorerKey = @cStorerKey ' + 
               ' AND PD.SKU = @cSKU ' + 
               ' AND PD.Status <> ''4''  ' + 
               ' AND PD.Status >= @cPickConfirmStatus ' + 
               CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
      END

      -- DropID
      IF @cDropID <> ''
      BEGIN
         -- Get storer configure
         DECLARE @cPPACartonIDByPickDetailCaseID NVARCHAR(1)
         SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorerKey)
         
         IF @cPPACartonIDByPickDetailCaseID = '1'
            SET @cSQL = 
               ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                  ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE PD.CaseID = @cDropID ' + 
                  ' AND PD.StorerKey = @cStorerKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status <> ''4''  ' + 
                  ' AND PD.Status >= @cPickConfirmStatus ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
         ELSE
            SET @cSQL = 
               ' SELECT @nPPA_QTY = ISNULL( SUM( PD.QTY), 0) ' + 
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' + 
                  ' JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' + 
               ' WHERE PD.DropID = @cDropID ' + 
                  ' AND PD.StorerKey = @cStorerKey ' + 
                  ' AND PD.SKU = @cSKU ' + 
                  ' AND PD.Status <> ''4''  ' + 
                  ' AND PD.Status >= @cPickConfirmStatus ' + 
                  CASE WHEN @cWhere = '' THEN '' ELSE ' AND ' + @cWhere END
      END

      -- Get PQTY
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cStorerKey, @cSKU, @cPickConfirmStatus, 
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, 
         @nRowRef OUTPUT, @nPPA_QTY OUTPUT, @nCHK_QTY OUTPUT

      IF @cMode = 'INSERT'
      BEGIN
         -- Insert PPA
         INSERT INTO rdt.rdtPPA WITH (ROWLOCK) 
            (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         VALUES 
            (@cRefNo, @cPickSlipNo, @cLoadKey, '', @cStorerKey, @cSKU, @cDescr, @nPPA_QTY, @nQTY, '0', SUSER_SNAME(), GETDATE(), 1, 1, @cOrderKey, @cDropID, 
            @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
            @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
            @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 122002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PPA Fail
            GOTO Quit
         END
      END
   END
   
   -- Update PPA
   ELSE
   BEGIN
      IF @cMode = 'UPDATE'
      BEGIN
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nQTY,
            NoOfCheck = NoOfCheck + 1
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 122003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PPA Fail
            GOTO Quit
         END
      END
   END

Quit:

END

GO