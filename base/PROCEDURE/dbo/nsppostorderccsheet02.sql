SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure: nspPostOrderCCSheet02                               */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Generate Post Order Process Cycle Count Sheet for SOS#160678*/    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.2 (unicode)                                          */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver. Purposes                                  */    
/* 23-Feb-2010  Vanessa  1.1  SOS#160678 New Requirement for Apparel    */   
/*                            Post Order Process Cycle Count Sheet      */
/*                            (Vanessa01)                               */ 
/* 11-Sep-2013  YTWan    1.2  SOS#288761:Add Loc & Loctype for converse */
/*                            (Wan01)                                   */
/************************************************************************/    

CREATE PROC [dbo].[nspPostOrderCCSheet02](@c_loadkey   NVARCHAR(10))
AS
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @c_size NVARCHAR(5),
            @c_size01 NVARCHAR(5),
            @c_size02 NVARCHAR(5),
            @c_size03 NVARCHAR(5),
            @c_size04 NVARCHAR(5),
            @c_size05 NVARCHAR(5),
            @c_size06 NVARCHAR(5),
            @c_size07 NVARCHAR(5),
            @c_size08 NVARCHAR(5),
            @c_size09 NVARCHAR(5),
            @c_size10 NVARCHAR(5), 
            @n_cnt int,
            @c_stylecolor NVARCHAR(30),     -- (Vanessa01)
            @c_prevstylecolor NVARCHAR(30), -- (Vanessa01)
            @c_Storerkey  NVARCHAR(15)
         ,  @c_Loc            NVARCHAR(10)   --(Wan01)
   
   CREATE TABLE #TEMPREC
            (Style NVARCHAR(30) null,       -- (Vanessa01)
             SizeDesc NVARCHAR(20) null,
             DetailDesc NVARCHAR(20) null,
             size01 NVARCHAR(6) null,
             size02 NVARCHAR(6) null,
             size03 NVARCHAR(6) null,
             size04 NVARCHAR(6) null,
             size05 NVARCHAR(6) null,
             size06 NVARCHAR(6) null,
             size07 NVARCHAR(6) null,
             size08 NVARCHAR(6) null,
             size09 NVARCHAR(6) null,
             size10 NVARCHAR(6) null,
             qty01 int null,
             qty02 int null,
             qty03 int null,
             qty04 int null,
             qty05 int null,
             qty06 int null,
             qty07 int null,
             qty08 int null,
             qty09 int null,
             qty10 int null 
            )  

   SELECT @n_cnt = 0 

   -- Prerequisites:
   -- One Loadplan is only allowed to replenish to only one FAST picking location
   -- picking in post launch is all fast picking
   --(Wan01) - START
   SELECT TOP 1 
          @c_Loc          = PD.Loc
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
   JOIN LOC            L   WITH (NOLOCK) ON (PD.Loc = L.Loc)
   WHERE LPD.LoadKey = @c_loadkey
   AND L.LocationType= 'FAST'
   --(Wan01) - END 

   DECLARE SizeCur CURSOR FAST_FORWARD READ_ONLY FOR
      -- Start (Vanessa01)
      SELECT  SKU.Storerkey, ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''), SKU.SIZE  
      FROM LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL (NOLOCK), SKU (NOLOCK)                           
      WHERE LPD.Orderkey = ORDERDETAIL.Orderkey
      AND   ORDERDETAIL.StorerKey = SKU.StorerKey
      AND   ORDERDETAIL.SKU = SKU.SKU
      AND   LPD.LoadKey    = @c_loadkey
