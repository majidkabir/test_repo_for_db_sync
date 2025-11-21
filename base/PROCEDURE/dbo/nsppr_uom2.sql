SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/    
/* Store Procedure:  nspPR_UOM2                                           */    
/* Creation Date:                                                         */    
/* Copyright: IDS                                                         */    
/* Written by:                                                            */    
/*                                                                        */    
/* Purpose:  Pre-Allocation Strategy of IDSCN - NIKE                      */    
/*                                                                        */    
/* Input Parameters:  @c_StorerKey char                                   */    
/*                    @c_SKU char                                         */    
/*                    @c_lot char                                         */    
/*                    @c_Lottable01                                       */    
/*                    @c_Lottable02                                       */    
/*                    @c_Lottable03                                       */    
/*                    @d_Lottable04                                       */    
/*                    @d_Lottable05                                       */    
/*                    @c_UOM                                              */    
/*                    @c_Facility                                         */    
/*                    @n_UOMBase                                          */    
/*                    @n_QtyLeftToFulfill                                 */    
/*                                                                        */    
/* Output Parameters:  None                                               */    
/*                                                                        */    
/* Return Status:  None                                                   */    
/*                                                                        */    
/* Usage:                                                                 */    
/*                                                                        */    
/* Local Variables:                                                       */    
/*                                                                        */    
/* Called By: Allocation Module                                           */    
/*                                                                        */    
/* PVCS Version: 1.0                                                      */    
/*                                                                        */    
/* Version: 5.4                                                           */    
/*                                                                        */    
/* Data Modifications:                                                    */    
/*                                                                        */    
/* Updates:                                                               */    
/* Date         Author      Purposes                                      */    
/* 01-Feb-2010  Shong       SOS162789 Strategy special design for NIVEA   */    
/*                          China.                                        */    
/* 25-Nov-2010  NJOW02  1.2 196281-shelf life checking based on sku.susr2 */   
/* 18-Mar-2015  SHONG   1.3 Add Extra Parameters                          */
/* 18-Sep-2015  NJOW03  1.4 353061 - add lottable06-15                    */
/* 17-Jul-2018  TLTING01 1.6  Dynamic SQL - cache issue                   */  
/**************************************************************************/    
CREATE PROCEDURE [dbo].[nspPR_UOM2]   
   @c_StorerKey NVARCHAR(15) ,  
   @c_SKU NVARCHAR(20) ,  
   @c_Lot NVARCHAR(10) ,  
   @c_Lottable01 NVARCHAR(18) ,  
   @c_Lottable02 NVARCHAR(18) ,  
   @c_Lottable03 NVARCHAR(18) ,  
   @d_Lottable04 DATETIME ,  
   @d_Lottable05 DATETIME ,  
   @c_Lottable06 NVARCHAR(30),
   @c_Lottable07 NVARCHAR(30),
   @c_Lottable08 NVARCHAR(30),
   @c_Lottable09 NVARCHAR(30),
   @c_Lottable10 NVARCHAR(30),
   @c_Lottable11 NVARCHAR(30),
   @c_Lottable12 NVARCHAR(30),
   @d_Lottable13 DATETIME,  
   @d_Lottable14 DATETIME,  
   @d_Lottable15 DATETIME,  
   @c_UOM NVARCHAR(10) ,  
   @c_Facility NVARCHAR(10) ,  
   @n_UOMBase INT ,  
   @n_QtyLeftToFulfill INT, -- new column  
   @c_OtherParms NVARCHAR(200) = ''
