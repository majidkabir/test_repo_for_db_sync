SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_fullcasepick_rpt                                   */
/* Creation Date:   05/7/2008                                           */
/* Copyright: IDS                                                       */
/* Written by:     TING TUCK LUNG                                       */
/*                                                                      */
/* Purpose:   SOS 84256 - Sorting Sheet For CN 				          		*/
/*               - For Full Case Picks By Sku                           */
/*                                                                      */
/* Input Parameters: facility, loadkeystart, loadkeyend, stopstart      */
/*                   , stopend                                          */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:  It has 2 section. same set of data. 2 grouping               */
/*       - this created due to PB problem in autosize height            */
/*       - data get hide at the last row in a page                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:     report						                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 06-08-2008   Vanessa       SOS#112457 Add a sequence number combined */
/*                            with loadkey                -- (Vanessa01)*/
/* 22-12-2008   NJOW     1.2  SOS#124058 Remove a sequence number       */
/*                            combined with loadkey (NJOW01)            */
/************************************************************************/

CREATE PROC [dbo].[isp_fullcasepick_rpt] 
(      @c_facility        NVARCHAR(10),
       @c_loadkeystart    NVARCHAR(10),
       @c_loadkeyend      NVARCHAR(10),
       @c_stopstart       NVARCHAR(10),
       @c_stopend         NVARCHAR(10)  )        
AS        
BEGIN     
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        
   /*******************************************************************************/        
   /* 17-Aug-2004 YTWan FBR Pieces Picking Slip By Load          */        
   /*******************************************************************************/        
  SET NOCOUNT ON        
  DECLARE      @c_Putawayzone     NVARCHAR(10),  
               @c_Sku             NVARCHAR(20), 
               @c_LoadKey         NVARCHAR(10), 
	--		   @n_id              int,  -- (Vanessa01)  --NJOW01
               @c_Packkey         NVARCHAR(10),
               @n_PickQtyInCnt    int,
      		   @c_Lottable02      NVARCHAR(10),
               @c_TPutawayzone    NVARCHAR(10),        
               @c_TSku            NVARCHAR(20),
               @n_SKU_Tot_Qty     int,         
               @n_PAZ_Tot_Qty     int,
               @n_Grand_Tot_Qty   int,
               @n_Addcnt          int,  
               @n_cnt             int,
               @c_TLoadKey        NVARCHAR(10), 
               @c_LoadKey2        NVARCHAR(10),   
               @n_qty             int,
               @n_Tot_qty         int,
               @n_StartTranCnt    int,
               @n_err             int,        
               @n_continue        int,        
               @b_success         int,        
               @c_errmsg          NVARCHAR(255)
      
   Declare @c_debug  NVARCHAR(1)      
   , @c_PrintedFlag  NVARCHAR(1)      
      
   SET @c_debug = '0'      
      
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1        
        
   /* Start Modification */        
 -- @n_continue = 1 or @n_continue = 2       

   DECLARE @ShowResult 
      TABLE(Putawayzone   NVARCHAR(10),
           Line          NVARCHAR(100),
           LineFlag      NVARCHAR(2),  
           rowid         int  IDENTITY (1,1) ) 
   -- (Vanessa01)  --NJOW01
 --  CREATE TABLE #AutoLoad ( 
