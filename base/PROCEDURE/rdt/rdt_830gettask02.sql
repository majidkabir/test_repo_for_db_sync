SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_830GetTask02                                             */
/* Copyright      : LFLogistics                                                  */
/*                                                                               */
/* Purpose: Suggest pick LOC                                                     */
/*                                                                               */
/* Date        Rev  Author      Purposes                                         */
/* 2020-08-24  1.0  YeeKung     WMS14706 - Created                               */
/* 2020-12-18  1.1  YeeKung     WMS-15995 Add PickZone (yeekung01)               */
/*********************************************************************************/

CREATE PROCEDURE [RDT].[rdt_830GetTask02]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cPickZone     NVARCHAR( 10), --(yeekung01)
   @cLOC          NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cSKU          NVARCHAR( 20) OUTPUT,   
   @nTaskQTY      INT           OUTPUT,  
   @cLottable01   NVARCHAR( 18) OUTPUT,   
   @cLottable02   NVARCHAR( 18) OUTPUT,   
   @cLottable03   NVARCHAR( 18) OUTPUT,   
   @dLottable04   DATETIME      OUTPUT,   
   @dLottable05   DATETIME      OUTPUT,   
   @cLottable06   NVARCHAR( 30) OUTPUT,  
   @cLottable07   NVARCHAR( 30) OUTPUT,  
   @cLottable08   NVARCHAR( 30) OUTPUT,  
   @cLottable09   NVARCHAR( 30) OUTPUT,  
   @cLottable10   NVARCHAR( 30) OUTPUT,  
   @cLottable11   NVARCHAR( 30) OUTPUT,  
   @cLottable12   NVARCHAR( 30) OUTPUT,  
   @dLottable13   DATETIME      OUTPUT,  
   @dLottable14   DATETIME      OUTPUT,  
   @dLottable15   DATETIME      OUTPUT,  
   @cLottableCode NVARCHAR( 30) OUTPUT,  
   @cSKUDescr     NVARCHAR( 60) OUTPUT,  
   @cMUOM_Desc    NVARCHAR( 5)  OUTPUT,  
   @cPUOM_Desc    NVARCHAR( 5)  OUTPUT,  
   @nPUOM_Div     INT           OUTPUT,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT,  
   @cPPK          NVARCHAR( 5)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cGetNextSKU NVARCHAR( 1)
   DECLARE @cVerifyID   NVARCHAR( 1)
   DECLARE @cPUOM       NVARCHAR( 5)
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)

   DECLARE @cTempSKU        NCHAR( 20)
   DECLARE @nTempQTY        INT
   DECLARE @cTempLottable01 NVARCHAR( 18) 
   DECLARE @cTempLottable02 NVARCHAR( 18) 
   DECLARE @cTempLottable03 NVARCHAR( 18) 
   DECLARE @dTempLottable04 DATETIME
   DECLARE @dTempLottable05 DATETIME
   DECLARE @cTempLottable06 NVARCHAR( 30)
   DECLARE @cTempLottable07 NVARCHAR( 30)
   DECLARE @cTempLottable08 NVARCHAR( 30)
   DECLARE @cTempLottable09 NVARCHAR( 30)
   DECLARE @cTempLottable10 NVARCHAR( 30)
   DECLARE @cTempLottable11 NVARCHAR( 30)
   DECLARE @cTempLottable12 NVARCHAR( 30)
   DECLARE @dTempLottable13 DATETIME
   DECLARE @dTempLottable14 DATETIME
   DECLARE @dTempLottable15 DATETIME
   DECLARE @cTempLottableCode NVARCHAR( 30)
   DECLARE @nLottableOnPage  INT

   SET @nLottableOnPage=1
   
   -- Assign to temp
   SET @cTempSKU = @cSKU
   SET @nTempQTY = 0
   SET @cTempLottable01 = @cLottable01
   SET @cTempLottable02 = @cLottable02
   SET @cTempLottable03 = @cLottable03
   SET @dTempLottable04 = @dLottable04
   SET @dTempLottable05 = @dLottable05
   SET @cTempLottable06 = @cLottable06
   SET @cTempLottable07 = @cLottable07
   SET @cTempLottable08 = @cLottable08
   SET @cTempLottable09 = @cLottable09
   SET @cTempLottable10 = @cLottable10
   SET @cTempLottable11 = @cLottable11
   SET @cTempLottable12 = @cLottable12
   SET @dTempLottable13 = @dLottable13
   SET @dTempLottable14 = @dLottable14
   SET @dTempLottable15 = @dLottable15
   SET @cTempLottableCode = @cLottableCode 

   IF @cTempSKU = ''
      SET @cGetNextSKU = 'Y' 
   ELSE 
      SET @cGetNextSKU = 'N' 

   IF @nStep = 6       
      SET @cGetNextSKU = 'Y' 

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   SET @cVerifyID = rdt.RDTGetConfig( @nFunc, 'VerifyID', @cStorerKey)

   -- Get PickHeader info
   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   WHILE (1=1)  
   BEGIN  
      /******************************************** Get SKU *****************************************/  
      IF @cGetNextSKU = 'Y'  
      BEGIN  
         -- Cross dock PickSlip  
         IF @cZone IN ('XD', 'LB', 'LP') 
            IF @cPickzone<>'' 
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE RKL.PickSlipNo = @cPickSlipNo  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus  
                  AND   LOC.PickZone=@cPickZone
               ORDER BY PD.SKU  
            ELSE
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE RKL.PickSlipNo = @cPickSlipNo  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus  
               ORDER BY PD.SKU  
        
         -- Discrete PickSlip  
         ELSE IF @cOrderKey <> ''
            IF @cPickZone<>''  
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE PD.OrderKey = @cOrderKey  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus  
                  AND PD.UOM<>1
                  AND   LOC.PickZone=@cPickZone
               ORDER BY PD.SKU  
            ELSE
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE PD.OrderKey = @cOrderKey  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus  
                  AND PD.UOM<>1
               ORDER BY PD.SKU  
               
         -- Conso PickSlip  
         ELSE IF @cLoadKey <> ''  
            IF @cPickZone<>''
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE LPD.LoadKey = @cLoadKey    
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.UOM<>1  
                  AND   LOC.PickZone=@cPickZone
               ORDER BY PD.SKU  
            ELSE
                SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE LPD.LoadKey = @cLoadKey    
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.UOM<>1  
               ORDER BY PD.SKU  
         -- Custom PickSlip  
         ELSE  
            IF @cPickZone<>''
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE PD.PickSlipNo = @cPickSlipNo  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.UOM<>1  
                  AND   LOC.PickZone=@cPickZone
               ORDER BY PD.SKU  
            ELSE
               SELECT TOP 1  
                  @cTempSKU = PD.SKU  
               FROM dbo.PickDetail PD WITH (NOLOCK)  
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
               WHERE PD.PickSlipNo = @cPickSlipNo  
                  AND LOC.LOC = @cLOC  
                  AND ((@cVerifyID = '1' AND PD.ID = @cID) OR @cVerifyID = '0')  
                  AND PD.SKU > @cTempSKU  
                  AND PD.QTY > 0  
                  AND PD.Status <> '4'  
                  AND PD.Status < @cPickConfirmStatus
                  AND PD.UOM<>1  
               ORDER BY PD.SKU 
           
         IF @@ROWCOUNT = 0  
         BEGIN  
            SET @nErrNo = 157551  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task  
            SET @nErrNo = -1 -- No more task  
            GOTO Quit  
         END  
        
         -- Get SKU info  
         SELECT   
            @cTempLottableCode = LottableCode  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND SKU = @cTempSKU  
  
         SET @cGetNextSKU = 'N'  
      END  
        
      /************************************** Get QTY and lottables *********************************/  
      DECLARE @cSelect  NVARCHAR( MAX)  
      DECLARE @cFrom    NVARCHAR( MAX)  
      DECLARE @cWhere1  NVARCHAR( MAX)  
      DECLARE @cWhere2  NVARCHAR( MAX)  
      DECLARE @cGroupBy NVARCHAR( MAX)  
      DECLARE @cOrderBy NVARCHAR( MAX)  
        
      SET @nTempQTY = 0  
        
      -- Get lottable filter  
      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',   
         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,  
         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
         @cSelect  OUTPUT,  
         @cWhere1  OUTPUT,  
         @cWhere2  OUTPUT,  
         @cGroupBy OUTPUT,  
         @cOrderBy OUTPUT,  
         @nErrNo   OUTPUT,  
         @cErrMsg  OUTPUT  
           
      -- Cross dock PickSlip  
      IF @cZone IN ('XD', 'LB', 'LP')  
         SET @cSQL =   
            ' SELECT TOP 1 ' +   
               ' @nQTY = ISNULL( SUM( PD.QTY), 0) ' +   
               CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +   
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK)' +   
               ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)' +   
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)' +   
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +   
               ' AND LOC.LOC = @cLOC ' +   
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END +   
               ' AND PD.SKU = @cSKU ' +   
               ' AND PD.QTY > 0' +   
               ' AND PD.Status <> ''4''' +   
               ' AND PD.Status < @cStatus ' +  
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone=@cPickZone ' ELSE '' END +  --(yeekung01)  
               CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +   
               CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +  
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +  
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END   
     
      -- Discrete PickSlip  
      ELSE IF @cOrderKey <> ''  
         SET @cSQL =   
            ' SELECT TOP 1 ' +   
               ' @nQTY = ISNULL( SUM( PD.QTY), 0) ' +   
               CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +   
            ' FROM dbo.PickDetail PD WITH (NOLOCK)' +   
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)' +   
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE PD.OrderKey = @cOrderKey ' +   
            ' AND LOC.LOC = @cLOC ' +   
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END +   
               ' AND PD.SKU = @cSKU ' +   
               ' AND PD.QTY > 0' +   
               ' AND PD.Status <> ''4''' +   
               ' AND PD.Status < @cStatus ' + 
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone=@cPickZone ' ELSE '' END +  --(yeekung01)   
               CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +   
               CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +   
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +  
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END   
                    
      -- Conso PickSlip  
      ELSE IF @cLoadKey <> ''  
         SET @cSQL =   
            ' SELECT TOP 1 ' +   
               ' @nQTY = ISNULL( SUM( PD.QTY), 0) ' +   
               CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +   
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +   
               ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +   
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +   
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE LPD.LoadKey = @cLoadKey ' +   
               ' AND LOC.LOC = @cLOC ' +   
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END +   
               ' AND PD.SKU = @cSKU ' +   
               ' AND PD.QTY > 0' +   
               ' AND PD.Status <> ''4''' +   
               ' AND PD.Status < @cStatus ' +   
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone=@cPickZone ' ELSE '' END +  --(yeekung01) 
               CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +   
               CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +   
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +  
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END   
        
      -- Custom PickSlip  
      ELSE  
         SET @cSQL =   
            ' SELECT TOP 1 ' +   
               ' @nQTY = ISNULL( SUM( PD.QTY), 0) ' +   
               CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +   
            ' FROM dbo.PickDetail PD WITH (NOLOCK)' +   
               ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)' +   
               ' JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +   
            ' WHERE PD.PickSlipNo = @cPickSlipNo ' +   
               ' AND LOC.LOC = @cLOC ' +   
               CASE WHEN @cVerifyID = '1' THEN ' AND PD.ID = @cID ' ELSE '' END +   
               ' AND PD.SKU = @cSKU ' +   
               ' AND PD.QTY > 0' +   
               ' AND PD.Status <> ''4''' +   
               ' AND PD.Status < @cStatus ' +  
               CASE WHEN @cPickZone <>'' THEN ' AND LOC.PickZone=@cPickZone ' ELSE '' END +  --(yeekung01)  
               CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +   
               CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +   
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +  
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END   
  
      SET @cSQLParam =   
         '@cPickSlipNo NVARCHAR( 10) , ' +    
         '@cOrderKey   NVARCHAR( 10) , ' +    
         '@cLoadKey    NVARCHAR( 10) , ' +
         '@cPickZone   NVARCHAR( 10) , ' +    
         '@cLOC        NVARCHAR( 10) , ' +    
         '@cID         NVARCHAR( 18) , ' +    
         '@cSKU        NVARCHAR( 20) , ' +    
         '@cStatus     NVARCHAR( 1)  , ' +   
         '@nQTY        INT           OUTPUT, ' +   
         '@cLottable01 NVARCHAR( 18) OUTPUT, ' +    
         '@cLottable02 NVARCHAR( 18) OUTPUT, ' +    
         '@cLottable03 NVARCHAR( 18) OUTPUT, ' +    
         '@dLottable04 DATETIME      OUTPUT, ' +    
         '@dLottable05 DATETIME      OUTPUT, ' +    
         '@cLottable06 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable07 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable08 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable09 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable10 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable11 NVARCHAR( 30) OUTPUT, ' +   
         '@cLottable12 NVARCHAR( 30) OUTPUT, ' +   
         '@dLottable13 DATETIME      OUTPUT, ' +   
         '@dLottable14 DATETIME      OUTPUT, ' +   
         '@dLottable15 DATETIME      OUTPUT  '  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,   
         @cPickSlipNo = @cPickSlipNo,    
         @cOrderKey   = @cOrderKey,    
         @cLoadKey    = @cLoadKey,    
         @cLOC        = @cLOC,    
         @cID         = @cID,    
         @cSKU        = @cTempSKU,    
         @cStatus     = @cPickConfirmStatus,  
         @cPickZone   = @cPickZone, --(yeekung01)    
         @nQTY        = @nTempQTY        OUTPUT,    
         @cLottable01 = @cTempLottable01 OUTPUT,     
         @cLottable02 = @cTempLottable02 OUTPUT,     
         @cLottable03 = @cTempLottable03 OUTPUT,     
         @dLottable04 = @dTempLottable04 OUTPUT,     
         @dLottable05 = @dTempLottable05 OUTPUT,     
         @cLottable06 = @cTempLottable06 OUTPUT,    
         @cLottable07 = @cTempLottable07 OUTPUT,    
         @cLottable08 = @cTempLottable08 OUTPUT,    
         @cLottable09 = @cTempLottable09 OUTPUT,    
         @cLottable10 = @cTempLottable10 OUTPUT,    
         @cLottable11 = @cTempLottable11 OUTPUT,    
         @cLottable12 = @cTempLottable12 OUTPUT,    
         @dLottable13 = @dTempLottable13 OUTPUT,    
         @dLottable14 = @dTempLottable14 OUTPUT,    
         @dLottable15 = @dTempLottable15 OUTPUT    
