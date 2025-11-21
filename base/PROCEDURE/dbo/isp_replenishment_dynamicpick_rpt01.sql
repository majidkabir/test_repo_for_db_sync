SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_REPLENISHMENT_dynamicpick_rpt01                 */
/* Creation Date: 2018-04-30                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4551 - KR - UA Replenishment Report                      */
/*                                                                       */
/* Called By: r_REPLENISHMENT_dynamicpick_rpt01                          */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_REPLENISHMENT_dynamicpick_rpt01]
         (  @c_wavekey           NVARCHAR(20)     
         )
                 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_NoOfLine  INT
          ,@c_getUDF01  NVARCHAR(30)
          ,@c_PrvUDF01  NVARCHAR(30)
          ,@n_CtnUDF01  INT
          ,@n_ctnsct    INT
          ,@n_Ctnsmct   INT
          ,@n_rpqty     INT
   
   
   SET @n_CtnUDF01 = 1
   SET @c_PrvUDF01 = ''
   
   CREATE TABLE #TEMRPLDYP01(
   WaveKey       NVARCHAR(20),
   ReplenNo      NVARCHAR(20),
   PutAZone      NVARCHAR(20),
   RPFromLoc     NVARCHAR(10),
   SKU           NVARCHAR(20),
   RPToLoc       NVARCHAR(20),
   Lottable11    NVARCHAR(30),
   RPQty         INT,
   TTLCTN        INT,
   FCPQTY        INT,
   FCSQTY        INT,
   RPLQTY        INT
   )
   
   
  -- SET @n_NoOfLine = 40
  
 DECLARE  @c_getwvkey          NVARCHAR(20),
		    @c_repno             NVARCHAR(20),
		    @n_TTLCTN            INT,
		    @n_fcpqty            INT,
		    @n_fcsqty            INT,
		    @n_rplqty            INT,
		    @c_SSM               NVARCHAR(10),
		    @n_qtyExp            INT
   
   
   INSERT INTO #TEMRPLDYP01
   (  WaveKey ,
		ReplenNo,
		PutAZone,
		RPFromLoc,
		SKU,
		RPToLoc,
		Lottable11,
		RPQty,
		TTLCTN,
		FCPQTY,
		FCSQTY,
		RPLQTY
   )
   
    SELECT WV.WaveKey,RP.ReplenNo,loc.PutawayZone,RP.FromLoc,RP.Sku,RP.ToLoc,la.Lottable11,RP.Qty,0,0,0,0
    FROM WAVE WV (NOLOCK) 
    JOIN REPLENISHMENT RP (NOLOCK) ON WV.Wavekey = RP.Wavekey 
    JOIN SKU (NOLOCK) ON RP.Storerkey = SKU.Storerkey AND RP.Sku = SKU.Sku 
    JOIN LOTATTRIBUTE LA (NOLOCK) ON RP.Lot = LA.Lot 
    JOIN LOC (NOLOCK) ON RP.FromLoc = LOC.Loc 
    WHERE WV.wavekey=@c_wavekey
    ORDER BY WV.WaveKey DESC
             
             
      SET @n_fcpqty = 0
   	SET @n_fcsqty = 0
   	SET @n_rplqty = 0
   	SET @n_TTLCTN = 1         
          
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT t.wavekey,t.ReplenNo,t.rpqty   
   FROM #TEMRPLDYP01 AS t
   WHERE t.wavekey = @c_wavekey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getwvkey,@c_repno,@n_rpqty    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN        
   	
   	
		
	    SELECT @n_ttlctn = COUNT(1)
	    FROM #TEMRPLDYP01 AS t
	    WHERE t.WaveKey= @c_getwvkey
	    
	  --  SELECT @c_repno '@c_repno',@n_rpqty '@n_rpqty',@n_fcpqty '@n_fcpqty',@n_fcsqty '@n_fcsqty',@n_rplqty '@n_rplqty'
	    
	    IF @c_repno = 'FCP'
	    BEGIN
	    	SET @n_fcpqty = @n_fcpqty + @n_rpqty
	    END
	    ELSE IF @c_repno = 'FCS'
	    BEGIN
	    	SET @n_fcsqty = @n_fcsqty + @n_rpqty
	    END
	    ELSE IF @c_repno = 'RPL' 
	    BEGIN
	    	SET @n_rplqty = @n_rplqty + @n_rpqty 	
	    END
		
   
   FETCH NEXT FROM CUR_RESULT INTO  @c_getwvkey,@c_repno,@n_rpqty    
   END   

   UPDATE #TEMRPLDYP01
   SET
       FCPQTY = @n_fcpqty
   	,FCSQTY = @n_fcsqty
   	,RPLQTY = @n_rplqty
   	,TTLCTN = @n_TTLCTN
   WHERE wavekey = @c_wavekey
   
   SELECT  *
   FROM #TEMRPLDYP01 AS t
   ORDER BY t.wavekey,RPFromLoc,sku
   
    QUIT_SP:
    
END


GO