--	  [id] [int] IDENTITY (1, 1) NOT NULL ,
--      [loadkey] [varchar] (10)  NULL,
--   ) ON [PRIMARY] -- (Vanessa01)

   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      SELECT L.Putawayzone,
              PD.Sku, 
              LP.LoadKey, 
              P.Packkey,
              CAST(SUM(PD.Qty) / P.CaseCnt AS Int) PickQtyInCnt,
      		  LA.Lottable02,
      		  StopStart = CONVERT(NVARCHAR(10), @c_stopstart),
      		  StopEnd = CONVERT(NVARCHAR(10), @c_stopend)
      INTO #Result1
      FROM PICKDETAIL PD WITH (NOLOCK)
      			JOIN LOADPLANDETAIL LPD WITH (NOLOCK) 	ON  ( LPD.Orderkey = PD.Orderkey )
      			JOIN LOADPLAN LP WITH (NOLOCK)       	ON  ( LPD.Loadkey  = LP.Loadkey ) 
      			JOIN SKUxLOC SL WITH (NOLOCK) 			ON  ( PD.Storerkey = SL.Storerkey )
      																AND ( PD.Sku       = SL.Sku )
      																AND ( PD.Loc       = SL.Loc )
      			JOIN LOC L WITH (NOLOCK)               ON  ( SL.LOC       = L.LOC)
      			JOIN SKU S WITH (NOLOCK) 					ON  ( PD.Storerkey = S.Storerkey ) 
      																AND ( PD.Sku       = S.Sku )
      			JOIN PACK P WITH (NOLOCK) 					ON  ( S.Packkey    = P.Packkey ) 
      			JOIN LOTATTRIBUTE LA WITH (NOLOCK)     ON  ( PD.LOT       = LA.LOT )
      			JOIN ORDERS WITH (NOLOCK) 				   ON  ( PD.OrderKey  = ORDERS.OrderKey )
      WHERE LP.LoadKey >= @c_loadkeystart
      AND   LP.LoadKey <= @c_loadkeyend
      AND   LP.Facility = @c_facility
      AND   SL.LocationType <> 'CASE'
      AND   SL.LocationType <> 'PICK'
      AND   PD.Status < '5'
      AND	Orders.Stop BETWEEN @c_stopstart AND @c_stopend
--      AND   L.Putawayzone = @c_Putawayzone
      GROUP BY L.Putawayzone, PD.Sku,  LP.LoadKey, P.Packkey, P.CaseCnt, LA.Lottable02
      HAVING CAST(SUM(PD.Qty) / P.CaseCnt AS Int) > 0
      	ORDER BY L.Putawayzone, PD.Sku, LP.LoadKey	

      CREATE UNIQUE CLUSTERED INDEX IX_1 on #Result1 (Putawayzone, LoadKey, Sku, Lottable02)
      CREATE NONCLUSTERED INDEX IX_2 on #Result1 (Putawayzone, LoadKey)
      CREATE nonCLUSTERED INDEX IX_3 on #Result1 (Putawayzone, Sku)
   END

   IF @c_debug = '1'
   BEGIN
      SELECT * from #Result1
   END

   SET ROWCOUNT 1   
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      SET @c_Putawayzone = ''
      SET @n_Grand_Tot_Qty = 0

      While 1=1
      BEGIN
         SET @c_TPutawayzone = ''
         SELECT @c_TPutawayzone = MIN(Putawayzone)
         FROM #Result1 WITH (NOLOCK)  
         WHERE Putawayzone > @c_Putawayzone

         IF ISNULL(RTRIM(@c_TPutawayzone), '') = '' 
         BEGIN
            Break
         END

         SET @c_Putawayzone = @c_TPutawayzone
         SET @n_PAZ_Tot_Qty = 0

         SET @c_sku = ''
         While 1=1
         BEGIN
            SET @c_Tsku = ''
            SELECT @c_Tsku = Min(Sku)
            FROM #Result1 WITH (NOLOCK)  
            WHERE Putawayzone = @c_Putawayzone
            AND Sku > @c_sku
   
            IF ISNULL(RTRIM(@c_Tsku), '') = '' 
            BEGIN
               Break
            END

            SET @n_SKU_Tot_Qty = 0
            SET @c_sku = @c_Tsku

            SET ROWCOUNT 0

            -- (Vanessa01) NJOW01
	--		INSERT INTO #AutoLoad
	--		SELECT DISTINCT R1.LoadKey
	--		   FROM #Result1 R1 WITH (NOLOCK) 
	--		   WHERE  R1.Putawayzone = @c_Putawayzone
	--		   AND    R1.Sku = @c_sku
	--		   AND    R1.LoadKey NOT IN 
	--		   (SELECT AL.LoadKey
	--		   FROM #AutoLoad AL WITH (NOLOCK))	 
	--		   ORDER BY R1.LoadKey 

	--	    IF @c_debug = '1'
	--	    BEGIN
	--		   SELECT * from #AutoLoad
	--	    END

			SELECT @n_err = @@ERROR      
			IF @n_err <> 0       
			BEGIN      
			   SELECT @n_continue = 3      
			   SELECT @n_err = 63501      
			   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT fullcasepick_rpt_result Failed. (isp_fullcasepick_rpt2)'      
			   BREAK    
			END 

            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            SELECT R1.Putawayzone,
                  Convert(Nchar(20), SUBSTRING(R1.sku ,1, 6) + '-' +  
                   SUBSTRING(R1.sku ,7, 3) + '-' + SUBSTRING(R1.sku ,10, 5) ) +
                   Space(1)  +      -- column buffer
                   CONVERT(Nchar(15), R1.Lottable02) +
                   Space(0+3)  +   --NJOW01
--                   CONVERT(char(3), AL.id)  --NJOW01
--				   + '- ' +  --NJOW
                   CONVERT(Nchar(10), R1.LoadKey) +
                   Space(2+1)  +      --NJOW01
                   CONVERT(Nchar(5), R1.PickQtyInCnt) +
                   Space(0)  +  
                   CONVERT(Nchar(5), Replicate('_', 5))    +  
                   Space(1)  +  
                   CONVERT(Nchar(10), R1.Packkey) ,
                     'L1' 
               FROM #Result1 R1 WITH (NOLOCK)  
--               JOIN #AutoLoad AL WITH (NOLOCK)       	ON  ( R1.Loadkey  = AL.Loadkey )  --NJOW01
               WHERE  R1.Putawayzone = @c_Putawayzone
               AND    R1.Sku = @c_sku
               ORDER BY R1.LoadKey   -- (Vanessa01) 

               SELECT @n_err = @@ERROR      
               IF @n_err <> 0       
               BEGIN      
                SELECT @n_continue = 3      
                SELECT @n_err = 63501      
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT fullcasepick_rpt_result Failed. (isp_fullcasepick_rpt2)'      
                BREAK    
               END  
               SET ROWCOUNT 1

               SELECT @n_SKU_Tot_Qty = SUM(PickQtyInCnt)
               FROM #Result1 WITH (NOLOCK)  
               WHERE  Putawayzone = @c_Putawayzone
               AND    Sku = @c_sku

            -- Total for PutawayZone
            SELECT @n_PAZ_Tot_Qty = @n_PAZ_Tot_Qty + @n_SKU_Tot_Qty

            -- Insert Line for Subttotal Line for Sku 
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone,  
                   Convert(char(20), '' ) +
                   Space(1)  +      -- column buffer
                   CONVERT(char(16), '') +  -- (Vanessa01)
--                Space(3)  +      
                CONVERT(char(13), 'SKU SubTotal:') +
                   Space(3-1)  +      --NJOW01
                   CONVERT(char(10), @n_SKU_Tot_Qty) +
                   Space(1)  +      
                   CONVERT(char(10), '') ,
                     'S1' )   -- Sub total
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
             SELECT @n_continue = 3      
             SELECT @n_err = 63505      
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
             BREAK    
            END  
            
         END --  1=1 SKu
         -- Grand total
         SELECT @n_Grand_Tot_Qty = @n_Grand_Tot_Qty + @n_PAZ_Tot_Qty 

         -- Insert Line for Subttotal Line for PutawayZone 
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone,  
                Convert(char(20), '' ) +
                Space(1)  +      -- column buffer