/*
      UNION
      SELECT  SKU.Storerkey, ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''), SKU.SIZE
      FROM REPLENISHMENT (NOLOCK), SKU (NOLOCK), SKUxLOC (NOLOCK), LOC (NOLOCK)  
      WHERE ReplenishmentGroup = @c_loadkey
      AND   REPLENISHMENT.StorerKey = SKU.StorerKey
      AND   REPLENISHMENT.SKU = SKU.SKU
      AND   SKUxLOC.StorerKey = SKU.StorerKey
      AND   SKUxLOC.SKU = SKU.SKU
      AND   SKUxLOC.LOC = LOC.LOC
      AND   LOC.LocationType = 'Fast'
      AND   Confirmed = 'Y'
*/
      GROUP BY SKU.Storerkey, SKU.SIZE,  ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'')
      ORDER BY SKU.Storerkey, ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''),  SKU.SIZE
      -- End (Vanessa01)

   OPEN SizeCur

   FETCH NEXT FROM SizeCur INTO @c_Storerkey, @c_stylecolor, @c_size
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @n_cnt = @n_cnt + 1

      SELECT @c_size01 = CASE @n_cnt WHEN 1
                         THEN @c_size
                         ELSE @c_size01
                         END 
      SELECT @c_size02 = CASE @n_cnt WHEN 2
                         THEN @c_size
                         ELSE @c_size02
                         END
      SELECT @c_size03 = CASE @n_cnt WHEN 3
                         THEN @c_size
                         ELSE @c_size03
                         END
      SELECT @c_size04 = CASE @n_cnt WHEN 4
                         THEN @c_size
                         ELSE @c_size04
                         END
      SELECT @c_size05 = CASE @n_cnt WHEN 5
                         THEN @c_size
                         ELSE @c_size05
                         END
      SELECT @c_size06 = CASE @n_cnt WHEN 6
                         THEN @c_size
                         ELSE @c_size06
                         END
      SELECT @c_size07 = CASE @n_cnt WHEN 7
                         THEN @c_size
                         ELSE @c_size07
                         END
      SELECT @c_size08 = CASE @n_cnt WHEN 8
                         THEN @c_size
                         ELSE @c_size08
                         END
      SELECT @c_size09 = CASE @n_cnt WHEN 9
                         THEN @c_size
                         ELSE @c_size09
                         END
      SELECT @c_size10 = CASE @n_cnt WHEN 10
                         THEN @c_size
                         ELSE @c_size10
                         END

      SELECT @c_prevstylecolor = @c_stylecolor

      FETCH NEXT FROM SizeCur INTO @c_Storerkey, @c_stylecolor, @c_size

      IF (@c_stylecolor <> @c_prevstylecolor) OR (@n_cnt >= 10) OR (@@FETCH_STATUS = -1)
      BEGIN
         INSERT INTO #TEMPREC
         -- Start (Vanessa01)
         SELECT ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') AS 'Style-Color',  
                'Size----->',
                'Replenished Qty',
                @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SKU.SIZE WHEN @c_size01
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  , 
                CASE SKU.SIZE WHEN @c_size02
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  ,
                CASE SKU.SIZE WHEN @c_size03
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END ,
                CASE SKU.SIZE WHEN @c_size04
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  ,
                CASE SKU.SIZE WHEN @c_size05
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  ,
                CASE SKU.SIZE WHEN @c_size06
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  , 
                CASE SKU.SIZE WHEN @c_size07
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  ,
                CASE SKU.SIZE WHEN @c_size08
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END ,
                CASE SKU.SIZE WHEN @c_size09
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END  ,
                CASE SKU.SIZE WHEN @c_size10
                                           THEN SUM(CASE WHEN LOC.LocationType = 'Fast' THEN SL.Qty ELSE 0 END )
                                           ELSE 0
                                           END
         FROM SKUxLOC SL (NOLOCK)
               JOIN LOC LOC (NOLOCK) ON (SL.LOC = LOC.LOC)
               JOIN SKU SKU (NOLOCK) ON (SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku)
         WHERE SL.Storerkey           = @c_storerkey
         AND   ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') = @c_prevstylecolor
         --(Wan01) - START
         AND   SL.Loc = @c_Loc
         --(Wan01) - END
         AND   1= CASE SKU.SIZE WHEN @c_size01
                                                THEN 1
                                                WHEN @c_size02
                                                THEN 1
                                                WHEN @c_size03
                                                THEN 1
                                                WHEN @c_size04
                                                THEN 1
                                                WHEN @c_size05
                                                THEN 1
                                                WHEN @c_size06
                                                THEN 1
                                                WHEN @c_size07
                                                THEN 1
                                                WHEN @c_size08
                                                THEN 1
                                                WHEN @c_size09
                                                THEN 1
                                                WHEN @c_size10
                                                THEN 1
                                                ELSE 0
                                                END  
         GROUP BY SL.Storerkey, ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''), SKU.SIZE, LOC.LocationType
         -- End (Vanessa01)

         INSERT INTO #TEMPREC
         -- Start (Vanessa01)
         SELECT ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') AS 'Style-Color', 
                'Size----->',
                'Sum Of Order Qty',
                @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SKU.SIZE WHEN @c_size01
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  , 
                CASE SKU.SIZE WHEN @c_size02
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END, 
                CASE SKU.SIZE WHEN @c_size03
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END ,
                CASE SKU.SIZE WHEN @c_size04
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size05
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size06
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  , 
                CASE SKU.SIZE WHEN @c_size07
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size08
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END ,
                CASE SKU.SIZE WHEN @c_size09
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size10
                                             THEN SUM(OriginalQty)
                                             ELSE 0
                                             END 
         FROM  LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL OD (NOLOCK), SKU SKU (NOLOCK)
         WHERE LPD.Orderkey  = OD.Orderkey
         AND   LPD.Loadkey   = @c_loadkey
         AND   OD.StorerKey  = SKU.StorerKey
         AND   OD.SKU        = SKU.SKU
         AND   ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') = @c_prevstylecolor
         AND   1= CASE SKU.SIZE WHEN @c_size01
                                                THEN 1
                                                WHEN @c_size02
                                                THEN 1
                                                WHEN @c_size03
                                                THEN 1
                                                WHEN @c_size04
                                                THEN 1
                                                WHEN @c_size05
                                                THEN 1
                                                WHEN @c_size06
                                                THEN 1
                                                WHEN @c_size07
                                                THEN 1
                                                WHEN @c_size08
                                                THEN 1
                                                WHEN @c_size09
                                                THEN 1
                                                WHEN @c_size10
                                                THEN 1
                                                ELSE 0
                                                END  
         GROUP BY ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''), SKU.SIZE
         -- End (Vanessa01)

         INSERT INTO #TEMPREC
         -- Start (Vanessa01)
         SELECT ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') AS 'Style-Color', 
                'Size----->',
                'Sum Of Processed',
                @c_size01, @c_size02, @c_size03, @c_size04, @c_size05, @c_size06, @c_size07, @c_size08, @c_size09, @c_size10,
                CASE SKU.SIZE WHEN @c_size01
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  , 
                CASE SKU.SIZE WHEN @c_size02
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END, 
                CASE SKU.SIZE WHEN @c_size03
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END ,
                CASE SKU.SIZE WHEN @c_size04
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size05
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size06
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  , 
                CASE SKU.SIZE WHEN @c_size07
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size08
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END ,
                CASE SKU.SIZE WHEN @c_size09
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END  ,
                CASE SKU.SIZE WHEN @c_size10
                                             THEN SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
                                             ELSE 0
                                             END
         FROM  LOADPLANDETAIL LPD (NOLOCK), ORDERDETAIL OD (NOLOCK), SKU SKU (NOLOCK)
         WHERE LPD.Orderkey  = OD.Orderkey
         AND   LPD.Loadkey   = @c_loadkey
         AND   OD.StorerKey  = SKU.StorerKey
         AND   OD.SKU        = SKU.SKU
         AND   ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') = @c_prevstylecolor
         AND   1= CASE SKU.SIZE WHEN @c_size01
                                                THEN 1
                                                WHEN @c_size02
                                                THEN 1
                                                WHEN @c_size03
                                                THEN 1
                                                WHEN @c_size04
                                                THEN 1
                                                WHEN @c_size05
                                                THEN 1
                                                WHEN @c_size06
                                                THEN 1
                                                WHEN @c_size07
                                                THEN 1
                                                WHEN @c_size08
                                                THEN 1
                                                WHEN @c_size09
                                                THEN 1
                                                WHEN @c_size10
                                                THEN 1
                                                ELSE 0
                                                END  
         GROUP BY ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''), SKU.SIZE
         -- End (Vanessa01)   

         --RESet cnt = 0 
         SELECT @n_cnt =0,  @c_size01 = NULL, @c_size02 = NULL, @c_size03 = NULL, @c_size04 = NULL, @c_size05 = NULL, 
                @c_size06 = NULL, @c_size07 = NULL, @c_size08 = NULL, @c_size09 = NULL, @c_size10 = NULL
      END
   END

   CLOSE SizeCur
   DEALLOCATE SizeCur
   
   SELECT Style AS StyleColor, SizeDesc, DetailDesc, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10,  -- (Vanessa01)
          SUM(qty01) qty01, SUM(qty02) qty02, SUM(qty03) qty03, SUM(qty04) qty04, SUM(qty05) qty05, 
          SUM(qty06) qty06, SUM(qty07) qty70, SUM(qty08) qty08, SUM(qty09) qty09, SUM(qty10) qty10, @c_loadkey
         ,@c_loc                                                                               --(Wan01)
   FROM #TEMPREC
   GROUP BY Style, SizeDesc, DetailDesc, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10
   ORDER BY Style, size01, size02, size03, size04, size05, size06, size07, size08, size09, size10, DetailDesc
     
   DROP TABLE #TEMPREC
END

GO