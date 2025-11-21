SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Function: fnc_SKUXLOC_Extended                                            */
/* Creation Date: 10-Jul-2018                                                */
/* Copyright: LF Logistics                                                   */
/* Written by:                                                               */
/*                                                                           */
/* Purpose: WMS-5638 - Get additional fields for SKUXLOC such as qtyreplen,  */
/*          pendingmovein.                                                   */
/*        :                                                                  */
/* Called By: CROSS APPLY dbo.fnc_skuxloc_extended(t.StorerKey,t.Sku, t.Loc) */
/*          : OUTER APPLY                                                    */
/* PVCS Version: 1.0                                                         */
/*                                                                           */
/* Version: 7.0                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author    Ver Purposes                                       */
/* 30-Oct-2019  NJOW01    1.0 WMS-11308 add qtyexpected column               */
/*****************************************************************************/
CREATE FUNCTION [dbo].fnc_SKUXLOC_Extended(@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Loc NVARCHAR(10))
RETURNS TABLE
AS 
RETURN
(
	SELECT LLI.Storerkey, LLI.Sku, LLI.Loc, 
	       SUM(LLI.QtyReplen) AS QtyReplen,
	       SUM(LLI.PendingMoveIn) AS PendingMoveIn,
	       SUM(LLI.QtyExpected) AS QtyExpected
	FROM LOTXLOCXID LLI (NOLOCK)
	WHERE LLI.Storerkey = @c_Storerkey
	AND LLI.Sku = @c_Sku
	AND LLI.Loc = @c_Loc
	GROUP BY LLI.Storerkey, LLI.Sku, LLI.Loc
)


GO