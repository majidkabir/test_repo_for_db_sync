SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispCheckLocMaxSKU                                   */
/* Copyright: IDS                                                       */
/* Purpose: HnM putaway strategy. This storer has different PA strategy */
/*          for different putaway method for the same sku.              */
/*          so we need to use putcode to diffentiate                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-03-14   James     1.0   SOS301647 Created                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispCheckLocMaxSKU]
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

   SET @b_debug = 0
   
   SET @c_SQL =   
   ' AND ( SELECT COUNT( DISTINCT LLI.SKU) + 1 ' +
   '       FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' +
   '       WHERE LLI.Loc = LOC.Loc ' +
   '       AND  (LLI.QTY > 0 OR LLI.PendingMoveIN > 0)) <= LOC.MaxSKU  '
   RETURN             
      
   Quit:

END


GO