--                CONVERT(char(18, '') +
--                Space(3)  +      
                CONVERT(char(7), '') +
                CONVERT(char(21), 'PutawayZone SubTotal:') +
                Space(3)  +      
                CONVERT(char(10), @n_PAZ_Tot_Qty) +
                Space(1)  +      
                CONVERT(char(10), '') ,
                  'S1' )  -- Sub total
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @n_err = 63510      
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
            BREAK    
         END  

         SET @n_cnt = 0
         While @n_cnt < 2
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone,  
                   Convert(char(1), '' ) ,   -- as blank line
                     '' )     -- Grant total
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
             SELECT @n_continue = 3      
             SELECT @n_err = 63515      
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
             BREAK    
            END  
            SET @n_cnt = @n_cnt + 1
         END

         -- Insert Line for "Summary By PutawayZone"
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone,  
                Convert(char(30), 'Summary By PutawayZone' ) ,   -- Section 2 title
                  'L2' )     -- Grant total
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 63520      
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
          BREAK    
         END  

         -- Insert Line for Label Line - Section 2
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone,  
                Convert(char(11), 'Load Plan #' ) +   -- Section 2 Label Line
                Space(25)  +  
                Convert(char(15), 'Total Case Qty' ) ,   -- Section 2 Label Line
                  'L2' )     -- Grant total
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 63525      
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
          BREAK    
         END  

         SET @c_LoadKey2 = ''
         SET @n_Tot_qty = 0
         -- Section 2 - Summary by Load Key
         While (1=1)
         BEGIN
            SET @c_TLoadKey = ''
            SELECT @c_TLoadKey = MIN(LoadKey)
            FROM #Result1  
            WHERE Putawayzone = @c_Putawayzone
            AND Loadkey > @c_LoadKey2
   
            IF ISNULL(RTRIM(@c_TLoadKey), '') = '' 
            BEGIN
               Break
            END
            SET @c_LoadKey2 = @c_TLoadKey

			-- (Vanessa01) NJOW01
			--SELECT @n_id = id
			--FROM #AutoLoad 
			--WHERE loadkey = @c_LoadKey2  -- (Vanessa01)

            SELECT @n_qty = SUM(PickQtyInCnt)
            FROM #Result1
            WHERE Putawayzone = @c_Putawayzone
            AND  LoadKey = @c_LoadKey2

            SET @n_Tot_qty = @n_Tot_qty + @n_qty      

            -- Insert Line for data Line - Section 2
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone,  
--                   CONVERT(char(3), @n_id) -- (Vanessa01) NJOW01
--				   + '- ' +                -- (Vanessa01) NJOW01
                   Convert(Nchar(11), @c_LoadKey2 ) +   
                   Space(26+4)  +  --NJOW01
                   Convert(Nchar(15), @n_qty ) ,  
                     'L2' )     
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
             SELECT @n_continue = 3      
             SELECT @n_err = 63530      
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
             BREAK    
            END  
         END   -- 1=1 - Load key

         -- Insert total Line - Section 2
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone,  
                Convert(char(15), '' ) +   -- (Vanessa01)
                Space(26)  +			   -- (Vanessa01)
                Convert(char(15), @n_Tot_qty ) ,   
                  'S2' )     
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 63530      
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
          BREAK    
         END  

         SET @n_cnt = 0
         While @n_cnt < 2
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone,  
                   Convert(char(1), '' ) ,   -- as blank line
                     '' )     -- Grant total
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
             SELECT @n_continue = 3      
             SELECT @n_err = 63545      
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
             BREAK    
            END  
            SET @n_cnt = @n_cnt + 1
         END

      END  -- 1=1 Putawayzone  

      IF Exists ( SELECT 1 from @ShowResult )
      BEGIN
         -- Insert Line for Grand total 
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone,  
                Convert(char(20), '' ) +
                Space(5)  +      -- column buffer
