SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: nspPR_TH10                                          */
/* Creation Date: 27-Apr-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-19416 - TH RMBL Allocate LOC = OVER3183 for certain      */
/*          condition                                                    */
/*          Pre-Allocation Strategy of RMBL (FIFO)                       */
/*          Notes: Turn on configkey 'OrderInfo4Preallocation'           */
/*                                                                       */
/* Called By: nspPrealLOCateOrderProcessing                              */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author     Ver   Purposes                                */
/* 27-Apr-2022  WLChooi    1.0   DevOps Combine Script                   */
/*************************************************************************/

CREATE PROC [dbo].[nspPR_TH10]
   @c_storerkey NVARCHAR(15) ,
   @c_sku NVARCHAR(20) ,
   @c_lot NVARCHAR(10) ,
   @c_lottable01 NVARCHAR(18) ,
   @c_lottable02 NVARCHAR(18) ,
   @c_lottable03 NVARCHAR(18) ,
   @d_lottable04 DATETIME ,
   @d_lottable05 DATETIME ,
   @c_lottable06 NVARCHAR(30) ,
   @c_lottable07 NVARCHAR(30) ,
   @c_lottable08 NVARCHAR(30) ,
   @c_lottable09 NVARCHAR(30) ,
   @c_lottable10 NVARCHAR(30) ,
   @c_lottable11 NVARCHAR(30) ,
   @c_lottable12 NVARCHAR(30) ,
   @d_lottable13 DATETIME ,    
   @d_lottable14 DATETIME ,    
   @d_lottable15 DATETIME ,    
   @c_uom NVARCHAR(10) ,
   @c_facility NVARCHAR(5),    
   @n_uombase INT ,
   @n_qtylefttofulfill INT,
   @c_OtherParms NVARCHAR(200)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StorerMinShelfLife INT,
           @c_Condition NVARCHAR(4000),
           @c_SQLStatement NVARCHAR(3999) 

   DECLARE @c_Orderkey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_ID              NVARCHAR(18),
           @c_OrderType       NVARCHAR(50)
           
   DECLARE @c_SQLParms        NVARCHAR(4000) = ''                                               

   IF LEN(@c_OtherParms) > 0 
   BEGIN
      SELECT @c_Orderkey = LEFT(@c_OtherParms, 10)
      SELECT @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      
      SELECT @c_ID = ID
      FROM ORDERDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND OrderLineNumber = @c_OrderLineNumber    
        
      SELECT @c_OrderType = ISNULL(OH.[Type],'')
      FROM ORDERS OH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
   END
   
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock), Lot (nolock)
      WHERE Lot.Lot = @c_lot
      AND Lot.Sku = Sku.Sku
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility 
      
      DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
      QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)
      FROM LOT (NOLOCK), Lotattribute (NOLOCK)
      WHERE LOT.LOT = @c_lot 
      AND Lot.Lot = Lotattribute.Lot 
      AND DATEADD(DAY, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GETDATE() 
      ORDER BY Lotattribute.Lottable05, Lot.Lot
   END
   ELSE
   BEGIN
      /* Get Storer Minimum Shelf Life */
      SELECT @n_StorerMinShelfLife = ((Sku.Shelflife * Storer.MinShelflife/100) * -1)
      FROM Sku (nolock), Storer (nolock)
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey   
      AND Sku.Storerkey = Storer.Storerkey
      AND Sku.Facility = @c_facility  
   
      IF @n_StorerMinShelfLife IS NULL
         SELECT @n_StorerMinShelfLife = 0
   
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable01)) <> '' AND @c_Lottable01 IS NOT NULL
      BEGIN
         SELECT @c_Condition = ' AND LOTTABLE01 = @c_Lottable01 '                                  
      END
      ELSE   
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT01'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = ' AND LOTTABLE01 = '''' '
         END
      END
      
      
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable02)) <> '' AND @c_Lottable02 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE02 = @c_Lottable02 '    
      END
      ELSE   
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT02'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND LOTTABLE02 = '''' '
         END
      END
      
      
      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Lottable03)) <> '' AND @c_Lottable03 IS NOT NULL
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE03 = @c_Lottable03 '
      END
      ELSE   
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT03'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND LOTTABLE03 = '''' '
         END
      END
      
      IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE04 = @d_Lottable04 '
      END
      IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900'
      BEGIN
         SELECT @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND LOTTABLE05 = @d_Lottable05 ' 
      END

      IF RTRIM(@c_Lottable06) <> '' AND @c_Lottable06 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable06 = @c_Lottable06' 
      END  
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT06'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable06 = '''' '
         END
      END

      IF RTRIM(@c_Lottable07) <> '' AND @c_Lottable07 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable07 = @c_Lottable07'
      END  
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT07'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable07 = '''' '
         END
      END

      IF RTRIM(@c_Lottable08) <> '' AND @c_Lottable08 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable08 = @c_Lottable08'
      END  
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT08'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable08 = '''' '
         END
      END

      IF RTRIM(@c_Lottable09) <> '' AND @c_Lottable09 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable09 = @c_Lottable09'
      END   
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT09'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable09 = '''' '
         END
      END

      IF RTRIM(@c_Lottable10) <> '' AND @c_Lottable10 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable10 = @c_Lottable10' 
      END   
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT10'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable10 = '''' '
         END
      END

      IF RTRIM(@c_Lottable11) <> '' AND @c_Lottable11 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable11 = @c_Lottable11'
      END   
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT11'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable11 = '''' '
         END
      END

      IF RTRIM(@c_Lottable12) <> '' AND @c_Lottable12 IS NOT NULL
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable12 = @c_Lottable12'
      END  
      ELSE
      BEGIN 
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
                    WHERE CL.Storerkey = @c_Storerkey
                    AND CL.Code = 'FILTEREMPTYLOT12'
                    AND CL.Listname = 'PKCODECFG'
                    AND CL.Code2 = 'nspPR_TH10'
                    AND ISNULL(CL.Short,'') <> 'N') 
         BEGIN              
            SET @c_Condition = @c_Condition + ' AND Lottable12 = '''' '
         END
      END

      IF CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable13 = @d_Lottable13'
      END

      IF CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable14 = @d_Lottable14'
      END

      IF CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900'
      BEGIN
         SET @c_Condition = @c_Condition + ' AND Lottable15 = @d_Lottable15'
      END

      IF @n_StorerMinShelfLife > 0 
      BEGIN
         SET @c_Condition = dbo.fnc_RTrim(@c_Condition) + ' AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() '
      END 
   
      IF ISNULL(@c_ID,'') <> ''
      BEGIN
          SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTxLOCxID.Id = @c_ID '
      END

      IF @c_OrderType = 'SCPO' AND @c_Facility = '3181'
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTxLOCxID.LOC = ''OVER3183'' '
      END
      ELSE
      BEGIN
         SELECT @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOC.STATUS = ''OK'' '
      END

      SELECT @c_SQLStatement =  ' DECLARE PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
            ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, ' +
            ' QTYAVAILABLE = (SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) )  ' +
            ' FROM LOT WITH (NOLOCK) ' +
            ' JOIN LOTATTRIBUTE (NOLOCK) ON (LOT.lot = LOTATTRIBUTE.lot) ' +   
            ' JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT AND LOTxLOCxID.LOT = LOTATTRIBUTE.LOT) ' +    
            ' JOIN LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC) ' +    
            ' JOIN ID (NOLOCK) ON (LOTxLOCxID.ID = ID.ID) ' +        
            ' LEFT OUTER JOIN (SELECT P.lot, ORDERS.Facility, QtyPreallocated = SUM(P.Qty) ' +    
            '                FROM   PreallocatePickdetail P (NOLOCK) ' +
            '                JOIN   ORDERS (NOLOCK) ON P.Orderkey = ORDERS.Orderkey ' +  
            '                JOIN   ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey AND P.OrderLineNumber = ORDERDETAIL.OrderLineNumber ' + 
            '                WHERE  P.Storerkey = @c_storerkey ' +                                                                                       
            '                AND    P.SKU = @c_SKU ' +                                                                                                   
            '                AND    ORDERS.FACILITY = @c_facility ' +                                                                                         
            '                AND    P.qty > 0 ' +    
            CASE WHEN ISNULL(@c_ID,'') <> '' THEN ' AND ORDERDETAIL.ID = @c_ID ' ELSE ' ' END +                                   
            '                GROUP BY p.Lot, ORDERS.Facility) P ON LOTxLOCxID.Lot = P.Lot AND P.Facility = LOC.Facility ' +   
            ' WHERE LOT.STORERKEY = @c_storerkey ' +                                                                                                      
            ' AND LOT.SKU = @c_SKU ' +                                                                                                                   
            ' AND LOT.STATUS = ''OK''  ' +   
            ' AND ID.STATUS = ''OK'' ' +     
            ' AND LOC.LocationFlag = ''NONE'' ' +  
            ' AND LOC.Facility = @c_facility '  +                                                                                                        
            ISNULL(RTRIM(@c_Condition),'')  + 
            ' GROUP By LOT.STORERKEY, LOT.SKU, LOT.LOT, Lotattribute.Lottable05 ' +
            ' HAVING SUM(LOTxLOCxID.QTY) - SUM(LOTxLOCxID.QTYALLOCATED) - SUM(LOTxLOCxID.QTYPICKED) - MAX(ISNULL(P.QTYPREALLOCATED,0)) >= @n_UOMBase ' + 
            ' ORDER BY Lotattribute.Lottable05, LOT.Lot ' 

      SET @c_SQLParms= N'@c_facility   NVARCHAR(5)'
                        + ',@c_storerkey  NVARCHAR(15)'
                        + ',@c_SKU        NVARCHAR(20)'
                        + ',@c_Lottable01 NVARCHAR(18)'
                        + ',@c_Lottable02 NVARCHAR(18)'
                        + ',@c_Lottable03 NVARCHAR(18)'
                        + ',@d_lottable04 DATETIME'
                        + ',@d_lottable05 DATETIME'
                        + ',@c_Lottable06 NVARCHAR(30)'
                        + ',@c_Lottable07 NVARCHAR(30)'
                        + ',@c_Lottable08 NVARCHAR(30)'
                        + ',@c_Lottable09 NVARCHAR(30)'
                        + ',@c_Lottable10 NVARCHAR(30)'
                        + ',@c_Lottable11 NVARCHAR(30)'
                        + ',@c_Lottable12 NVARCHAR(30)'
                        + ',@d_lottable13 DATETIME'
                        + ',@d_lottable14 DATETIME'
                        + ',@d_lottable15 DATETIME'
                        + ',@n_StorerMinShelfLife INT'
                        + ',@n_UOMBase    INT'
                        + ',@c_ID NVARCHAR(18)'
      
      EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms, @c_facility, @c_storerkey, @c_SKU
                        ,@c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05
                        ,@c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10
                        ,@c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                        ,@n_StorerMinShelfLife, @n_UOMBase, @c_ID 
       
   END
END

GO