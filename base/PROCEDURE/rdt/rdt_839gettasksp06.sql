SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_839GetTaskSP06                                  */    
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose:                                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 19-07-2022 1.0  YeeKung     WMS-20239 Add DisExtValue                */  
/* 28-07-2023 1.1  Ung         WMS-23002 Add serial no                  */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_839GetTaskSP06] (    
  @nMobile          INT,              
  @nFunc            INT,              
  @cLangCode        NVARCHAR( 3),     
  @nStep            INT,              
  @nInputKey        INT,              
  @cFacility        NVARCHAR( 5) ,    
  @cStorerKey       NVARCHAR( 15),    
  @cType            NVARCHAR( 10),    
  @cPickSlipNo      NVARCHAR( 10),    
  @cPickZone        NVARCHAR( 10),     
  @nLottableOnPage  INT,  
  @cLOC             NVARCHAR( 10) OUTPUT,     
  @cSKU             NVARCHAR( 20) OUTPUT,     
  @cSKUDescr        NVARCHAR( 60) OUTPUT,     
  @nQTY             INT           OUTPUT,     
  @cDisableQTYField NVARCHAR( 1)  OUTPUT,     
  @cLottableCode    NVARCHAR( 30) OUTPUT,     
  @cLottable01      NVARCHAR( 18) OUTPUT,      
  @cLottable02      NVARCHAR( 18) OUTPUT,      
  @cLottable03      NVARCHAR( 18) OUTPUT,      
  @dLottable04      DATETIME      OUTPUT,      
  @dLottable05      DATETIME      OUTPUT,      
  @cLottable06      NVARCHAR( 30) OUTPUT,     
  @cLottable07      NVARCHAR( 30) OUTPUT,     
  @cLottable08      NVARCHAR( 30) OUTPUT,     
  @cLottable09      NVARCHAR( 30) OUTPUT,     
  @cLottable10      NVARCHAR( 30) OUTPUT,     
  @cLottable11      NVARCHAR( 30) OUTPUT,     
  @cLottable12      NVARCHAR( 30) OUTPUT,     
  @dLottable13      DATETIME      OUTPUT,     
  @dLottable14      DATETIME      OUTPUT,     
  @dLottable15      DATETIME      OUTPUT,     
  @nErrNo           INT           OUTPUT,     
  @cErrMsg          NVARCHAR(250) OUTPUT,
  @cSuggID          NVARCHAR(20)  OUTPUT, --(yeekung02)
  @nTtlBalQty      INT            OUTPUT, --(yeekung01)
  @nBalQty         INT            OUTPUT, --(yeekung01)   
  @cSKUSerialNoCapture NVARCHAR(1) OUTPUT
)    
AS    
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
    
