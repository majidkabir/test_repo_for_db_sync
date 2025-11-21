SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispCNAPA01                                          */
/* Copyright: IDS                                                       */
/* Purpose: CNA putaway strategy.                                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2016-04-12   James     1.0   SOS368048 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispCNAPA01]
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
      @c_SuggestedLOC   NVARCHAR( 10), 
      @c_Facility       NVARCHAR( 5), 
      @nFunc            INT

   SET @b_debug = 0

   SET @c_SuggestedLOC = ''

   -- Get rdt function id
   SELECT @nFunc = Func, 
          @c_Facility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUSER_sName()

   -- Putaway by sku
   IF @nFunc = 523
   BEGIN
      /* Rules
         If sku no inventory, display blank suggested loc
         If sku with inventory
            If pick face assigned for the sku
               show the pick face as suggested loc
            else         
               display blank suggested loc
      */

      IF ISNULL( @c_SKU, '') = '' 
         GOTO Quit

      IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                  WHERE LLI.StorerKey = @c_StorerKey
                  AND   LLI.SKU = @c_SKU
                  AND   ( LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - 
                        (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
                  AND   LOC.Facility = @c_Facility)
      BEGIN
         SELECT TOP 1 @c_SuggestedLOC = SL.LOC
         FROM dbo.SKUxLOC SL WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
         WHERE LOC.Facility = @c_Facility
         AND   SL.SKU = @c_SKU
         AND   SL.StorerKey = @c_StorerKey
         AND   ( SL.LocationType = 'PICK' OR SL.LocationType = 'CASE')
         
         IF ISNULL( @c_SuggestedLOC, '') = ''
         BEGIN
            SET @c_SuggestedLOC = ''
            GOTO Quit
         END
      END
      ELSE
         GOTO Quit

   END   
   Quit:
   BEGIN
      SET @c_SQL = CASE WHEN ISNULL( @c_SuggestedLOC, '') = '' THEN ' AND 1 = 2' ELSE ' AND LOC.LOC = ''' + @c_SuggestedLOC + '''' END 

      RETURN
   END
END

GO