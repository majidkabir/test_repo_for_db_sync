SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_shortReplenAlert                               */  
/* Creation Date: 25-Oct-2018                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: UA check short replenishment after release task before      */
/*          confirm replenishment.                                      */
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_shortReplenAlert]
   @c_wavekey      NVARCHAR(10)
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF
        
    SELECT DISTINCT PD.Storerkey, PD.Sku, PD.Loc
    INTO #TMP_WAVEREP
    FROM WAVEDETAIL AS WD WITH (NOLOCK)
    JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
    JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
    JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
    WHERE WD.WaveKey = @c_Wavekey
    AND (LOC.LocationType IN ('DYNPPICK','DYNPICKP','DYNPICKR') OR SL.LocationType IN('PICK','CASE'))
    
    SELECT RP.Storerkey, RP.Sku, RP.ToLoc, SUM(RP.Qty) AS Qty
    INTO #TMP_REP
    FROM REPLENISHMENT RP (NOLOCK) 
    JOIN #TMP_WAVEREP WL ON RP.Storerkey = WL.Storerkey AND RP.Sku = WL.Sku AND RP.ToLoc = WL.Loc
    WHERE RP.Confirmed = 'N'
    AND RP.qty > 0 
    GROUP BY RP.Storerkey, RP.Sku, RP.ToLoc

    /*
    SELECT RP.Storerkey, RP.Sku, RP.ToLoc, SUM(RP.Qty) AS Qty
    INTO #TMP_REP
    FROM TASKDETAIL RP (NOLOCK) 
    JOIN #TMP_WAVEREP WL ON RP.Storerkey = WL.Storerkey AND RP.Sku = WL.Sku AND RP.ToLoc = WL.Loc
    WHERE RP.Status = '0'
    AND RP.TaskType = 'RPF'
    AND RP.qty > 0 
    GROUP BY RP.Storerkey, RP.Sku, RP.ToLoc        
    */
                
    SELECT @c_Wavekey AS Wavekey, LLI.Storerkey, LLI.Sku, LLI.Loc, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + ISNULL(TR.Qty,0) AS ShortReplQty
    FROM LOTXLOCXID LLI (NOLOCK)
    JOIN #TMP_WAVEREP WL ON LLI.Storerkey = WL.Storerkey AND LLI.Sku = WL.Sku AND LLI.Loc = WL.Loc
    LEFT JOIN #TMP_REP TR ON LLI.Storerkey = TR.Storerkey AND LLI.Sku = TR.Sku AND LLI.Loc = TR.ToLoc
    WHERE (LLI.Qty > 0 OR LLI.QtyExpected > 0)
    GROUP BY LLI.Storerkey, LLI.Sku, LLI.Loc, ISNULL(TR.Qty,0)
    HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) + ISNULL(TR.Qty,0) < 0  
    ORDER BY LLI.Sku, LLI.Loc
END --sp end

GO