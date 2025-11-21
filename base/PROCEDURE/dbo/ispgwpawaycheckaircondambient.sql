SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispGWPAwayCheckAircondAmbient                       */
/* Copyright: IDS                                                       */
/* Purpose: Putaway Strategy for liquor accounts (Beam/Remy/Edrington)  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-05-12   James     1.0   SOS337104 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGWPAwayCheckAircondAmbient]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey                 NVARCHAR(15)
   ,@c_SKU                       NVARCHAR(20)
   ,@c_LOT                       NVARCHAR(10)
   ,@c_FromLoc                   NVARCHAR(10)
   ,@c_ID                        NVARCHAR(18)
   ,@n_Qty                       INT     
   ,@c_ToLoc                     NVARCHAR(10)
   ,@c_Param1                    NVARCHAR(20)
   ,@c_Param2                    NVARCHAR(20)
   ,@c_Param3                    NVARCHAR(20)
   ,@c_Param4                    NVARCHAR(20)
   ,@c_Param5                    NVARCHAR(20)
   ,@b_debug                     INT
   ,@c_SQL                       VARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed        INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Bonded             NVARCHAR( 1),
           @c_Facility           NVARCHAR( 5),
           @c_SuggestedLOC       NVARCHAR( 10),
           @c_SKUPAZone          NVARCHAR( 10), 
           @c_TemperatureFlag    NVARCHAR( 30), 
           @c_PutawayZone        NVARCHAR( 10), 
           @c_Lottable01         NVARCHAR( 18), 
           @c_Lottable06         NVARCHAR( 30), 
           @c_SUSR3              NVARCHAR( 20), 
           @c_Brand              NVARCHAR( 20), 
           @d_Lottable04         DATETIME, 
           @c_PalletTotStdCube   NVARCHAR( 10), 
           @nFunc                INT

   DECLARE  @cExecStatements  NVARCHAR( 4000),  
            @cExecArguments   NVARCHAR( 4000)

   SET @c_SuggestedLOC = ''
   SET @c_SQL = ''

   -- Get rdt function id
   SELECT @nFunc = Func, @c_Facility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

   IF ISNULL( @c_SKU, '') = ''
      SELECT TOP 1 @c_SKU = SKU
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
      WHERE LOC.Facility = @c_Facility
      AND   LLI.ID = @c_ID
      AND   LLI.QTY > 0

   IF ISNULL( @c_SKU, '') = ''
      RETURN

   SELECT @c_SKUPAZone = PutawayZone 
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @c_StorerKey
   AND   SKU = @c_SKU

   -- From aircond zone putaway to aircond zone only
   IF @c_SKUPAZone = 'AIRCOND'
      SET @c_SQL = ' AND EXISTS ( SELECT 1 FROM PutAwayZone PZ WITH (NOLOCK) WHERE LOC.PutAwayZone = PZ.PutAwayZone AND PZ.PutAwayZone = ''AIRCOND'' ) '

   -- From ambient zone putaway to ambient or 
   -- From ambient zone putaway to aircond with condition sku.itemclass exists in codelkup with udf01 = 'FG'
   IF @c_SKUPAZone = 'AMBIENT'
      SET @c_SQL = ' AND EXISTS (( SELECT 1 FROM PutAwayZone PZ WITH (NOLOCK) WHERE LOC.PutAwayZone = PZ.PutAwayZone AND PZ.PutAwayZone = ''AMBIENT'' ) ' + 
                     ' OR  EXISTS ( SELECT 1 FROM PutAwayZone PZ WITH (NOLOCK) WHERE LOC.PutAwayZone = PZ.PutAwayZone AND PZ.PutAwayZone = ''AIRCOND'' ) ' + 
                     ' AND EXISTS ( SELECT 1 FROM SKU SKU WITH (NOLOCK) JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ( SKU.ItemClass = CL.Code AND SKU.StorerKey = CL.StorerKey) ' + 
                     '      WHERE LOTxLOCxID.SKU = SKU.SKU ' + 
                     '      AND   CL.ListName = ''ITEMCLASS'' ' + 
                     '      AND   CL.UDF01 = ''FG'' )'

   RETURN
END

GO