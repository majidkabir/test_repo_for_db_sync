SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Stored Procedure: nspPR_PH09                                         */  
/* Creation Date: 03-Jun-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-13601 PH Unilever allocation                            */  
/*          Notes: Turn on configkey 'OrderInfo4Preallocation'          */  
/*                                                                      */  
/* Called By: nspPrealLOCateOrderProcessing                             */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/* 16-Jun-2020  NJOW01  1.0  Fix sorting and grouping                   */
/* 03-Dec-2020  WLChooi 1.1  WMS-15808 - Add new sorting based on config*/
/*                           (WL01)                                     */
/* 12-Mar-2021  WLChooi 1.2  WMS-16550 - Consider QtyReplen (WL02)      */
/* 14-May-2021  NJOW02  1.3  WMS-17043 PH YLEO No partial allocate line */
/************************************************************************/  
  
CREATE PROC [dbo].[nspPR_PH09]  
 @c_storerkey NVARCHAR(15),  
 @c_sku NVARCHAR(20),  
 @c_lot NVARCHAR(10),  
 @c_lottable01 NVARCHAR(18),  
 @c_lottable02 NVARCHAR(18),  
 @c_lottable03 NVARCHAR(18),  
 @d_lottable04 DATETIME,  
 @d_lottable05 DATETIME,  
 @c_lottable06 NVARCHAR(30),  
 @c_lottable07 NVARCHAR(30),  
 @c_lottable08 NVARCHAR(30),  
 @c_lottable09 NVARCHAR(30),  
 @c_lottable10 NVARCHAR(30),  
 @c_lottable11 NVARCHAR(30),  
 @c_lottable12 NVARCHAR(30),  
 @d_lottable13 DATETIME,  
 @d_lottable14 DATETIME,  
 @d_lottable15 DATETIME,  
 @c_uom NVARCHAR(10),  
 @c_facility NVARCHAR(10),  
 @n_uombase INT,  
 @n_qtylefttofulfill INT,  
 @c_OtherParms NVARCHAR(200)  