AS  
BEGIN  
    SET NOCOUNT ON  
      
    DECLARE @b_success          INT  
           ,@n_err              INT  
           ,@c_errmsg           NVARCHAR(250)  
           ,@b_debug            INT  
           ,@c_SQL              NVARCHAR(MAX)             
           ,@c_SQLParm           NVARCHAR(4000)  
           ,@n_CaseCnt          INT  
      
    DECLARE @c_Manual           NVARCHAR(1)       
    DECLARE @c_LimitString      NVARCHAR(255) -- To limit the where clause based on the user input      
    DECLARE @c_Limitstring1     NVARCHAR(255)  
           ,@c_Lottable04Label  NVARCHAR(20)  
      
    SELECT @b_success = 0  
          ,@n_err = 0   
          ,@c_errmsg = ''  
          ,@b_debug = 0  
      
    SELECT @c_manual = 'N'      
      
    DECLARE @n_ShelfLife  INT     
    DECLARE @n_continue   INT    
      
    DECLARE @c_UOMBase    NVARCHAR(10)    
      
    SELECT @c_UOMBase = @n_UOMBase    
  
    SELECT @n_CaseCnt  = p.CaseCnt   
    FROM PACK p WITH (NOLOCK)  
    JOIN SKU s WITH (NOLOCK) ON s.PackKey = p.PackKey  
    WHERE s.StorerKey = @c_StorerKey AND  
          s.Sku = @c_SKU  
  
    -- SELECT NOTHING IF Qty Allocated for UOM 2 (Carton) is less then a Carton   
    IF @c_UOM = '2' AND @n_QtyLeftToFulfill < @n_CaseCnt   
    BEGIN  
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  SCROLL CURSOR    
        FOR  
            SELECT LOT.StorerKey  
                  ,LOT.SKU  
                  ,LOT.LOT  
                  ,QTYAVAILABLE = 0  
            FROM   LOT(NOLOCK)   
            WHERE 1=2  
              
       RETURN  
    END  
  
    --NJOW02  
    SELECT @n_ShelfLife = CASE WHEN ISNUMERIC(ISNULL(SKU.Susr2,'0')) = 1 THEN CONVERT(INT, ISNULL(SKU.Susr2,'0')) ELSE 0 END  
    FROM SKU (NOLOCK)  
    WHERE SKU.Sku = @c_SKU  
    AND SKU.Storerkey = @c_StorerKey     
  
    IF @d_Lottable04='1900-01-01'  
    BEGIN  
        SELECT @d_Lottable04 = NULL  
    END    
      
    IF @d_Lottable05='1900-01-01'  
    BEGIN  
        SELECT @d_Lottable05 = NULL  
    END    

    IF @d_Lottable13='1900-01-01'  
    BEGIN  
        SELECT @d_Lottable13 = NULL  
    END    

    IF @d_Lottable14='1900-01-01'  
    BEGIN  
        SELECT @d_Lottable14 = NULL  
    END    

    IF @d_Lottable15='1900-01-01'  
    BEGIN  
        SELECT @d_Lottable15 = NULL  
    END    
      
    IF @b_debug=1  
    BEGIN   
        SELECT 'nspPR_UOM2 : Before Lot Lookup .....'      
        SELECT '@c_lot' = @c_lot  
              ,'@c_Lottable01' = @c_Lottable01  
              ,'@c_Lottable02' = @c_Lottable02  
              ,'@c_Lottable03' = @c_Lottable03  
          
        SELECT '@d_Lottable04' = @d_Lottable04  
              ,'@d_Lottable05' = @d_Lottable05  
              ,'@c_manual' = @c_manual  
              ,'@c_SKU' = @c_SKU  
          
        SELECT '@c_StorerKey' = @c_StorerKey  
              ,'@c_Facility' = @c_Facility  
    END   
      
    -- when any of the Lottables is supplied, get the specific lot  
    --   IF (@c_Lottable01<>'' OR @c_Lottable02<>'' OR @c_Lottable03<>'' OR  
    --       @d_Lottable04 IS NOT NULL OR @d_Lottable05 IS NOT NULL) OR LEFT(@c_lot,1) = '*'    
      
    IF (  
           (ISNULL(LTRIM(RTRIM(@c_Lottable01)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable02)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable03)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@d_Lottable04)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@d_Lottable05)) ,''))<>'' OR
           (ISNULL(LTRIM(RTRIM(@c_Lottable06)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable07)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable08)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable09)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable10)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable11)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@c_Lottable12)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@d_Lottable13)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@d_Lottable14)) ,''))<>'' OR  
           (ISNULL(LTRIM(RTRIM(@d_Lottable15)) ,''))<>'' 
       ) OR  
       LEFT(ISNULL(LTRIM(RTRIM(@c_lot)) ,'') ,1)='*' -- SOS128087  
    BEGIN  
        SELECT @c_manual = 'Y'  
    END      
      
    IF @b_debug=1  
    BEGIN  
        SELECT 'nspPR_UOM2 : After Lot Lookup .....'      
        SELECT '@c_lot' = @c_lot  
              ,'@c_Lottable01' = @c_Lottable01  
              ,'@c_Lottable02' = @c_Lottable02  
              ,'@c_Lottable03' = @c_Lottable03  
          
        SELECT '@d_Lottable04' = @d_Lottable04  
              ,'@d_Lottable05' = @d_Lottable05  
              ,'@c_manual' = @c_manual  
          
        SELECT '@c_StorerKey' = @c_StorerKey  
    END   
      
    -- Start : SOS76195      
    IF ISNULL(RTrim(@c_lot),'') <> '' AND  
       LEFT(@c_lot ,1)<>'*'   
    BEGIN  
        /* Lot specific candidate set */      
        DECLARE PREALLOCATE_CURSOR_CANDIDATES  SCROLL CURSOR    
        FOR  
            SELECT LOT.StorerKey  
                  ,LOT.SKU  
                  ,LOT.LOT  
                  ,QTYAVAILABLE                = (  
                       LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED  
                   )  
            FROM   LOT(NOLOCK)  
                  ,LOTATTRIBUTE                (NOLOCK)  
                  ,LOTxLOCxID                  (NOLOCK)  
                  ,LOC                         (NOLOCK)  
                  ,SKUxLOC                     (NOLOCK)  
            WHERE  LOT.LOT = LOTATTRIBUTE.LOT AND  
                   LOTxLOCxID.Lot = LOT.LOT AND  
                   LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND  
                   LOTxLOCxID.LOC = LOC.LOC AND  
                   LOC.Facility = @c_Facility AND  
                   LOT.LOT = @c_lot AND  
                   SKUxLOC.StorerKey = LOTxLOCxID.StorerKey AND  
                   SKUxLOC.SKU = LOTxLOCxID.SKU AND  
                   SKUxLOC.LOC = LOTxLOCxID.LOC   
            ORDER BY  
                   LOTATTRIBUTE.Lottable04  
                  ,LOTATTRIBUTE.Lottable05      
          
        IF @b_debug=1  
        BEGIN  
            SELECT ' Lot not null'    
            SELECT LOT.StorerKey  
                  ,LOT.SKU  
                  ,LOT.LOT  
                  ,QTYAVAILABLE = (  
                       LOT.QTY- LOT.QTYALLOCATED- LOT.QTYPICKED- LOT.QTYPREALLOCATED  
                   )  
            FROM   LOT   (NOLOCK)
                  ,LOTATTRIBUTE  (NOLOCK)
            WHERE  LOT.LOT = LOTATTRIBUTE.LOT AND  
                   LOT.LOT = @c_lot  
            ORDER BY  
                   LOTATTRIBUTE.Lottable04  
                  ,LOTATTRIBUTE.Lottable02  
        END  
    END  
    ELSE  
    BEGIN  
      IF @b_debug=1  
          SELECT 'Manual = Y and Lot is NULL'    
        
      SELECT @c_LimitString = ''   
        
      IF ISNULL(RTRIM(@c_Lottable01) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable01= @c_Lottable01 '   
        
      IF ISNULL(RTRIM(@c_Lottable02) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable02= @c_Lottable02 '   
        
      IF ISNULL(RTRIM(@c_Lottable03) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable03= @c_Lottable03 '   
        
      IF ISNULL(RTRIM(@d_Lottable04) ,'')<>'' AND  
         ISNULL(RTRIM(@d_Lottable04) ,'')<>'1900-01-01'  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable04 = @d_Lottable04 '   
        
      IF ISNULL(RTRIM(@d_Lottable05) ,'')<>'' AND  
         ISNULL(RTRIM(@d_Lottable05) ,'')<>'1900-01-01'  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable05= @d_Lottable05 '      

      IF ISNULL(RTRIM(@c_Lottable06) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable06= @c_Lottable06 '   

      IF ISNULL(RTRIM(@c_Lottable07) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable07= @c_Lottable07 '   

      IF ISNULL(RTRIM(@c_Lottable08) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable08= @c_Lottable08 '   

      IF ISNULL(RTRIM(@c_Lottable09) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable09= @c_Lottable09 '   

      IF ISNULL(RTRIM(@c_Lottable10) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable10= @c_Lottable10 '   

      IF ISNULL(RTRIM(@c_Lottable11) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable11= @c_Lottable11 '   

      IF ISNULL(RTRIM(@c_Lottable12) ,'')<>''  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable12=  @c_Lottable12 '   

      IF ISNULL(RTRIM(@d_Lottable13) ,'')<>'' AND  
         ISNULL(RTRIM(@d_Lottable13) ,'')<>'1900-01-01'  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable13= @d_Lottable13 '      

      IF ISNULL(RTRIM(@d_Lottable14) ,'')<>'' AND  
         ISNULL(RTRIM(@d_Lottable14) ,'')<>'1900-01-01'  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable14= @d_Lottable14 '      

      IF ISNULL(RTRIM(@d_Lottable15) ,'')<>'' AND  
         ISNULL(RTRIM(@d_Lottable15) ,'')<>'1900-01-01'  
          SELECT @c_LimitString = RTrim(@c_LimitString)+  
                 ' AND Lottable15= @d_Lottable15 '      
        
      IF LEFT(@c_lot ,1)='*' AND @n_ShelfLife = 0 --NJOW02      
      BEGIN  
          SELECT @n_ShelfLife = CONVERT(INT ,SUBSTRING(@c_lot ,2 ,9))    
            
          IF @n_ShelfLife<13   
             -- it's month  
          BEGIN  
              SELECT @c_Limitstring = RTrim(@c_LimitString)+  
                     ' AND Lottable04  > CONVERT(VARCHAR(15) ,DATEADD(MONTH ,@n_ShelfLife ,GETDATE()) ,106) '  
          END  
          ELSE  
          BEGIN  
              SELECT @c_Limitstring = RTrim(@c_LimitString)+  
                     ' AND Lottable04  > CONVERT(VARCHAR(15) ,DATEADD(DAY ,@n_ShelfLife ,GETDATE()) ,106) '  
          END  
      END  
      ELSE   
      BEGIN  --NJOW02  
          IF @n_ShelfLife > 0  
              SELECT @c_Limitstring = RTrim(@c_LimitString)+  
                     ' AND Lottable04  > CONVERT(VARCHAR(15) ,DATEADD(DAY ,@n_ShelfLife ,GETDATE()) ,106) '           
      END  
  
        
      IF @b_debug=1  
      BEGIN  
          SELECT '@c_limitstring'  
                 ,@c_limitstring  
      END   
     SELECT @c_SQL =   
               ' DECLARE PREALLOCATE_CURSOR_CANDIDATES SCROLL CURSOR FOR '   
              +' SELECT MIN(LOTxLOCxID.StorerKey) , MIN(LOTxLOCxID.SKU), LOT.LOT, '   
              +' CASE WHEN    
           SUM(LOTxLOCxID.QTY)- SUM(LOTxLOCxID.QTYALLOCATED)- SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0)) <   
           MIN(LOT.QTY)- MIN(LOT.QTYALLOCATED)- MIN(LOT.QTYPICKED) - MIN(LOT.QtyPreallocated) - MIN(LOT.QtyOnHold)    
           THEN SUM(LOTxLOCxID.QTY)- SUM(LOTxLOCxID.QTYALLOCATED)- SUM(LOTxLOCxID.QTYPICKED) - MIN(ISNULL(P.QtyPreallocated,0))   
           ELSE MIN(LOT.QTY)- MIN(LOT.QTYALLOCATED)- MIN(LOT.QTYPICKED) - MIN(LOT.QtyPreallocated) - MIN(LOT.QtyOnHold)   
           END '   
              +' FROM LOT (NOLOCK) '  
              +' JOIN LOTATTRIBUTE (NOLOCK) ON (lot.lot = lotattribute.lot) '   
              +' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) '   
              +' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) '+  
               ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) '+  
               ' JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.StorerKey = LOTxLOCxID.StorerKey) '   
              +' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) '   
              +                 ' FROM   PreallocatePickdetail P (NOLOCK), ORDERS (NOLOCK) '   
              +                 ' WHERE  P.Orderkey = ORDERS.Orderkey '  
              +                 ' AND    P.StorerKey = @c_StorerKey '  
              +                 ' AND    P.SKU = @c_SKU '  
              +                 ' AND    ORDERS.Facility = @c_Facility '  
              +                 ' AND    P.qty > 0 '   
              +                 ' AND    P.UOM IN (' + CASE WHEN @c_UOM = '6' THEN '''6''' ELSE '''2'',''7'''  END + ') '   
              +                 ' AND    P.PreAllocatePickCode = ''nspPR_UOM2'''  
              +                 ' GROUP BY p.Lot, ORDERS.Facility) P '  
              +                 ' ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility '   
              +' WHERE LOT.StorerKey = @c_StorerKey '+  
               ' AND LOT.SKU = @c_SKU '+  
               ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'' And LOC.LocationFlag = ''NONE'' '   
              +' AND LOC.Facility = @c_Facility '+@c_LimitString+' '     
              +'  AND (SKUxLOC.LocationType NOT IN (''CASE'',''PICK'')) '   
              +' GROUP BY LOT.LOT, SKUxLOC.LocationType, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 '  
              +' HAVING (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QtyAllocated) - SUM(LOTxLOCxID.QTYPicked)- MIN(ISNULL(P.QtyPreallocated,0)) ) >= '   
              + CAST(@n_CaseCnt AS NVARCHAR(10))    
              +' ORDER BY  LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable05 '   


       SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +    
                         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +
                         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +
                         '@c_Lottable06 NVARCHAR(30), ' +
                         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' + 
                         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' + 
                         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +
                         '@n_ShelfLife INT  '     
      
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU, @c_Lottable01, @c_Lottable02, @c_Lottable03,
                         @d_Lottable04, @d_Lottable05, @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09, 
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,  
                         @n_ShelfLife   

  
--      EXEC (@c_SQL)   
   END  
END  


GO