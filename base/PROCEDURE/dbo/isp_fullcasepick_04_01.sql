SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_fullcasepick_04_01                                 */
/* Creation Date: 08-Aug-2011                                           */
/* Copyright: IDS                                                       */
/* Written by:YTWan                                                     */
/*                                                                      */
/* Purpose: SOS#238068 - Sorting Sheet For WE CN                        */
/*        : Copy & Modified from isp_fullcasepick_rpt03_01              */
/*                                                                      */
/* Input Parameters: facility, loadkeystart, loadkeyend, stopstart      */
/*                 , stopend                                            */
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
/* Called By: r_dw_fullcasepick_sortsheet_bysku04_1                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_fullcasepick_04_01] 
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
        
   DECLARE @n_StartTranCnt    INT  
         , @n_continue        INT 
         , @n_err             INT         
         , @b_success         INT         
         , @c_errmsg          NVARCHAR(255)
         , @c_debug           NVARCHAR(1) 
     
   DECLARE @c_Putawayzone     NVARCHAR(10)   
         , @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(10)
         , @c_Measurement     NVARCHAR(5) 
         , @c_Size            NVARCHAR(5) 
         , @c_ExternOrderkey  NVARCHAR(20)  

         , @n_cnt             INT  
         , @n_SKU_Tot_Qty     INT          
         , @n_PAZ_Tot_Qty     INT  
         , @n_Grand_Tot_Qty   INT  
         , @n_qty             INT  
         , @n_Tot_qty         INT  
      
   SET @n_StartTranCnt  = @@TRANCOUNT
   SET @n_continue      = 1  
   SET @n_err           = 0 
   SET @b_success       = 0
   SET @c_errmsg        = ''
   SET @c_debug         = '0'   

   SET @c_Putawayzone   = ''
   SET @c_Style         = ''
   SET @c_Color         = ''
   SET @c_Measurement   = ''
   SET @c_Size          = ''
   SET @c_ExternOrderkey= '' 
        
   SET @n_cnt           = 0
   SET @n_SKU_Tot_Qty   = 0
   SET @n_PAZ_Tot_Qty   = 0
   SET @n_Grand_Tot_Qty = 0
   SET @n_qty           = 0
   SET @n_Tot_qty       = 0
   /* Start Modification */        

   DECLARE @ShowResult 
      TABLE(Putawayzone   NVARCHAR(10) 
           ,Line          NVARCHAR(255) 
           ,LineFlag      NVARCHAR(2)   
           ,rowid         INT  IDENTITY (1,1) ) 

   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      SELECT ISNULL(RTRIM(L.Putawayzone),'')                            AS Putawayzone
            ,ISNULL(RTRIM(S.Style),'')                                  AS Style
            ,ISNULL(RTRIM(S.Color),'')                                  AS Color
            ,ISNULL(RTRIM(S.Measurement),'')                            AS Measurement
            ,ISNULL(RTRIM(S.Size),'')                                   AS [Size]
            ,ISNULL(RTRIM(OH.ExternOrderkey),'')                        AS ExternOrderkey   
            ,ISNULL(RTRIM(P.Packkey),'')                                AS Packkey 
            ,CAST(ISNULL(SUM(PD.Qty),0) / ISNULL(P.CaseCnt,0) AS Int)   AS PickQtyInCnt 
      INTO #Result1
      FROM PICKDETAIL PD      WITH (NOLOCK)
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK)  ON  ( LPD.Orderkey = PD.Orderkey )
      JOIN LOADPLAN LP        WITH (NOLOCK)  ON  ( LPD.Loadkey  = LP.Loadkey ) 
      JOIN SKUxLOC SL         WITH (NOLOCK)  ON  ( PD.Storerkey = SL.Storerkey )
                                             AND ( PD.Sku       = SL.Sku )
                                             AND ( PD.Loc       = SL.Loc )
      JOIN LOC L              WITH (NOLOCK)  ON  ( SL.LOC       = L.LOC)
      JOIN SKU S              WITH (NOLOCK)  ON  ( PD.Storerkey = S.Storerkey ) 
                                             AND ( PD.Sku       = S.Sku )
      JOIN PACK P             WITH (NOLOCK)  ON  ( S.Packkey    = P.Packkey ) 
      JOIN LOTATTRIBUTE LA WITH (NOLOCK)     ON  ( PD.LOT       = LA.LOT )
      JOIN ORDERS OH WITH (NOLOCK)           ON  ( PD.OrderKey  = OH.OrderKey )
      WHERE LP.LoadKey >= @c_loadkeystart
      AND   LP.LoadKey <= @c_loadkeyend
      AND   LP.Facility = @c_facility
      AND   SL.LocationType <> 'CASE'
      AND   SL.LocationType <> 'PICK'
      AND   PD.Status < '5'
      AND   OH.Stop BETWEEN @c_stopstart AND @c_stopend
      GROUP BY ISNULL(RTRIM(L.Putawayzone),'')        
            ,  ISNULL(RTRIM(S.Style),'')                                   
            ,  ISNULL(RTRIM(S.Color),'') 
            ,  ISNULL(RTRIM(S.Measurement),'')                                 
            ,  ISNULL(RTRIM(S.Size),'')             
            ,  ISNULL(RTRIM(OH.ExternOrderkey),'')    
            ,  ISNULL(RTRIM(P.Packkey),'')            
            ,  ISNULL(P.CaseCnt,0)
      HAVING CAST(ISNULL(SUM(PD.Qty),0) / ISNULL(P.CaseCnt,0) AS Int) > 0
      ORDER BY ISNULL(RTRIM(L.Putawayzone),'')      
            ,  ISNULL(RTRIM(S.Style),'')                                   
            ,  ISNULL(RTRIM(S.Color),'') 
            ,  ISNULL(RTRIM(S.Measurement),'')                                  
            ,  ISNULL(RTRIM(S.Size),'')            
            ,  ISNULL(RTRIM(OH.ExternOrderkey),'')  
      
      CREATE NONCLUSTERED INDEX IX_1 on #Result1 (Putawayzone, ExternOrderkey, Style, Color, Measurement, [Size])
      CREATE NONCLUSTERED INDEX IX_2 on #Result1 (Putawayzone, ExternOrderkey)
      CREATE nonCLUSTERED INDEX IX_3 on #Result1 (Putawayzone, Style, Color, Measurement, [Size])
   END

   IF @c_debug = '1'
   BEGIN
      SELECT * from #Result1
   END

   --SET ROWCOUNT 1   
   IF @n_continue = 1 or @n_continue = 2        
   BEGIN        
      SET @c_Putawayzone = ''
      SET @n_Grand_Tot_Qty = 0

      DECLARE CURSOR_PAGRP CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Putawayzone
        FROM #Result1
  
      OPEN CURSOR_PAGRP

      FETCH NEXT FROM CURSOR_PAGRP INTO @c_Putawayzone

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_PAZ_Tot_Qty = 0
         DECLARE CURSOR_SKUGRP CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT Style
               ,Color
               ,Measurement
               ,Size
           FROM #Result1
          WHERE PutawayZone = @c_Putawayzone
          ORDER BY Style
                  ,Color
                  ,Measurement
                  ,Size

         OPEN CURSOR_SKUGRP

         FETCH NEXT FROM CURSOR_SKUGRP INTO @c_Style
                                          , @c_Color
                                          , @c_Measurement
                                          , @c_Size

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            SELECT Putawayzone 
                 , CONVERT(NCHAR(15), Style)   
                 + SPACE(1) 
                 + CONVERT(NCHAR(10), Color)  
                 + SPACE(1) 
                 + CONVERT(NCHAR(5),  Measurement) 
                 + SPACE(7) 
                 + CONVERT(NCHAR(5),  Size) 
                 + SPACE(1)         
                 + CONVERT(NCHAR(24), ExternOrderkey) 
                 + SPACE(1) 
                 + RIGHT(REPLICATE(' ',10) + CONVERT(NVARCHAR(10), PickQtyInCnt),5)       
                 + SPACE(1)    
                 + CONVERT(NCHAR(5),  Replicate('_', 5))     
                 + SPACE(1)    
                 + CONVERT(NCHAR(10), Packkey) 
                 , 'L1' 
             FROM #Result1
            WHERE PutawayZone = @c_Putawayzone
              AND Style = @c_Style
              AND Color = @c_Color
              AND Measurement = @c_Measurement
              AND Size  = @c_Size
            ORDER BY ExternOrderkey

            SET @n_err = @@ERROR      

            IF @n_err <> 0       
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 63501      
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT fullcasepick_rpt_result Failed. (isp_fullcasepick_04_012)'      
               GOTO QUIT    
            END  

            SET @n_SKU_Tot_Qty = 0
            SELECT @n_SKU_Tot_Qty = ISNULL(SUM(PickQtyInCnt),0)
              FROM #Result1 WITH (NOLOCK)  
             WHERE  Putawayzone = @c_Putawayzone
               AND  Style = @c_Style
               AND  Color = @c_Color
               AND  Measurement = @c_Measurement
               AND  Size  = @c_Size

            -- Total for PutawayZone
            SET @n_PAZ_Tot_Qty = @n_PAZ_Tot_Qty + @n_SKU_Tot_Qty

            -- Insert Line for Subttotal Line for Sku 
            INSERT INTO @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES   ( @c_Putawayzone   
                     , CONVERT(CHAR(39), '' )  
                     + RIGHT(REPLICATE(' ',25) + 'SKU SubTotal:',25) 
                     + SPACE(1)       
                     + RIGHT(REPLICATE(' ',10) + CONVERT(VARCHAR(10), @n_SKU_Tot_Qty),10)  
                     , 'S1' ) 
                    
            SET @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @n_err = 63505      
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
               GOTO QUIT    
            END  

            FETCH NEXT FROM CURSOR_SKUGRP INTO @c_Style
                                             , @c_Color
                                             , @c_Measurement
                                             , @c_Size
         END --  WHILE CURSOR_SKUGRP
         CLOSE CURSOR_SKUGRP
         DEALLOCATE CURSOR_SKUGRP

         -- Grand total
         SET @n_Grand_Tot_Qty = @n_Grand_Tot_Qty + @n_PAZ_Tot_Qty 

         -- Insert Line for Subttotal Line for PutawayZone 
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES (@c_Putawayzone  
                , CONVERT(CHAR(39), '' )  
                + RIGHT(REPLICATE(' ',25) + 'PutawayZone SubTotal:',25) 
                + SPACE(1)      
                +  RIGHT(REPLICATE(' ',10) + CONVERT(VARCHAR(10), @n_PAZ_Tot_Qty),10)   
                , 'S1' )                                             -- Sub total

         SET @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 63510      
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
            GOTO QUIT    
         END  

         SET @n_cnt = 0
         While @n_cnt < 2
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone  
                   ,SPACE(1)                                         -- as blank line
                   ,'' )                                             -- Grant total
                     
            SET @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 63515      
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
               GOTO QUIT    
            END  
            SET @n_cnt = @n_cnt + 1
         END

         -- Insert Line for "Summary By PutawayZone"
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES ( @c_Putawayzone  
                , CONVERT(CHAR(30), 'Summary By PutawayZone' )       -- Section 2 title
                , 'L2' )                                             -- Grant total
                
         SET @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 63520      
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
            GOTO QUIT    
         END  

         -- Insert Line for Label Line - Section 2
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES ( @c_Putawayzone   
                , CONVERT(CHAR(20), 'ExternOrderkey')                -- Section 2 Label Line
                + SPACE(10)   
                + RIGHT(REPLICATE(' ',15)+ 'Total Case Qty',15)      -- Section 2 Label Line
                , 'L2' )     -- Grant total
                
         SET @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 63525      
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
            GOTO QUIT    
         END  

         SET @n_Tot_qty = 0
         -- Section 2 - Summary by Load Key

         DECLARE CURSOR_SOGRP CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT ExternOrderkey
           FROM #Result1
          WHERE PutawayZone = @c_Putawayzone
          ORDER BY ExternOrderkey
     
         OPEN CURSOR_SOGRP

         FETCH NEXT FROM CURSOR_SOGRP INTO @c_ExternOrderkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_qty = 0
            SELECT @n_qty = ISNULL(SUM(PickQtyInCnt),0)
            FROM #Result1
            WHERE Putawayzone = @c_Putawayzone
            AND  ExternOrderKey = @c_ExternOrderkey

            SET @n_Tot_qty = @n_Tot_qty + @n_qty      

            -- Insert Line for data Line - Section 2
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES ( @c_Putawayzone   
                   , CONVERT(NCHAR(20), @c_ExternOrderkey )    
                   + SPACE(10)   
                   + RIGHT(REPLICATE(' ',15)+ CONVERT(VARCHAR(15), @n_qty),15) 
                   , 'L2' ) 
                       
            SET @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 63530      
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
               GOTO QUIT    
            END 
            FETCH NEXT FROM CURSOR_SOGRP INTO @c_ExternOrderkey 
         END  --WHILE DISTINCT ExternOrderkey
         CLOSE CURSOR_SOGRP 
         DEALLOCATE CURSOR_SOGRP

         -- Insert total Line - Section 2
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES ( @c_Putawayzone   
                , SPACE(30)   
                + RIGHT(REPLICATE(' ',15)+ CONVERT(VARCHAR(15), @n_Tot_qty),15)          
                , 'S2' ) 
                    
         SET @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 63530      
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
            GOTO QUIT    
         END  

         SET @n_cnt = 0
         While @n_cnt < 2
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES (@c_Putawayzone   
                   ,CONVERT(CHAR(1), '' )     -- as blank line
                   ,'' )     -- Grant total
                   
            SET @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 63545      
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
               GOTO QUIT    
            END  
            SET @n_cnt = @n_cnt + 1
         END
         FETCH NEXT FROM CURSOR_PAGRP INTO @c_Putawayzone
      END  -- 1=1 Putawayzone  
      CLOSE CURSOR_PAGRP
      DEALLOCATE CURSOR_PAGRP

      IF Exists ( SELECT 1 from @ShowResult )
      BEGIN
         -- Insert Line for Grand total 
         INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
         VALUES ( @c_Putawayzone   
                , SPACE(39)  
                + RIGHT(REPLICATE(' ',25) + 'Grand SubTotal:',25)
                + SPACE(1)     
                + RIGHT(REPLICATE(' ',10) + CONVERT(VARCHAR(10), @n_Grand_Tot_Qty),10)    
                , 'G1' )                                             -- Grant total
                
         SET @n_err = @@ERROR      
         IF @n_err <> 0       
         BEGIN      
            SET @n_continue = 3      
            SET @n_err = 63550      
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
         END 

         SET @n_cnt = 0
         While @n_cnt < 1
         BEGIN  
            -- Insert Line for Blank Line
            INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
            VALUES ( @c_Putawayzone   
                   , SPACE(1)                                        -- as blank line
                   , '' )                                            -- Grant total

            SET @n_err = @@ERROR      
            IF @n_err <> 0       
            BEGIN      
               SET @n_continue = 3      
               SET @n_err = 63555      
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
            END  
            SET @n_cnt = @n_cnt + 1
         END
 
      END
   END      
   --SET ROWCOUNT 0

   DROP TABLE  #Result1  

   -- Insert Line for "Summary By Load Plan No"
   INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
   VALUES (''
          ,CONVERT(CHAR(30), 'Summary By ExternOrderkey' )           -- Section 3 title
          ,'')                                                       -- Grant total
          
   SET @n_err = @@ERROR      
   IF @n_err <> 0       
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 63556      
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'      
   END  

   -- Insert Line for Label Line - Section 3
   INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag)     
   VALUES ( ''   
          , CONVERT(CHAR(20), 'ExternOrdekey')                       -- Section 3 Label Line
          + SPACE(10)   
          + RIGHT(REPLICATE(' ',15)+ 'Total Case Qty',15)            -- Section 3 Label Line
          , '' )                                                     -- Grant total
          
   SET @n_err = @@ERROR      
   IF @n_err <> 0       
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 63557      
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'       
   END  

   SELECT ISNULL(RTRIM(OH.ExternOrderkey),'')                     AS ExternOrderkey   
        , CAST(ISNULL(SUM(PD.Qty),0) / ISNULL(P.CaseCnt,0) AS Int)AS PickQtyInCnt    
