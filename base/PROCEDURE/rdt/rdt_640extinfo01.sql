SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_640ExtInfo01                                    */  
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display total ctn to be picked                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2023-06-08   James     1.0   WMS-22212 Created                       */  
/************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_640ExtInfo01]  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cGroupKey      NVARCHAR( 10),
   @cTaskDetailKey NVARCHAR( 10),
   @cCartId        NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @tExtInfo       VariableTable READONLY, 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT

AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cSuggSKU             NVARCHAR( 20)
   DECLARE @nSuggQty             INT = 0
   DECLARE @nPickedQty           INT = 0
   DECLARE @cPUOM                NVARCHAR(  1)
   DECLARE @nPUOM_Div            INT
   DECLARE @nPQTY                INT = 0
   DECLARE @nMQTY                INT = 0
   DECLARE @nSuggPQTY            INT = 0
   DECLARE @nSuggMQTY            INT = 0
   
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
   IF @cPickConfirmStatus = '0'    
      SET @cPickConfirmStatus = '5'    

   
   IF @nAfterStep = 5   -- SKU/Qty
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	SELECT @cPUOM = V_UOM
      	FROM rdt.RDTMOBREC WITH (NOLOCK)
      	WHERE Mobile = @nMobile
      	
      	SELECT @cSuggSKU = SKU
      	FROM dbo.TaskDetail WITH (NOLOCK)
      	WHERE TaskDetailKey = @cTaskDetailKey
      	
      	SELECT @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.SKU = @cSuggSKU
         
         SELECT @nSuggQty = ISNULL( SUM( Qty), 0)  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   Loc = @cFromLoc  
         AND   Sku = @cSuggSKU  
         AND   CaseID = @cCartonID  
         AND   [Status] < @cPickConfirmStatus  
  
         SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   Loc = @cFromLoc  
         AND   Sku = @cSuggSKU  
         AND   CaseID = @cCartonID  
         AND   [Status] = @cPickConfirmStatus  

         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = @nSuggQty
         END
         ELSE
         BEGIN
         	-- Picked qty
            SET @nPQTY = @nPickedQty / @nPUOM_Div 
            SET @nMQTY = @nPickedQty % @nPUOM_Div 

            -- Suggested qty
            SET @nSuggPQTY = @nSuggQty / @nPUOM_Div 
            SET @nSuggMQTY = @nSuggQty % @nPUOM_Div 
         END

         SET @cExtendedInfo = 'PICKED/TOT:' + 
                              RTRIM( CAST( @nPQTY AS NVARCHAR( 3))) + 
                              '/' + 
                              RTRIM( CAST( @nSuggPQTY AS NVARCHAR( 3))) + 
                              ':' + 
                              CAST( @nSuggQTY AS NVARCHAR( 3))
      END
   END

          
   Quit:               

END  
SET QUOTED_IDENTIFIER OFF 

GO