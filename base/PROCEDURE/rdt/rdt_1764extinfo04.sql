SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo04                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-03-08   Ung       1.0   WMS-4096 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtInfo04]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cPickMethod NVARCHAR( 10)
   DECLARE @cFromID     NVARCHAR( 18)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @nQTY_RPL    INT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 2 AND  -- From LOC  
         @nAfterStep = 3 -- From ID
      BEGIN
         -- Get TaskDetail info
         SET @cTaskType = ''
         SELECT 
            @cTaskType = TaskType, 
            @cPickMethod = PickMethod, 
            @cFromID = FromID, 
            @cStorerKey = StorerKey,  
            @cSKU = SKU, 
            @nQTY_RPL = QTY
         FROM TaskDetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
      
         IF @cTaskType = 'RPF' AND @cPickMethod = 'FP'
         BEGIN
            DECLARE @cSKUDesc    NVARCHAR( 60)
            DECLARE @cDesc1      NVARCHAR( 20)
            DECLARE @cDesc2      NVARCHAR( 20)
            DECLARE @cPUOM_Desc  NCHAR( 5)
            DECLARE @cMUOM_Desc  NCHAR( 5)
            DECLARE @cPQTY_RPL   NCHAR( 5)
            DECLARE @cMQTY_RPL   NCHAR( 5)
            DECLARE @nPUOM_Div   INT -- UOM divider
            DECLARE @cPUOM       NVARCHAR(1)
            DECLARE @cUOM_Line   NVARCHAR(20)
            DECLARE @cQTY_Line   NVARCHAR(20)

            -- Get preferred UOM
            SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
            
            -- Get SKU info
            SELECT
               @cSKUDesc = S.Descr,
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
               @nPUOM_Div = CAST(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END AS INT)
            FROM dbo.SKU S WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU

            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0 -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @cPQTY_RPL = ''
               SET @cMQTY_RPL = CAST( @nQTY_RPL AS NCHAR( 5))
            END
            ELSE
            BEGIN
               SET @cPQTY_RPL = CAST( @nQTY_RPL / @nPUOM_Div AS NCHAR(5)) -- Calc QTY in preferred UOM
               SET @cMQTY_RPL = CAST( @nQTY_RPL % @nPUOM_Div AS NCHAR(5)) -- Calc the remaining in master unit
            END

            SET @cDesc1 = SUBSTRING( @cSKUDesc, 1, 20)
            SET @cDesc2 = SUBSTRING( @cSKUDesc, 21, 20)
            SET @cUOM_Line = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
            SET @cQTY_Line = SPACE( 9) + @cPQTY_RPL + ' ' +  @cMQTY_RPL

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT
               ,'FROM ID:'
               ,@cFromID
               ,''
               ,'SKU:'
               ,@cSKU
               ,@cDesc1
               ,@cDesc2
               ,''
               ,@cUOM_Line
               ,@cQTY_Line 
         END
      END
   END

Quit:

END

GO