--        , CONVERT(CHAR(10), ISNULL(RTRIM(@c_StopStart),''))       AS StopStart  
--        , CONVERT(CHAR(10), ISNULL(RTRIM(@c_StopEnd ),''))        AS StopEnd   
    INTO #RESUlT2
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK)  ON  ( LPD.Orderkey = PD.Orderkey )
   JOIN LOADPLAN LP WITH (NOLOCK)         ON  ( LPD.Loadkey  = LP.Loadkey )
   JOIN SKUxLOC SL  WITH (NOLOCK)         ON  ( PD.Storerkey = SL.Storerkey )
                                          AND ( PD.Sku       = SL.Sku )
                                          AND ( PD.Loc       = SL.Loc )
   JOIN SKU S       WITH (NOLOCK)         ON  ( PD.Storerkey = S.Storerkey )
                                          AND ( PD.Sku       = S.Sku )
   JOIN PACK P      WITH (NOLOCK)         ON  ( S.Packkey    = P.Packkey )
   JOIN ORDERS OH   WITH (NOLOCK)         ON  ( PD.OrderKey  = OH.OrderKey )
   WHERE LP.LoadKey >= ISNULL(RTRIM(@c_loadkeystart),'')
   AND   LP.LoadKey <= ISNULL(RTRIM(@c_loadkeyend),'')
   AND   LP.Facility = ISNULL(RTRIM(@c_facility),'')
   AND   SL.LocationType <> 'CASE'
   AND   SL.LocationType <> 'PICK'
   AND   PD.Status < '5'
   AND   OH.Stop BETWEEN ISNULL(RTRIM(@c_stopstart),'') AND ISNULL(RTRIM(@c_stopend),'')
   GROUP BY ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(S.Style),'') 
         ,  ISNULL(RTRIM(S.Color),'')
         ,  ISNULL(RTRIM(S.Measurement),'')
         ,  ISNULL(RTRIM(S.Size),'')
         ,  ISNULL(P.CaseCnt,0)
   HAVING CAST(ISNULL(SUM(PD.Qty),0) / ISNULL(P.CaseCnt,0) AS Int)  > 0
   ORDER BY ISNULL(RTRIM(OH.ExternOrderkey),'') 

   INSERT INTO  @ShowResult (Putawayzone,  Line,  LineFlag) 
   SELECT SPACE(1)
        , CONVERT(NCHAR(20),R2.ExternOrderKey) 
        + SPACE(10) 
        + RIGHT(REPLICATE(' ',15)+ CONVERT(VARCHAR(15), ISNULL(SUM(R2.PickQtyInCnt),0)),15)  
        , '' 
   FROM #RESUlT2 R2 WITH (NOLOCK)  
   GROUP BY R2.ExternOrderkey  
   ORDER BY R2.ExternOrderkey
   
   SET @n_err = @@ERROR      
   IF @n_err <> 0       
   BEGIN      
      SET @n_continue = 3      
      SET @n_err = 63558      
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': INSERT @ShowResult Failed. (isp_fullcasepick_04_01)'        
   END   

   QUIT:
   IF CURSOR_STATUS('LOCAL' , 'CURSOR_PAGRP') in (0 , 1)
   BEGIN
      CLOSE CURSOR_PAGRP
      DEALLOCATE CURSOR_PAGRP
   END

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_SKUGRP') in (0 , 1)
   BEGIN
      CLOSE CURSOR_SKUGRP
      DEALLOCATE CURSOR_SKUGRP
   END

   IF CURSOR_STATUS('LOCAL' , 'CURSOR_SOGRP') in (0 , 1)
   BEGIN
      CLOSE CURSOR_SOGRP
      DEALLOCATE CURSOR_SOGRP
   END
 
   SELECT Putawayzone 
         ,Line 
         ,LineFlag   
   FROM @ShowResult     
   ORder by rowid   

   DROP TABLE  #RESUlT2    
        
   IF @n_continue=3  -- Error Occured - Process And Return        
   BEGIN        
      execute nsp_logerror @n_err, @c_errmsg, 'isp_fullcasepick_04_01'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
      RETURN        
   END        
   ELSE        
   BEGIN        
      SET @b_success = 1        
      WHILE @@TRANCOUNT > @n_StartTranCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END        
END /* main procedure */        
        

GO