--                CONVERT(char(18, '') +
--                Space(3)  +      
                CONVERT(char(6), '') +
                CONVERT(char(16), 'Grand SubTotal:') +
                Space(5)  +      
                CONVERT(char(10), @n_Grand_Tot_Qty) +
                Space(1)  +      
                CONVERT(char(10), '') ,
                  'G1' )     -- Grant total
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
          SELECT @n_continue = 3      
          SELECT @n_err = 63550      
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
         END 

         SET @n_cnt = 0
         While @n_cnt < 1
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone,  
                   Convert(char(1), '' ) ,   -- as blank line
                     '' )     -- Grant total
            SELECT @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
             SELECT @n_continue = 3      
             SELECT @n_err = 63555      
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
            END  
            SET @n_cnt = @n_cnt + 1
         END
 
      END
   END      
   SET ROWCOUNT 0

   DROP TABLE  #Result1  

    -- (Vanessa01)
	-- Insert Line for "Summary By Load Plan No"
	INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
	VALUES (CONVERT(char(1),' '),  
		    Convert(char(30), 'Summary By Load Plan No' ) ,   -- Section 3 title
		    CONVERT(char(1),' '))     -- Grant total
	SELECT @n_err = @@ERROR      
	IF @n_err <> 0       
	BEGIN      
		SELECT @n_continue = 3      
		SELECT @n_err = 63556      
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'      
	END  

	-- Insert Line for Label Line - Section 3
	INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
	VALUES (CONVERT(char(1),' '),  
		Convert(char(11), 'Load Plan #' ) +   -- Section 3 Label Line
		Space(25) +  
		Convert(char(15), 'Total Case Qty' ), CONVERT(char(1),' ') )     -- Grant total
	SELECT @n_err = @@ERROR      
	IF @n_err <> 0       
	BEGIN      
		SELECT @n_continue = 3      
		SELECT @n_err = 63557      
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'       
	END  

	SELECT LP.LoadKey, 
		  CAST(SUM(PD.Qty) / P.CaseCnt AS Int) PickQtyInCnt,
		  StopStart = CONVERT(NVARCHAR(10), ISNULL(RTRIM(@c_loadkeystart),'')),
		  StopEnd = CONVERT(NVARCHAR(10), ISNULL(RTRIM(@c_loadkeyend),''))
    INTO #RESUlT2
	FROM PICKDETAIL PD WITH (NOLOCK)
			JOIN LOADPLANDETAIL LPD WITH (NOLOCK) 	ON  ( LPD.Orderkey = PD.Orderkey )
			JOIN LOADPLAN LP WITH (NOLOCK)       	ON  ( LPD.Loadkey  = LP.Loadkey )
			JOIN SKUxLOC SL WITH (NOLOCK) 			ON  ( PD.Storerkey = SL.Storerkey )
																AND ( PD.Sku       = SL.Sku )
																AND ( PD.Loc       = SL.Loc )
			JOIN SKU S WITH (NOLOCK) 					ON  ( PD.Storerkey = S.Storerkey )
																AND ( PD.Sku       = S.Sku )
			JOIN PACK P WITH (NOLOCK) 					ON  ( S.Packkey    = P.Packkey )
			JOIN ORDERS WITH (NOLOCK) 				   ON  ( PD.OrderKey  = ORDERS.OrderKey )
	WHERE LP.LoadKey >= ISNULL(RTRIM(@c_loadkeystart),'')
	AND   LP.LoadKey <= ISNULL(RTRIM(@c_loadkeyend),'')
	AND   LP.Facility = ISNULL(RTRIM(@c_facility),'')
	AND   SL.LocationType <> 'CASE'
	AND   SL.LocationType <> 'PICK'
	AND   PD.Status < '5'
	AND	Orders.Stop BETWEEN ISNULL(RTRIM(@c_stopstart),'') AND ISNULL(RTRIM(@c_stopend),'')
	GROUP BY LP.LoadKey, PD.Sku, P.CaseCnt
	HAVING CAST(SUM(PD.Qty) / P.CaseCnt AS Int) > 0
	ORDER BY LP.LoadKey

	INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag) 