--insert into a (field, value) values ('@nTempQTY', @nTempQTY)  
  
      IF @nTempQTY > 0  
         BREAK  
      ELSE  
         SELECT   
            @cGetNextSKU = 'Y',   
            @cTempLottable01 = '', @cTempLottable02 = '', @cTempLottable03 = '',    @dTempLottable04 = NULL,  @dTempLottable05 = NULL,  
            @cTempLottable06 = '', @cTempLottable07 = '', @cTempLottable08 = '',    @cTempLottable09 = '',    @cTempLottable10 = '',  
            @cTempLottable11 = '', @cTempLottable12 = '', @dTempLottable13 = NULL,  @dTempLottable14 = NULL,  @dTempLottable15 = NULL  
   END  
  
   IF @nTempQTY = 0  
   BEGIN  
      SET @nErrNo = 157552  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task  
      SET @nErrNo = -1 -- No more task  
      GOTO Quit  
   END  
     
   -- Assign to actual  
   SET @cSKU = @cTempSKU  
   SET @nTaskQTY = @nTempQTY   
   SET @cLottable01 = @cTempLottable01  
   SET @cLottable02 = @cTempLottable02  
   SET @cLottable03 = @cTempLottable03  
   SET @dLottable04 = @dTempLottable04  
   SET @dLottable05 = @dTempLottable05  
   SET @cLottable06 = @cTempLottable06  
   SET @cLottable07 = @cTempLottable07  
   SET @cLottable08 = @cTempLottable08  
   SET @cLottable09 = @cTempLottable09  
   SET @cLottable10 = @cTempLottable10  
   SET @cLottable11 = @cTempLottable11  
   SET @cLottable12 = @cTempLottable12  
   SET @dLottable13 = @dTempLottable13  
   SET @dLottable14 = @dTempLottable14  
   SET @dLottable15 = @dTempLottable15  
  
   -- Get SKU info  
   SELECT  
      @cSKUDescr = IsNULL( DescR, ''),  
      @cLottableCode = LottableCode,  
      @cPPK =       
         CASE WHEN SKU.PrePackIndicator = '2'       
            THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 5))       
            ELSE ''       
         END,   
      @cMUOM_Desc = Pack.PackUOM3,  
      @cPUOM_Desc =  
         CASE @cPUOM  
            WHEN '2' THEN Pack.PackUOM1 -- Case  
            WHEN '3' THEN Pack.PackUOM2 -- Inner pack  
            WHEN '6' THEN Pack.PackUOM3 -- Master unit  
            WHEN '1' THEN Pack.PackUOM4 -- Pallet  
            WHEN '4' THEN Pack.PackUOM8 -- Other unit 1  
            WHEN '5' THEN Pack.PackUOM9 -- Other unit 2  
         END,  
      @nPUOM_Div = CAST( IsNULL(  
         CASE @cPUOM  
            WHEN '2' THEN Pack.CaseCNT  
            WHEN '3' THEN Pack.InnerPack  
            WHEN '6' THEN Pack.QTY  
            WHEN '1' THEN Pack.Pallet  
            WHEN '4' THEN Pack.OtherUnit1  
            WHEN '5' THEN Pack.OtherUnit2  
         END, 1) AS INT)  
   FROM dbo.SKU WITH (NOLOCK)  
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
   WHERE SKU.StorerKey = @cStorerKey  
      AND SKU.SKU = @cSKU

Quit:

END

GO