AS  
BEGIN   
   DECLARE @b_debug                       INT  
          ,@c_SQLStmt                     NVARCHAR(4000)  
          ,@c_SQLParm                     nvarchar(4000)  = ''   
          ,@b_Success                     INT  
          ,@n_Err                         INT  
          ,@c_ErrMsg                      NVARCHAR(255)  
          ,@c_AllocateByConsNewExpiry     NVARCHAR(10)  
          ,@c_FromTableJoin               NVARCHAR(500)  
          ,@c_Where                       NVARCHAR(500)  
          ,@c_LimitString                 NVARCHAR(1000) -- To limit the where clause based on the user input  
          ,@n_SkuShelfLife                INT  
          ,@n_SkuOutgoingShelfLife        INT -- SKU.SUSR2  
          ,@n_ConsigneeShelfLife          INT  
          ,@c_Consigneekey                NVARCHAR(15)  
          ,@c_ConSusr1                    NVARCHAR(10)  
          ,@c_SortMode                    NVARCHAR(20)  
          ,@c_OrderBy                     NVARCHAR(2000)  
          ,@c_LottableList                NVARCHAR(1000)  
          ,@c_key1                        NVARCHAR(10)  
          ,@c_key2                        NVARCHAR(5)  
          ,@c_key3                        NCHAR(1)    
          ,@C_FullLineAlloc               NVARCHAR(30)
          ,@n_QtyAvai                     INT
          ,@n_OrderLineQty                INT
          ,@c_OrdDetUserdefine02          NVARCHAR(18)
    
   SELECT @b_debug = 0 
   SELECT @c_SQLStmt = ''  
   SELECT @c_errmsg = '', @n_err = 0, @b_success = 0, @c_FromTableJoin = '', @c_Where = '', @c_LimitString = '', @c_ConSusr1 = ''  
  
   -- If @c_LOT is not null  
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_LOT)) IS NOT NULL  
   BEGIN  
      DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT LOT.StorerKey, LOT.SKU, LOT.LOT,   
           QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0))   --WL02
      FROM LOTXLOCXID (NOLOCK)   
      JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT  
      JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT  
      JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC  
      JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID   
      LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty)   
                  FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK)   
                  WHERE  P.Orderkey = ORDERS.Orderkey   
                  AND    P.StorerKey = @c_storerkey  
                  AND    P.SKU = @c_sku  
                  AND    P.Qty > 0  
                  GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility   
      WHERE LOTXLOCXID.LOT = @c_LOT  
            AND LOTXLOCXID.Qty > 0  
            AND LOT.Status = 'OK'  
            AND ID.Status = 'OK'   
            AND LOC.Facility = @c_facility  
            AND LOC.Status = 'OK' AND LOC.LocationFlag = 'NONE'  
         GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT  
         HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) > 0   --WL02
   END  
   ELSE  
   BEGIN  
      SELECT @c_LimitString = ''  

      --get lottable filtering logic  
      SET @c_LottableList = ''  
      SELECT @c_LottableList = @c_LottableList + code + ' '   
      FROM CODELKUP(NOLOCK)   
      WHERE listname = 'AllocLot'  
      AND Storerkey = @c_Storerkey  
                    
       --Lottable filtering  
      IF @c_lottable01 <> ' ' OR CHARINDEX('LOTTABLE01', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND Lottable01= @c_lottable01 '    
          
      IF @c_lottable02 <> ' ' OR CHARINDEX('LOTTABLE02', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable02= @c_lottable02 '   
        
      IF @c_lottable03 <> ' ' OR CHARINDEX('LOTTABLE03', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable03= @c_lottable03 '    
        
      IF @d_lottable04 IS NOT NULL AND @d_lottable04 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable04 = @d_lottable04 '    
      ELSE IF CHARINDEX('LOTTABLE04', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND (lottable04 IS NULL OR lottable04 = N''1900-01-01'') '    
          
      IF @d_lottable05 IS NOT NULL  AND @d_lottable05 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable05= @d_lottable05 '    
      ELSE IF CHARINDEX('LOTTABLE05', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND (lottable05 IS NULL OR lottable05 = N''1900-01-01'') '    
  
      IF @c_lottable06 <> ' ' OR CHARINDEX('LOTTABLE06', @c_LottableList) > 0   
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable06= @c_lottable06 '    

      IF @c_lottable07 <> ' ' OR CHARINDEX('LOTTABLE07', @c_LottableList) > 0   
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable07= @c_lottable07 '    

      IF @c_lottable08 <> ' ' OR CHARINDEX('LOTTABLE08', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable08= @c_lottable08 '     

      IF @c_lottable09 <> ' ' OR CHARINDEX('LOTTABLE09', @c_LottableList) > 0   
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable09= @c_lottable09 '    

      IF @c_lottable10 <> ' ' OR CHARINDEX('LOTTABLE10', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable10= @c_lottable10 '    

      IF @c_lottable11 <> ' ' OR CHARINDEX('LOTTABLE11', @c_LottableList) > 0   
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable11= @c_lottable11 '    
      IF @c_lottable12 <> ' ' OR CHARINDEX('LOTTABLE12', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable12= @c_lottable12 '    
  
      IF @d_lottable13 IS NOT NULL AND @d_lottable13 <> '1900-01-01'   
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable13 = @d_lottable13 '    
      ELSE IF CHARINDEX('LOTTABLE13', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND (lottable13 IS NULL OR lottable13 = N''1900-01-01'') '    
  
      IF @d_lottable14 IS NOT NULL AND @d_lottable14 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable14 = @d_lottable14 '    
      ELSE IF CHARINDEX('LOTTABLE14', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND (lottable14 IS NULL OR lottable14 = N''1900-01-01'') '    
  
      IF @d_lottable15 IS NOT NULL AND @d_lottable15 <> '1900-01-01'  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND lottable15 = @d_lottable15 '    
      ELSE IF CHARINDEX('LOTTABLE15', @c_LottableList) > 0  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND (lottable15 IS NULL OR lottable15 = N''1900-01-01'') '    
        
       -- Get OrderKey - @c_OtherParms pass-in OrderKey and OrderLineNumber   
      IF ISNULL(@c_OtherParms,'') <> ''  
      BEGIN          
         SET @c_key1 = LEFT(@c_OtherParms, 10) --Orderkey, Loadkey(conso), Wavekey(conso)  
         SET @c_key2 = SUBSTRING(@c_OtherParms, 11, 5) --OrderLineNumber             
         SET @c_key3 = SUBSTRING(@c_OtherParms, 16, 1) --W=Wave            

         IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''  
         BEGIN  
            SELECT TOP 1 @c_Consigneekey = ORDERS.Consigneekey,  
                    @c_ConSusr1 = STORER.Susr1,  
                    @c_SortMode = STORER.Susr2  
            FROM ORDERS(NOLOCK)  
            JOIN STORER (NOLOCK)ON ORDERS.Consigneekey = STORER.Storerkey  
            WHERE ORDERS.Orderkey = @c_key1  

            SELECT @n_ConsigneeShelfLife = ISNULL( STORER.MinShelfLife, 0)  
            FROM   ORDERS (NOLOCK)  
            JOIN   STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey)  
            WHERE  ORDERS.OrderKey = @c_key1               
         END   
                                
         IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')='' --call by load/wave conso  
         BEGIN  
            SELECT @c_Consigneekey = SUBSTRING(@c_OtherParms, 17, 15)  
           
            SELECT TOP 1 @c_Consigneekey = STORER.Storerkey,  
                       @c_ConSusr1 = STORER.Susr1,  
                       @c_SortMode = STORER.Susr2  
            FROM STORER (NOLOCK)  
            WHERE STORER.Storerkey = @c_Consigneekey               

            SELECT @n_ConsigneeShelfLife = ISNULL( STORER.MinShelfLife, 0)  
            FROM STORER (NOLOCK)   
            WHERE Storerkey = @c_Consigneekey               
         END                            
         
         --NJOW02
         IF ISNULL(@c_key1,'')<>'' AND ISNULL(@c_key2,'')<>''
         BEGIN
            SELECT @n_OrderLineQty = OpenQty - QtyAllocated - QtyPicked,
                   @c_OrdDetUserdefine02 = Userdefine02
            FROM ORDERDETAIL (NOLOCK)
            WHERE Orderkey = @c_Key1
            AND OrderLineNumber = @c_Key2
         END 
      END  
         
      --Sorting  
      IF ISNULL(@c_SortMode,'') = 'LEFO'  
      BEGIN  
         IF @c_UOM = '1'                       
          --SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType NOT IN(''PICK'') THEN 1 ELSE 2 END, LOTATTRIBUTE.LOTTABLE04 DESC, LOTATTRIBUTE.Lottable05, LOT.Lot '  -- ZG01
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType NOT IN(''CASE'',''PICK'') THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04 DESC, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, LOC.LogicalLocation, LOC.Loc '  --ZG01
         ELSE IF @c_UOM = '2'  
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''CASE'' THEN 1 WHEN LOC.LocationType = ''PICK'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04 DESC, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, MIN(Loc.LogicalLocation), LOT.Lot '  
         ELSE --uom 6  
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04 DESC, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, MIN(Loc.LogicalLocation), LOT.Lot '              
      END     
      ELSE --FEFO  
      BEGIN  
         IF @c_UOM = '1'                       
          --SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType NOT IN(''PICK'') THEN 1 ELSE 2 END, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.Lottable05, LOT.Lot '  -- ZG01
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType NOT IN (''CASE'',''PICK'') THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, LOC.LogicalLocation, LOC.Loc '  -- ZG01
         ELSE IF @c_UOM = '2'  
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''CASE'' THEN 1 WHEN LOC.LocationType = ''PICK'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, MIN(Loc.LogicalLocation), LOT.Lot '  
         ELSE --uom 6  
          SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.LOTTABLE04, LOTATTRIBUTE.LOTTABLE02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, MIN(Loc.LogicalLocation), LOT.Lot '              
      END
      
      --WL01 START
      SELECT @c_SortMode = ISNULL(CL.Code,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'PKCODECFG'
      AND CL.Long = 'nspPR_PH09'
      AND CL.Code = 'ADISORT'
      AND CL.Storerkey = @c_storerkey
      AND CL.Short = 'Y'
      AND (CL.Code2 = @c_Facility OR CL.Code2 = '')
      ORDER BY CASE WHEN CL.Code2 = '' THEN 2 ELSE 1 END
      
      IF @c_SortMode = 'ADISORT'
      BEGIN
         IF @c_UOM = '1'                       
            SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType NOT IN (''CASE'',''PICK'') AND LOC.LocationType = ''DYNPCKFACE'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, LOC.LogicalLocation, LOTATTRIBUTE.LOTTABLE05'
         ELSE IF @c_UOM = '2'  
            SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''CASE'' THEN 1 WHEN LOC.LocationType = ''PICK'' THEN 2 ELSE 3 END, MIN(Loc.LogicalLocation), LOTATTRIBUTE.LOTTABLE05 '  
         ELSE --uom 6  
            SET @c_OrderBy = ' ORDER BY CASE WHEN LOC.LocationType = ''PICK'' THEN 1 WHEN LOC.LocationType = ''CASE'' THEN 2 ELSE 3 END, MIN(Loc.LogicalLocation), LOTATTRIBUTE.LOTTABLE05 '   
            
         SET @c_Where = @c_Where + 'AND LOC.LocationType IN (''CASE'',''PICK'',''DYNPCKFACE'')'    
      END
      --WL01 END
      
      --Shelflife    
      SELECT @n_SkuShelfLife = SKU.Shelflife,   
          @n_SkuOutgoingShelfLife = ISNULL( CAST( SKU.SUSR2 as int), 0)  
      FROM  SKU (NOLOCK)  
      WHERE SKU.StorerKey = dbo.fnc_RTrim(@c_storerkey)  
      AND SKU.SKU = dbo.fnc_RTrim(@c_sku)  
                
      IF ISNULL(@n_ConsigneeShelfLife, 0) > 0  
      BEGIN  
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, @n_ConsigneeShelfLife ' +  
           ' * -1, Lottable04) >= GetDate() '              
      END  
      ELSE IF ISNULL(@n_SkuOutgoingShelfLife, 0) > 0  
      BEGIN  
         SELECT @c_LimitString = dbo.fnc_RTrim(@c_LimitString) + ' AND DATEADD (Day, @n_SkuOutgoingShelfLife ' +  
          ' * -1, Lottable04) >= GetDate() '    
      END         
                   
      SET @b_success = 0  
      EXECUTE dbo.nspGetRight @c_facility  
         ,  @c_Storerkey                     -- Storerkey  
         ,  NULL                             -- Sku  
         ,  'AllocateByConsNewExpiry'        -- Configkey  
         ,  @b_Success                 OUTPUT  
         ,  @c_AllocateByConsNewExpiry OUTPUT   
         ,  @n_Err                     OUTPUT  
         ,  @c_errmsg                  OUTPUT  

      IF ISNULL(@c_AllocateByConsNewExpiry,'') = '1' AND ISNULL(@c_Consigneekey,'') <> '' AND ISNULL(@c_ConSusr1 ,'') IN('Y','nspPRTH01')  
      BEGIN  
         SELECT @c_FromTableJoin = ' LEFT JOIN CONSIGNEESKU WITH (NOLOCK) ON (CONSIGNEESKU.Consigneekey = RTRIM(ISNULL(@c_Consigneekey,'''')) ) '  
                                                           +  ' AND (CONSIGNEESKU.ConsigneeSku = LOT.Sku) '  
         SELECT @c_Where = ' AND (LOTATTRIBUTE.Lottable04 >= ISNULL(CONSIGNEESKU.AddDate,CONVERT(DATETIME,''19000101''))) '         
      END  
      
      --NJOW02 S
      SELECT TOP 1 @C_FullLineAlloc = ISNULL(CL.Code,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'PKCODECFG'
      AND CL.Long = 'nspPR_PH09'
      AND CL.Code = 'FULLLINEALLOC'
      AND CL.Storerkey = @c_storerkey
      AND CL.Short = 'Y'
      AND (CL.Code2 = @c_Facility OR CL.Code2 = '')      

      IF @c_UOM IN('2','6') AND ISNULL(@c_SortMode,'') <> 'LEFO' AND ISNULL(@c_FullLineAlloc,'') = 'FULLLINEALLOC'
      BEGIN
         SELECT @c_LimitString =  dbo.fnc_RTrim(@c_LimitString) + ' AND LOC.LocationType IN (''CASE'',''PICK'') '
      END
      
      IF ISNULL(@c_FullLineAlloc,'') = 'FULLLINEALLOC' AND @c_OrdDetUserdefine02 IN('S','K')
      BEGIN      	       	 
         SELECT @c_SQLStmt  = 'SELECT @n_QtyAvai = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) ' +  
         ' FROM LOTXLOCXID (NOLOCK) ' +  
         ' JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT ' +  
         ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +  
         ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +  
         ' JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +    
         ' JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku AND LOTXLOCXID.Loc = SKUXLOC.Loc ' +    
          RTRIM(@c_FromTableJoin) + ' ' +  
         ' WHERE LOTXLOCXID.StorerKey = @c_storerkey ' +  
         ' AND LOTXLOCXID.SKU = @c_sku ' +  
         ' AND LOTXLOCXID.Qty > 0 ' +  
         ' AND LOT.Status = ''OK'' ' +  
         ' AND LOC.Facility = @c_facility ' +  
         ' AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +  
         ' AND ID.Status = ''OK'' ' +               
          RTRIM(@c_Where) +  ' ' +  
          RTRIM(@c_LimitString)   

         SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU NVARCHAR(20), ' +     
            '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +  
            '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +  
            '@c_Lottable06 NVARCHAR(30), ' +  
            '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' +   
            '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' +   
            '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +  
            '@n_ConsigneeShelfLife INT, @n_SkuOutgoingShelfLife INT , @n_uombase INT, @c_Consigneekey NVARCHAR(15), @n_QtyAvai INT OUTPUT'       
           
         EXEC sp_ExecuteSQL @c_SQLStmt, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                            @d_Lottable04, @d_Lottable05,  @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09,   
                            @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,    
                            @n_ConsigneeShelfLife , @n_SkuOutgoingShelfLife, @n_uombase, @c_Consigneekey, @n_QtyAvai OUTPUT            
         
         IF @n_OrderLineQty > @n_QtyAvai
         BEGIN
         	  DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
         	    SELECT TOP 0 NULL, NULL, NULL, 0
         	  RETURN  
         END
      END
      --NJOW02 E
            
       -- Form Preallocate cursor  
      SELECT @c_SQLStmt = 'DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +  
      ' SELECT LOT.StorerKey, LOT.SKU, LOT.LOT, ' +  
      ' QtyAvailable = SUM(LOTXLOCXID.Qty-LOTXLOCXID.QtyAllocated-LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) ' +   --WL02
      ' FROM LOTXLOCXID (NOLOCK) ' +  
      ' JOIN LOT (NOLOCK) ON LOTXLOCXID.LOT = LOT.LOT ' +  
      ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTXLOCXID.LOT = LOTATTRIBUTE.LOT ' +  
      ' JOIN LOC (NOLOCK) ON LOTXLOCXID.LOC = LOC.LOC ' +  
      ' JOIN ID (NOLOCK) ON LOTXLOCXID.ID = ID.ID ' +    
      ' JOIN SKUXLOC (NOLOCK) ON LOTXLOCXID.Storerkey = SKUXLOC.Storerkey AND LOTXLOCXID.Sku = SKUXLOC.Sku AND LOTXLOCXID.Loc = SKUXLOC.Loc ' +    
      ' LEFT OUTER JOIN (SELECT P.LOT, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +  
      '       FROM   PREALLOCATEPICKDETAIL P (NOLOCK), ORDERS (NOLOCK) ' +  
      '       WHERE  P.Orderkey = ORDERS.OrderKey ' +  
      '       AND    P.StorerKey = @c_storerkey ' +   
      '       AND    P.SKU = @c_sku ' +  
      '       AND    P.Qty > 0 ' +   
      -- '       AND    P.UOM = N''' + dbo.fnc_RTrim(@c_UOM) + ''' ' +  
      '       GROUP BY P.LOT, ORDERS.Facility) P ON LOTXLOCXID.LOT = P.LOT AND P.Facility = LOC.Facility ' +  
       RTRIM(@c_FromTableJoin) + ' ' +  
      ' WHERE LOTXLOCXID.StorerKey = @c_storerkey ' +  
      ' AND LOTXLOCXID.SKU = @c_sku ' +  
      ' AND LOTXLOCXID.Qty > 0 ' +  
      ' AND LOT.Status = ''OK'' ' +  
      ' AND LOC.Facility = @c_facility ' +  
      ' AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +  
      ' AND ID.Status = ''OK'' ' +     
       RTRIM(@c_Where) +  ' ' +  
       RTRIM(@c_LimitString) + ' ' +  
       CASE WHEN @c_UOM = '1' THEN
         ' GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, LOC.LocationType, LOC.LogicalLocation, LOC.Loc ' 
       ELSE    
         ' GROUP BY LOT.StorerKey, LOT.SKU, LOT.LOT, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable02, CASE WHEN LOTATTRIBUTE.LOTTABLE04 IS NULL OR LOTATTRIBUTE.LOTTABLE04 = ''1900-01-01'' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END, LOC.LocationType ' 
       END +  
       CASE WHEN @c_SortMode = 'ADISORT' THEN ', LOTATTRIBUTE.LOTTABLE05 ' ELSE '' END +   --WL01
      ' HAVING SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated - LOTXLOCXID.QtyPicked-LOTXLOCXID.QtyReplen) - MIN(ISNULL(P.QtyPreallocated, 0)) >= @n_uombase ' +   --WL02  
      RTRIM(@c_OrderBy)  
      
  --   EXEC (@c_SQLStmt)  
  
      SET @c_SQLParm =  N'@c_facility   NVARCHAR(5),  @c_storerkey  NVARCHAR(15), @c_SKU        NVARCHAR(20), ' +     
         '@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), ' +  
         '@c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME,     @d_Lottable05 DATETIME,  ' +  
         '@c_Lottable06 NVARCHAR(30), ' +  
         '@c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' +   
         '@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), ' +   
         '@d_Lottable13 DATETIME,     @d_Lottable14 DATETIME,     @d_Lottable15 DATETIME, ' +  
         '@n_ConsigneeShelfLife INT, @n_SkuOutgoingShelfLife INT , @n_uombase INT, @c_Consigneekey NVARCHAR(15)'       
        
      EXEC sp_ExecuteSQL @c_SQLStmt, @c_SQLParm, @c_facility, @c_storerkey, @c_SKU,  @c_Lottable01, @c_Lottable02, @c_Lottable03,  
                         @d_Lottable04, @d_Lottable05,  @c_Lottable06, @c_Lottable07, @c_Lottable08,@c_Lottable09,   
                         @c_Lottable10, @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15,    
                         @n_ConsigneeShelfLife , @n_SkuOutgoingShelfLife, @n_uombase, @c_Consigneekey    
  
     IF @b_debug = 1 
        PRINT @c_SQLStmt       
    END  
END  

GO