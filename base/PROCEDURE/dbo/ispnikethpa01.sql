SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispNikeTHPA01                                       */
/* Copyright: IDS                                                       */
/* Purpose: NIKE TH putaway strategy.                                   */
/*          Find friend with sku sku style (itemclass)                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-05-15   James     1.0   WMS1862. Created                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispNikeTHPA01]
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

   DECLARE 
      @c_PAZone01             NVARCHAR( 10), 
      @c_PAZone02             NVARCHAR( 10), 
      @c_PAZone03             NVARCHAR( 10), 
      @c_PAZone04             NVARCHAR( 10), 
      @c_PAZone05             NVARCHAR( 10), 
      @c_SearchZone           NVARCHAR(10),  
      @c_SuggestedLOC         NVARCHAR( 10), 
      @c_Facility             NVARCHAR( 5), 
      @c_MultiPutawayZone     NVARCHAR( 100), 
      @c_ExecStatements       NVARCHAR( 4000), 
      @c_ExecArguments        NVARCHAR( 4000),
      @n_Func                 INT,
      @nPutawayZoneCount      INT,
      @n_PalletTotStdCube     DECIMAL(15,5),
      @c_Style                NVARCHAR( 20),
      @c_PAType               NVARCHAR( 5)


   SET @b_debug = 0
   
   -- Get rdt function id
   SELECT @n_Func = Func, 
          @c_Facility = Facility,
          @c_StorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

   -- Get Facility
   SELECT @c_Facility = Facility 
   FROM dbo.LOC WITH (NOLOCK) 
   WHERE LOC = @c_FromLoc

   SELECT @c_PAType = PAType
   FROM dbo.PutawayStrategyDetail WITH (NOLOCK) 
   WHERE PutawayStrategyKey = @c_PutawayStrategyKey
   AND   PutawayStrategyLineNumber = @c_PutawayStrategyLineNumber

   IF @n_Func = 1819 OR SUSER_SNAME() = 'jameswong'
   BEGIN
      IF ISNULL( @c_ID, '') = '' OR ISNULL( @c_FromLoc, '') = ''
         GOTO Quit

      SELECT TOP 1 @c_Style = SKU.ItemClass
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey)
      WHERE LLI.LOC = @c_FromLoc 
      AND   LLI.ID  = @c_ID 
      AND   LLI.Qty > 0  
      AND   LLI.StorerKey = @c_StorerKey

      IF @c_PAType = '21'
         SET @c_SQL = CASE WHEN ISNULL( @c_Style, '') <> '' THEN ' AND EXISTS ( SELECT 1 FROM SKU SKU WITH (NOLOCK) WHERE SKU.SKU = LOTxLOCxID.SKU AND SKU.ItemClass = ''' + @c_Style + '''' + ')' ELSE '' END
      
   END
END

   Quit:
      RETURN


GO