IF @nFunc = 839    
BEGIN    
    
    
   DECLARE @cSQL      NVARCHAR( MAX)    
   DECLARE @cSQLParam NVARCHAR( MAX)    
   DECLARE @cGetTaskSP NVARCHAR( 20)    
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
   DECLARE @cGetNextSKU NVARCHAR( 1)    
          --,@nLottableOnPage  INT    
          ,@cDocType     NVARCHAR(1)   
    
   SET @nErrNo = 0 -- Require if calling GetTask multiple times (NEXTSKU then NEXTLOC)    
   SET @cErrMsg = ''    
     
   --SET @nLottableOnPage = 4   
    
  /***********************************************************************************************      
                                              Standard get task      
   ***********************************************************************************************/      
   DECLARE @cOrderKey   NVARCHAR( 10)      
   DECLARE @cLoadKey    NVARCHAR( 10)      
   DECLARE @cZone       NVARCHAR( 18)      
   DECLARE @cSuggSKU    NVARCHAR( 20)      
   DECLARE @cSuggLOC    NVARCHAR( 10)      
   DECLARE @nSuggQTY    INT      
   DECLARE @cCurrLogicalLOC    NVARCHAR( 18)      
   DECLARE @cCurrLOC           NVARCHAR( 10)      
   DECLARE @cPickConfirmStatus NVARCHAR( 1)      
    
   DECLARE @cSelect  NVARCHAR( MAX)      
   DECLARE @cFrom    NVARCHAR( MAX)      
   DECLARE @cWhere1  NVARCHAR( MAX)      
   DECLARE @cWhere2  NVARCHAR( MAX)      
   DECLARE @cGroupBy NVARCHAR( MAX)      
   DECLARE @cOrderBy NVARCHAR( MAX)      
          ,@cBFax1   NVARCHAR( 18)    
          ,@cOrderType NVARCHAR(1)    
   DECLARE @cCurrSKU NVARCHAR( 20)  
   DECLARE @cBalPick NVARCHAR( 10)  
  
   SET @cOrderKey = ''      
   SET @cLoadKey = ''      
   SET @cZone = ''      
     
   SET @cCurrLOC = @cLOC       
   SET @cCurrSKU = CASE WHEN @cSKU <> '' THEN @cSKU ELSE '' END  
   SET @cBalPick = CASE WHEN @cSKUDescr = '' THEN '' ELSE @cSKUDescr END  
   SET @cSKUDescr = ''  
  
   -- Get storer config      
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)      
   IF @cPickConfirmStatus = '0'      
      SET @cPickConfirmStatus = '5'      
      
   -- Get PickHeader info      
   SELECT TOP 1      
      @cOrderKey = OrderKey,      
      @cLoadKey = ExternOrderKey,      
      @cZone = Zone      
   FROM dbo.PickHeader WITH (NOLOCK)      
   WHERE PickHeaderKey = @cPickSlipNo      
      
   -- Get logical LOC      
   SET @cCurrLogicalLOC = ''      
   SELECT @cCurrLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cCurrLOC      
     
   SELECT @cDocType = DocType     
         ,@cBFax1 = B_Fax1    
   FROM dbo.Orders WITH (NOLOCK)     
   WHERE StorerKey = @cStorerKey    
   AND OrderKey = @cOrderKey   
  
  
   IF ISNULL(@cDocType,'' ) = 'N'    
   BEGIN    
      /***********************************************************************************************      
                                                 Get next Zone      
      ***********************************************************************************************/      
      IF @cType = 'NEXTZONE'      
      BEGIN      
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1   
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND LOC.PickZone <> @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND PD.UOM = '7'    
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END      
         END       
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND LOC.PickZone <> @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END      
         END            
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                  @cOrderkey = Orderkey
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ,
                  @cOrderkey = Orderkey     
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND LOC.PickZone <> @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LocationType = 'PICK'  
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU, Orderkey     
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
            END    
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''               BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
           CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
     '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
         
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT,        
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
      END     
          
      /***********************************************************************************************      
                                                 Get next LOC      
      ***********************************************************************************************/      
      IF @cType = 'NEXTLOC'      
      BEGIN      

         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
            END                   
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, STEP1, Col1, Col2, Col3, COL4, COL5) VALUES  
                  --('1234', GETDATE(), @cOrderKey, @cPickZone, @cPickConfirmStatus, @cCurrLOC, @cCurrSKU, @cCurrLogicalLOC)  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
    JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
             AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
  
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
            END      
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END    
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ,
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
  
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ,
                        @cOrderKey = Orderkey
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                        @cOrderKey = Orderkey
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
            END    
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
    
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
      '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
         
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT,        
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
      END      
      /***********************************************************************************************      
                                                 Get next SKU      
      ***********************************************************************************************/      
      ELSE IF @cType = 'NEXTSKU'     
      BEGIN      
         SET @cSuggLOC = @cCurrLOC      
               
             
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
            ELSE      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus    
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
            ELSE      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
         END      
            
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                  @cOrderKey = Orderkey
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
                  GROUP BY PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY PD.StorerKey, PD.SKU,Orderkey      
            ELSE      
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0), 
                  @cOrderkey = Orderkey
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
                  GROUP BY PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY PD.StorerKey, PD.SKU,Orderkey      
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
      END 
      
      /***********************************************************************************************      
                                                 Get current LOC      
      ***********************************************************************************************/      
      ELSE IF @cType = 'CLOSE'      
      BEGIN        
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                 @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
            END                   
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, STEP1, Col1, Col2, Col3, COL4, COL5) VALUES  
                  --('1234', GETDATE(), @cOrderKey, @cPickZone, @cPickConfirmStatus, @cCurrLOC, @cCurrSKU, @cCurrLogicalLOC)  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
  
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
           AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
            END      
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
            END    
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
  
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                        @cOrderKey =Orderkey
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ,
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                        @cOrderKey = Orderkey
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND LOC.LocationType = 'PICK'  
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderKey =Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND LOC.LocationType = 'PICK'  
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
            END    
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
    
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
         
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cOrderKey  = @cOrderKey,        
            @cLoadKey    = @cLoadKey,        
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT,        
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
      END    
   END    
   ELSE     
   BEGIN    
      /***********************************************************************************************      
                                                 Get next Zone      
      ***********************************************************************************************/      
      IF @cType = 'NEXTZONE'      
      BEGIN      
            
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6', '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                 
            END    
            ELSE      
            BEGIN    
                 
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone <> @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6', '7' )     
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                 
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''     
            BEGIN     
                
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6', '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
            ELSE      
            BEGIN    
                
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone <> @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6', '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
                
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND PD.UOM IN ( '6' , '7')    
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                
            END     
            ELSE      
            BEGIN    
                
               SELECT TOP 1      
                  @cSuggLOC = LOC.LOC,       
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND LOC.PickZone <> @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND PD.UOM IN ( '6', '7')    
                  AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                  OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
               GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               
            END    
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            SET @cSQL =       
        ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '  AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
         
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT,        
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
      END     
          
      /***********************************************************************************************      
                                                 Get next LOC      
      ***********************************************************************************************/      
      IF @cType = 'NEXTLOC'      
      BEGIN      

         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                
            END    
            ELSE    
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND LOC.PickZone = @cPickZone  
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
  
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
               @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone  
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                       AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                  
            END    
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6', '7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1 
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6', '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                 
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6' , '7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6' , '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
            END  
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
    
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +     
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
    
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT,        
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
      END      
      /***********************************************************************************************      
                                                 Get next SKU      
      ***********************************************************************************************/      
      ELSE IF @cType = 'NEXTSKU'      
      BEGIN      
         SET @cSuggLOC = @cCurrLOC      
               
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND PD.UOM IN ( '6','7')    
                  AND LOC.LOC = @cCurrLOC      
            AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU     
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.OrderKey = @cOrderKey      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus    
                  AND PD.UOM IN ( '6', '7')    
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND PD.UOM IN ( '6','7')    
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU   
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU      
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE LPD.LoadKey = @cLoadKey        
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus      
                  AND PD.UOM IN ( '6', '7')    
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
               GROUP BY PD.StorerKey, PD.SKU      
               ORDER BY PD.StorerKey, PD.SKU    
            END      
         END      
            
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND PD.UOM IN ('6' , '7')     
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
                  GROUP BY PD.StorerKey, PD.SKU     
                  ORDER BY PD.StorerKey, PD.SKU     
            END    
            ELSE      
            BEGIN    
               SELECT TOP 1      
                  @cSuggSKU = PD.SKU,       
                  @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)      
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
               WHERE PD.PickSlipNo = @cPickSlipNo      
                  AND LOC.PickZone = @cPickZone      
                  AND PD.QTY > 0      
                  AND PD.Status <> '4'      
                  AND PD.Status < @cPickConfirmStatus     
                  AND PD.UOM IN ( '6','7')    
                  AND LOC.LOC = @cCurrLOC      
                  AND PD.SKU > @cCurrSKU  
                  GROUP BY PD.StorerKey, PD.SKU     
                  ORDER BY PD.StorerKey, PD.SKU     
            END    
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
               
         /************************************** Get QTY and lottables *********************************/      
   --      SET @nSuggQTY = 0      
 --            
   --      -- Get lottable filter      
   --      EXEC rdt.rdt_Lottable_GetNextSQL @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @nLottableOnPage, @cTempLottableCode, 'LA',       
   --         @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,      
   --         @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,      
   --         @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,      
   --         @cSelect  OUTPUT,      
   --         @cWhere1  OUTPUT,      
   --         @cWhere2  OUTPUT,      
   --         @cGroupBy OUTPUT,      
   --         @cOrderBy OUTPUT,      
   --         @nErrNo   OUTPUT,      
   --         @cErrMsg  OUTPUT      
   --      
   --        
   --      -- Discrete PickSlip      
   --      IF @cOrderKey <> ''      
   --      BEGIN      
   --         SET @cSQL =       
   --         '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
   --         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
   --         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
   --         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
   --         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
   --         '    WHERE PD.OrderKey = @cOrderKey ' +       
   --         '       AND PD.QTY > 0 ' +       
   --         '       AND PD.Status <> ''4'' ' +       
   --         '       AND PD.Status < @cStatus ' +       
   --         '       AND LOC.LOC = @cLOC ' +       
   --         '       AND PD.UOM <> ''2'' ' +     
   --         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
   --         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
   --         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
   --         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
   --         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
   --      END      
   --                        
   --      -- Conso PickSlip      
   --      ELSE IF @cLoadKey <> ''      
   --      BEGIN      
   --         SET @cSQL =       
   --         '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +      
   --         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
   --         '    FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +      
   --         '       JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +      
   --         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +      
   --         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
   --         '    WHERE LPD.LoadKey = @cLoadKey ' +      
   --         '       AND PD.QTY > 0 ' +      
   --         '       AND PD.Status <> ''4'' ' +      
   --         '       AND PD.Status < @cStatus ' +      
   --         '       AND LOC.LOC = @cLOC ' +      
   --         '       AND PD.UOM <> ''2'' ' +     
   --         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
   --         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
   --         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
   --         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
   --         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
   --      END      
   --         
   --      -- Custom PickSlip      
   --      ELSE      
   --      BEGIN      
   --         SET @cSQL =       
   --         '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +      
   --         CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
   --         '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +      
   --         '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +      
   --         '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
   --         '    WHERE PD.PickSlipNo = @cPickSlipNo ' +      
   --         '       AND PD.QTY > 0 ' +      
   --         '       AND PD.Status <> ''4'' ' +      
 --         '       AND PD.Status < @cStatus ' +      
   --         '       AND LOC.LOC = @cLOC ' +      
   --         '       AND PD.UOM <> ''2'' ' +     
   --         CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
   --         CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
   --         CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
   --         CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
   --         CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
   --      END      
   --      
   --      SET @cSQLParam =       
   --         '@cPickSlipNo NVARCHAR( 10) , ' +        
   --         '@cOrderKey   NVARCHAR( 10) , ' +        
   --         '@cLoadKey    NVARCHAR( 10) , ' +        
   --         '@cLOC        NVARCHAR( 10) , ' +        
   --         '@cSKU        NVARCHAR( 20) , ' +        
   --         '@cStatus     NVARCHAR( 1)  , ' +       
   --         '@cPickZone   NVARCHAR( 10) , ' +       
   --         '@nQTY        INT           OUTPUT, ' +       
   --         '@cLottable01 NVARCHAR( 18) OUTPUT, ' +        
   --         '@cLottable02 NVARCHAR( 18) OUTPUT, ' +        
   --         '@cLottable03 NVARCHAR( 18) OUTPUT, ' +        
   --         '@dLottable04 DATETIME      OUTPUT, ' +        
   --         '@dLottable05 DATETIME      OUTPUT, ' +        
   --         '@cLottable06 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable07 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable08 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable09 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable10 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable11 NVARCHAR( 30) OUTPUT, ' +       
   --         '@cLottable12 NVARCHAR( 30) OUTPUT, ' +       
   --         '@dLottable13 DATETIME      OUTPUT, ' +       
   --         '@dLottable14 DATETIME      OUTPUT, ' +       
   --         '@dLottable15 DATETIME      OUTPUT  '      
   --      
   --      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,       
   --         @cPickSlipNo = @cPickSlipNo,        
   --         @cOrderKey   = @cOrderKey,        
   --         @cLoadKey    = @cLoadKey,        
   --         @cLOC        = @cSuggLOC,        
   --         @cSKU        = @cSuggSKU,        
   --         @cStatus     = @cPickConfirmStatus,       
   --         @cPickZone   = @cPickZone,      
   --         @nQTY        = @nSuggQTY        OUTPUT,        
   --         @cLottable01 = @cTempLottable01 OUTPUT,         
   --         @cLottable02 = @cTempLottable02 OUTPUT,         
   --         @cLottable03 = @cTempLottable03 OUTPUT,         
   --         @dLottable04 = @dTempLottable04 OUTPUT,         
   --         @dLottable05 = @dTempLottable05 OUTPUT,         
   --         @cLottable06 = @cTempLottable06 OUTPUT,        
   --         @cLottable07 = @cTempLottable07 OUTPUT,        
   --         @cLottable08 = @cTempLottable08 OUTPUT,        
   --         @cLottable09 = @cTempLottable09 OUTPUT,        
   --         @cLottable10 = @cTempLottable10 OUTPUT,        
   --         @cLottable11 = @cTempLottable11 OUTPUT,        
   --         @cLottable12 = @cTempLottable12 OUTPUT,        
   --         @dLottable13 = @dTempLottable13 OUTPUT,        
   --         @dLottable14 = @dTempLottable14 OUTPUT,        
   --         @dLottable15 = @dTempLottable15 OUTPUT        
      END      

      /***********************************************************************************************      
                                                 Get current LOC      
      ***********************************************************************************************/      
      ELSE IF @cType = 'CLOSE'      
      BEGIN      
         -- Discrete PickSlip      
         IF @cOrderKey <> ''      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
               END  
               ELSE 
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                
            END    
            ELSE    
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD (NOLOCK)           
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey        
                     AND LOC.PickZone = @cPickZone  
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.OrderKey = @cOrderKey      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.OrderKey = @cOrderKey      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
  
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
              SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone  
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE LPD.LoadKey = @cLoadKey        
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6','7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)      
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)       
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)          
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE LPD.LoadKey = @cLoadKey        
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6','7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                  
            END    
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            IF @cPickZone = ''      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                     @cOrderkey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0),
                        @cOrderkey = Orderkey
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ( '6', '7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0) ,
                     @cOrderkey = Orderkey
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ( '6', '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU,Orderkey      
                 
            END    
            ELSE      
            BEGIN    
               IF @cCurrLOC <> '' AND @cCurrSKU <> '' AND @cBalPick <> 'BALPICK'  
               BEGIN  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6','7')    
                     AND LOC.LOC >= @cCurrLOC      
                     AND PD.Sku >= @cCurrSKU  
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU    
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                    
                  IF @@ROWCOUNT = 0  
                     SELECT TOP 1      
                        @cSuggLOC = LOC.LOC,       
                        @cSuggSKU = PD.SKU,       
                        @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)      
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                     WHERE PD.PickSlipNo = @cPickSlipNo      
                        AND LOC.PickZone = @cPickZone      
                        AND PD.QTY > 0      
                        AND PD.Status <> '4'      
                        AND PD.Status < @cPickConfirmStatus      
                        AND PD.UOM IN ('6' , '7')    
                        AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                        OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC >= @cCurrLOC))      
                     GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU   
                     ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
               END  
               ELSE  
                  SELECT TOP 1      
                     @cSuggLOC = LOC.LOC,       
                     @cSuggSKU = PD.SKU,       
                     @nSuggQTY = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)      
                     JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)      
                  WHERE PD.PickSlipNo = @cPickSlipNo      
                     AND LOC.PickZone = @cPickZone      
                     AND PD.QTY > 0      
                     AND PD.Status <> '4'      
                     AND PD.Status < @cPickConfirmStatus      
                     AND PD.UOM IN ('6' , '7')    
                     AND (LOC.LogicalLocation > @cCurrLogicalLOC      
                     OR  (LOC.LogicalLocation = @cCurrLogicalLOC AND LOC.LOC > @cCurrLOC))      
                  GROUP BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                  ORDER BY LOC.LogicalLocation, LOC.LOC, PD.StorerKey, PD.SKU     
                
            END     
         END      
         
         -- Get SKU info      
         SELECT       
            @cTempLottableCode = LottableCode      
         FROM dbo.SKU WITH (NOLOCK)      
         WHERE StorerKey = @cStorerKey      
            AND SKU = @cSuggSKU      
         
         SET @cGetNextSKU = 'N'      
               
         -- Assign to temp      
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
                  
         /************************************** Get QTY and lottables *********************************/      
    
               
         SET @nSuggQTY = 0      
               
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
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +     
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         
         END      
         -- Discrete PickSlip      
         ELSE IF @cOrderKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE PD.OrderKey = @cOrderKey ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
                           
         -- Conso PickSlip      
         ELSE IF @cLoadKey <> ''      
         BEGIN      
            SET @cSQL =       
            ' SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +       
            '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +       
            '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '    JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            ' WHERE LPD.LoadKey = @cLoadKey ' +         
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
               
         -- Custom PickSlip      
         ELSE      
         BEGIN      
            SET @cSQL =       
            '    SELECT @nQTY = ISNULL( SUM( PD.QTY), 0) ' +       
            CASE WHEN @cSelect = '' THEN '' ELSE ', ' + @cSelect END +       
            '    FROM dbo.PickDetail PD WITH (NOLOCK) ' +       
            '       JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +       
            '       JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +       
            '    WHERE PD.PickSlipNo = @cPickSlipNo ' +       
            '    AND PD.QTY > 0 ' +       
            '    AND PD.Status <> ''4'' ' +       
            '    AND PD.Status < @cStatus ' +       
            '    AND LOC.LOC = @cLOC ' +       
            '    AND PD.SKU = @cSKU ' +       
            '    AND PD.UOM <> ''2'' ' +     
            --CASE WHEN @cOrderType = '1' THEN ' AND PD.UOM IN ( ''6'', ''7'') ' ELSE ' AND PD.UOM = ''7'' ' END +    
            CASE WHEN @cPickZone = '' THEN '' ELSE '    AND LOC.PickZone = @cPickZone ' END +       
            CASE WHEN @cWhere1 = '' THEN '' ELSE ' AND ' + @cWhere1 END +       
            CASE WHEN @cWhere2 = '' THEN '' ELSE ' > '   + @cWhere2 END +      
            CASE WHEN @cGroupBy = '' THEN '' ELSE ' GROUP BY ' + @cGroupBy END +      
            CASE WHEN @cOrderBy = '' THEN '' ELSE ' ORDER BY ' + @cOrderBy END       
         END      
    
         SET @cSQLParam =       
            '@cPickSlipNo NVARCHAR( 10) , ' +        
            '@cOrderKey   NVARCHAR( 10) , ' +        
            '@cLoadKey    NVARCHAR( 10) , ' +        
            '@cLOC        NVARCHAR( 10) , ' +        
            '@cSKU        NVARCHAR( 20) , ' +        
            '@cStatus     NVARCHAR( 1)  , ' +       
            '@cPickZone   NVARCHAR( 10) , ' +       
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
            @cLOC        = @cSuggLOC,        
            @cSKU        = @cSuggSKU,        
            @cStatus     = @cPickConfirmStatus,       
            @cPickZone   = @cPickZone,      
            @nQTY        = @nSuggQTY        OUTPUT, 
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
      END      
   END    

   /***********************************************************************************************      
                                              Get Balance task    
   ***********************************************************************************************/    
       
   IF @nTtlBalQty = 0    
   BEGIN    
      -- Cross dock PickSlip                
      IF @cZone IN ('XD', 'LB', 'LP')                
      BEGIN    
         IF @cPickZone = ''    
            SELECT  @nTtlBalQty= SUM(PD.QTY)    
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)                
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)                
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
               WHERE RKL.PickSlipNo = @cPickSlipNo                
                  AND PD.QTY > 0     
                  AND PD.UOM <>2                           
         ELSE    
            SELECT  @nTtlBalQty= SUM(PD.QTY)    
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)                
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)                
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
               WHERE RKL.PickSlipNo = @cPickSlipNo    
                  AND LOC.PickZone = @cPickZone                 
                  AND PD.QTY > 0   
                  AND PD.UOM <>2                             
      END    
      -- Discrete PickSlip                
      ELSE IF @cOrderKey <> ''                
      BEGIN    
         IF @cPickZone = ''    
            SELECT  @nTtlBalQty= SUM(PD.QTY)    
            FROM dbo.PickDetail PD WITH (NOLOCK)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE PD.OrderKey = @cOrderKey                         
               AND PD.QTY > 0  
               AND PD.UOM <>2                  
         ELSE    
            SELECT  @nTtlBalQty= SUM(PD.QTY)    
            FROM dbo.PickDetail PD WITH (NOLOCK)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE PD.OrderKey = @cOrderKey                
               AND LOC.PickZone = @cPickZone                
               AND PD.QTY > 0 
               AND PD.UOM <>2                                      
      END    
       -- Conso PickSlip                
      ELSE IF @cLoadKey <> ''                
      BEGIN                
         IF @cPickZone = ''                
            SELECT  @nTtlBalQty= SUM(PD.QTY)           
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)                 
              JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)                    
              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE LPD.LoadKey = @cLoadKey                  
               AND PD.QTY > 0  
               AND PD.UOM <>2                                                    
         ELSE               
            SELECT  @nTtlBalQty= SUM(PD.QTY)           
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)                 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)                    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE LPD.LoadKey = @cLoadKey                  
               AND LOC.PickZone = @cPickZone                
               AND PD.QTY > 0   
               AND PD.UOM <>2                                                         
      END                
                      
      -- Custom PickSlip                
      ELSE                
      BEGIN                
         IF @cPickZone = ''                
            SELECT  @nTtlBalQty= SUM(PD.QTY)              
            FROM dbo.PickDetail PD WITH (NOLOCK)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE PD.PickSlipNo = @cPickSlipNo               
               AND PD.QTY > 0   
               AND PD.UOM <>2                                                             
         ELSE                
           SELECT  @nTtlBalQty= SUM(PD.QTY)         
            FROM dbo.PickDetail PD WITH (NOLOCK)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE PD.PickSlipNo = @cPickSlipNo                
               AND LOC.PickZone = @cPickZone                 
               AND PD.QTY > 0 
               AND PD.UOM <>2                                                             
      END       
   END     
       
   -- Cross dock PickSlip                
   IF @cZone IN ('XD', 'LB', 'LP')                
   BEGIN    
      IF @cPickZone = ''    
         SELECT  @nBalQty= SUM(PD.QTY)    
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)                
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE RKL.PickSlipNo = @cPickSlipNo                
               AND PD.QTY > 0                
               --AND PD.Status <>'4'       
               AND PD.Status <@cPickConfirmStatus
               AND PD.UOM <>2                      
      ELSE    
         SELECT  @nBalQty= SUM(PD.QTY)    
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)                
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)                
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
            WHERE RKL.PickSlipNo = @cPickSlipNo    
               AND LOC.PickZone = @cPickZone                  
               AND PD.QTY > 0                
               --AND PD.Status <>'4'       
               AND PD.Status <@cPickConfirmStatus 
               AND PD.UOM <>2                            
   END    
   -- Discrete PickSlip                
   ELSE IF @cOrderKey <> ''                
   BEGIN    
      IF @cPickZone = ''    
         SELECT  @nBalQty= SUM(PD.QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)                
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE PD.OrderKey = @cOrderKey                       
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus
            AND PD.UOM <>2                          
    
      ELSE    
         SELECT  @nBalQty= SUM(PD.QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)                
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE PD.OrderKey = @cOrderKey                
            AND LOC.PickZone = @cPickZone                
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus  
            AND PD.UOM <>2                           
   END    
      -- Conso PickSlip                
   ELSE IF @cLoadKey <> ''                
   BEGIN                
      IF @cPickZone = ''                
         SELECT  @nBalQty= SUM(PD.QTY)           
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)                 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)                    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE LPD.LoadKey = @cLoadKey                  
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus  
            AND PD.UOM <>2                
      ELSE                
         SELECT  @nBalQty= SUM(PD.QTY)           
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)                 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)                    
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE LPD.LoadKey = @cLoadKey                  
            AND LOC.PickZone = @cPickZone                
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus 
            AND PD.UOM <>2           
   END                
                      
   -- Custom PickSlip                
   ELSE                
   BEGIN                
      IF @cPickZone = ''                
         SELECT  @nBalQty= SUM(PD.QTY)              
         FROM dbo.PickDetail PD WITH (NOLOCK)                
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE PD.PickSlipNo = @cPickSlipNo                
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus
            AND PD.UOM <>2                                  
      ELSE                
         SELECT  @nBalQty= SUM(PD.QTY)         
         FROM dbo.PickDetail PD WITH (NOLOCK)                
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)                
         WHERE PD.PickSlipNo = @cPickSlipNo                
            AND LOC.PickZone = @cPickZone                
            AND PD.QTY > 0                
            --AND PD.Status <>'4'       
            AND PD.Status <@cPickConfirmStatus
            AND PD.UOM <>2                                
   END 
       
   /***********************************************************************************************      
                                              Return task      
   ***********************************************************************************************/      
   IF ISNULL( @cSuggSKU, '') = ''      
   BEGIN      
      SET @nErrNo = 100151      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task      
      SET @nErrNo = -1 -- No more task      
   END      
   ELSE      
   BEGIN      
      -- Assign to actual      
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
      SET @cLottableCode = @cTempLottableCode      
      
      SET @cLOC = @cSuggLOC      
      SET @cSKU = @cSuggSKU      
      SET @nQTY = @nSuggQTY      
            
      -- Get SKU description      
      DECLARE @cDispStyleColorSize  NVARCHAR( 20)      
      SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)   
      
      --yeekung05
      DECLARE @cDispExtValue  NVARCHAR( 20)    
      SET @cDispExtValue = rdt.RDTGetConfig( @nFunc, 'DispExtValues', @cStorerKey)  --(yeekung04)  
      
      
      SELECT TOP 1 @cOrderkey=orderkey
      FROM pickdetail PD (nolock)
         WHERE PD.PickSlipNo = @cPickSlipNo        
            AND PD.QTY > 0      
            AND PD.Status <> '4'   
            AND PD.Loc = @cSuggLOC
            AND PD.SKU = @cSuggSKU
            AND PD.Status < @cPickConfirmStatus      
            AND PD.UOM IN ('6' , '7') 
            
      IF @cDispStyleColorSize = '0'      
         SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU      
            
      ELSE IF @cDispStyleColorSize = '1'      
         SELECT @cSKUDescr =       
            CAST( Style AS NCHAR(20)) +       
            CAST( Color AS NCHAR(10)) +       
            CAST( Size  AS NCHAR(10))       
         FROM SKU WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey       
            AND SKU = @cSKU      

      IF @cDispExtValue ='1' --(yeekung04)
      BEGIN
         DECLARE @cTable NVARCHAR(20)
         DECLARE @cNotes NVARCHAR(MAX)
         DECLARE @cColumnName NVARCHAR(20)

         SELECT @cTable=long,
                @cNotes = notes,
                @cColumnName=udf01
         FROM codelkup (NOLOCK)
         where storerkey=@cStorerKey
         AND LISTNAME='RefColLkup'

        SET @cSQL =             
         '    SELECT @cSKUDescr = ' + @cNotes +
         '    FROM dbo.'+@cTable + ' WITH (NOLOCK)' +
         '    WHERE storerkey=@cStorerkey ' +  
         '       AND  sku = @cSKU         ' +
         CASE WHEN ISNULL (@cColumnName,'') <>'' THEN 
         '       AND ' + @cColumnName + '= @c' + @cColumnName 
         ELSE '' END


         SET @cSQLParam =          
            '@cOrderKey   NVARCHAR( 10) , ' +      
            '@cStorerkey  NVARCHAR( 20) , ' +        
            '@cSKU        NVARCHAR( 20) , ' + 
            '@cSKUDescr   NVARCHAR( 60) OUTPUT ' 
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @cStorerKey = @cStorerKey,      
            @cOrderKey   = @cOrderKey,          
            @cSKU        = @cSuggSKU,        
            @cSKUDescr   = @cSKUDescr        OUTPUT  
      END
      
      -- Get DisableQTYField      
      DECLARE @cDisableQTYFieldSP NVARCHAR( 20)      
      SET @cDisableQTYFieldSP = rdt.rdtGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)      
      
      IF @cDisableQTYFieldSP = '0'      
         SET @cDisableQTYField = ''      
      ELSE IF @cDisableQTYFieldSP = '1'      
         SET @cDisableQTYField = '1'      
      ELSE      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cLOC, @cSKU, @nQTY, ' +      
               ' @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'      
            SET @cSQLParam =      
               '@nMobile          INT,           ' +      
               '@nFunc            INT,           ' +      
               '@cLangCode        NVARCHAR( 3),  ' +      
               '@nStep            INT,           ' +      
               '@nInputKey        INT,           ' +      
               '@cFacility        NVARCHAR( 5),  ' +       
               '@cStorerKey       NVARCHAR( 15), ' +      
              '@cPickSlipNo      NVARCHAR( 10), ' +      
               '@cPickZone        NVARCHAR( 10), ' +      
               '@cLOC             NVARCHAR( 10), ' +      
               '@cSKU             NVARCHAR( 20), ' +      
               '@nQTY             INT,           ' +      
               '@cDisableQTYField NVARCHAR( 1)  OUTPUT, ' +       
               '@nErrNo           INT           OUTPUT, ' +      
               '@cErrMsg          NVARCHAR( 20) OUTPUT  '      
      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cPickZone, @cLOC, @cSKU, @nQTY,      
               @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT      
         END      
      END      
   END      
         
Quit:      

END


GO