--    SELECT CONVERT(char(1),''),CONVERT(char(3),AL.id) + CONVERT(char(3),' - ') + CONVERT(char(11),R2.LoadKey) + SPACE(26) + CONVERT(char(10),SUM(R2.PickQtyInCnt)),CONVERT(char(1),'') --NJOW01
    SELECT CONVERT(NVARCHAR(1),''),CONVERT(Nchar(11),R2.LoadKey) + SPACE(26+6) + CONVERT(Nchar(10),SUM(R2.PickQtyInCnt)),CONVERT(char(1),'') --NJOW01
    FROM #RESUlT2 R2 WITH (NOLOCK)  
--    JOIN #AutoLoad AL WITH (NOLOCK)  ON  ( R2.Loadkey  = AL.Loadkey ) --NJOW01
--	GROUP BY AL.id ,R2.LoadKey  --NJOW01
	GROUP BY R2.LoadKey --NJOW
	ORDER BY R2.LoadKey
	SELECT @n_err = @@ERROR      
	IF @n_err <> 0       
	BEGIN      
		SELECT @n_continue = 3      
		SELECT @n_err = 63558      
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_rpt)'        
	END  -- (Vanessa01)

   SELECT Putawayzone,
               Line,
               LineFlag   
   FROM @ShowResult     
   ORder by rowid   

--   DROP TABLE  #AutoLoad   -- (Vanessa01) NJOW01
   DROP TABLE  #RESUlT2	   -- (Vanessa01)
        
   IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN        
    execute nsp_logerror @n_err, @c_errmsg, 'isp_fullcasepick_rpt'        
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
    RETURN        
   END        
   ELSE        
   BEGIN        
   SELECT @b_success = 1        
   WHILE @@TRANCOUNT > @n_StartTranCnt        
   BEGIN        
      COMMIT TRAN        
   END        
   RETURN        
   END        
END /* main procedure */        
        

GO