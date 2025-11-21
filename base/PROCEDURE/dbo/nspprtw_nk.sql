SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: nspPRTW_NK                                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: New Strategy for NIKE                                       */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 29-Oct-2013  NJOW01  1.0  292744-Sorting depend on                   */
/*                           loadplan.LoadPickmethod.                   */
/* 06-Nov-2015  NJOW02  1.1  356220-exclude empty lottable02 filter by  */
/*                           codelkup config                            */
/* 21-Nov-2016  NJOW03  1.2  WMS-666 Allocation by floor                */  
/* 24-Jan-2017  NJOW04  1.3  WMS-905 Additional filtering condition for */
/*                           lottable01 and lottable11                  */
/* 02-May-2017  NJOW05  1.4  WMS-1765 Add lottable06 filtering logic    */
/* 06-Jun-2017  NJOW06  1.5  WMS-1914 Add sorting logic                 */
/* 12-Oct-2017  SPChin  1.6  INC0021705 - Add Filter By StorerKey       */
/* 04-Dec-2017  CSCHONG 1.7  WMS-3481-revise available qty logic (CS01) */
/* 23-Jul-2021  NJOW07  1.8  WMS-17543 Lottable12 filtering changes     */
/* 23-Jul-2021  NJOW07  1.8  DEVOPS Combine script                      */
/************************************************************************/

CREATE PROC  [dbo].[nspPRTW_NK] 
@c_storerkey NVARCHAR(15) ,
@c_sku NVARCHAR(20) ,
@c_lot NVARCHAR(10) ,
@c_lottable01 NVARCHAR(18) ,
@c_lottable02 NVARCHAR(18) ,
@c_lottable03 NVARCHAR(18) ,
@d_lottable04 datetime ,
@d_lottable05 datetime ,
@c_lottable06 NVARCHAR(30),
@c_lottable07 NVARCHAR(30),
@c_lottable08 NVARCHAR(30),
@c_lottable09 NVARCHAR(30),
@c_lottable10 NVARCHAR(30),
@c_lottable11 NVARCHAR(30),
@c_lottable12 NVARCHAR(30),
@d_lottable13 datetime ,
@d_lottable14 datetime ,
@d_lottable15 datetime ,
@c_uom NVARCHAR(10) , 
@c_facility NVARCHAR(10)  ,  -- added By Ricky for IDSV5
@n_uombase int ,
@n_qtylefttofulfill int,
@c_OtherParms NVARCHAR(200) = '' --NJOW01
AS
BEGIN
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON 
   
   DECLARE @n_StorerMinShelfLife int,
           @c_Condition NVARCHAR(2000), 
           @c_Orderkey NVARCHAR(10),  --NJOW01
           @c_LocType NVARCHAR(10), --NJOW01           
           @c_nofilteremptylot2 NVARCHAR(10), --NJOW02
           @c_LoadPickMethod NVARCHAR(10),--NJOW03
           @c_Orderby NVARCHAR(2000), --NJOW06
           @c_CaseCond NVARCHAR(2000), --NJOW06
           @n_cnt INT

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
      BEGIN
         /* Get Storer Minimum Shelf Life */
         SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)
         FROM   STORER (NOLOCK)
         WHERE  STORERKEY = @c_lottable03
  
         SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)
         FROM  Sku (nolock)
         WHERE Sku.Sku = @c_SKU
         AND   Sku.Storerkey = @c_Storerkey

         DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY 
         FOR 
         SELECT LOT.STORERKEY,LOT.SKU,LOT.LOT ,
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED) - LOTXLOCXID.QtyReplen  --CS01
         FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)
         WHERE LOT.LOT = LOTATTRIBUTE.LOT  
      	 AND LOTXLOCXID.Lot = LOT.LOT
      	 AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT
      	 AND LOTXLOCXID.LOC = LOC.LOC
      	 AND LOC.Facility = @c_facility
      	 AND LOT.LOT = @c_lot 
         AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate() 
         ORDER BY Lotattribute.Lottable04, Lot.Lot

      END
   ELSE
      BEGIN      	      	      	
         /* Get Storer Minimum Shelf Life */
         /* Lottable03 = Consignee Key */
         SET @c_condition = ''
                  
         SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)
         FROM   STORER (NOLOCK)
         WHERE  STORERKEY = dbo.fnc_RTrim(@c_lottable03)

         SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)
         FROM  Sku (nolock)
         WHERE Sku.Sku = @c_SKU
         AND   Sku.Storerkey = @c_Storerkey

         IF @n_StorerMinShelfLife IS NULL
            SELECT @n_StorerMinShelfLife = 0

         -- lottable01 is used for loc.HostWhCode -- modified by Jeff
         IF ISNULL(@c_Lottable01,'') <> '' 
         BEGIN
            SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOC.HostWhCode = N''' + RTRIM(ISNULL(@c_Lottable01,'')) + ''' '
         END
         BEGIN
         	  --NJOW04
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT1'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW_NK'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
              SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE01 = '''' '
            END
         END

         IF ISNULL(@c_Lottable02,'') <> '' 
         BEGIN
            SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE02 = N''' + RTRIM(ISNULL(@c_Lottable02,'')) + ''' '
         END
         ELSE
         BEGIN
         	  --NJOW02
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT2'
         	                 AND CL.Listname = 'PKCODECFG' 
         	                 AND CL.Long = 'nspPRTW_NK'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
              SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE02 = '''' '
            END
         END

         IF CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL
            BEGIN
               SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE04 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + ''' '
            END

         IF CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL
            BEGIN
               SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE05 = N''' + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + ''' '
            END
         
         --NJOW04   
         IF ISNULL(@c_Lottable11,'') <> '' 
         BEGIN
            SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE11 = N''' + RTRIM(ISNULL(@c_Lottable11,'')) + ''' '
         END
         ELSE
         BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT11'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW_NK'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
              SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE11 = '''' '
            END
         END            

         --NJOW07  
         IF ISNULL(@c_Lottable12,'') <> '' 
         BEGIN
            SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE12 = N''' + RTRIM(ISNULL(@c_Lottable12,'')) + ''' '
         END
         ELSE
         BEGIN
         	  IF NOT EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                 WHERE CL.Storerkey = @c_Storerkey
         	                 AND CL.Code = 'NOFILTEREMPTYLOT12'
         	                 AND CL.Listname = 'PKCODECFG'
         	                 AND CL.Long = 'nspPRTW_NK'
         	                 AND ISNULL(CL.Short,'') <> 'N') 
         	  BEGIN              
              SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND LOTTABLE12 = '''' '
            END
         END            

         -- if lottable04 is blank, then get candidate based on expiry date based on the following conversion.
         IF @n_StorerMinShelfLife <> 0 
            BEGIN
               IF CONVERT(char(10), @d_Lottable04, 103) = '01/01/1900' OR @d_Lottable04 IS NULL
                  BEGIN
                     SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' AND ( DateAdd(Day, ' + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ', Lotattribute.Lottable04) > GetDate() ' 
                     SELECT @c_Condition = RTRIM(ISNULL(@c_Condition,'')) + ' OR Lotattribute.Lottable04 IS NULL ) '
                  END
            END

            --SELECT @c_condition = dbo.fnc_RTrim(@c_Condition) + ' ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot'

      	    --NJOW01
      	    IF ISNULL(@c_OtherParms,'') <> ''
   		      BEGIN
   		      	 SET @n_cnt = 0
   			       SELECT @c_OrderKey = LEFT(LTRIM(@c_OtherParms), 10)
   			       
   			       SELECT @c_LocType = CL.Short, 
   			              @c_LoadPickMethod = ISNULL(L.LoadPickMethod,''),  --NJOW03
   			              @n_cnt = CASE WHEN CL.Code IS NOT NULL THEN 1 ELSE 0 END
   			       FROM ORDERS O (NOLOCK) 
   			       JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey
   			       LEFT JOIN CODELKUP CL (NOLOCK) ON L.LoadPickMethod = CL.Code AND CL.Listname = 'LPPICKMTD' AND O.Storerkey = CL.Storerkey
   			       WHERE O.Orderkey = @c_OrderKey 
   			       
   			       --SET @n_cnt = @@ROWCOUNT
   			       
   			       --NJOW06
   			       SET @c_OrderBy = ' ORDER BY '
   			       SET @c_Casecond = ''
   			       IF EXISTS (SELECT 1 FROM CODELKUP(NOLOCK) 
                          WHERE LISTNAME = 'NIKALC' 
                          AND Storerkey = @c_Storerkey)
               BEGIN
   			          IF @c_LoadPickMethod = 'L-ORDER' 
   			          BEGIN
                     SET @c_casecond = ' CASE LOC.PutawayZone '
                     SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF01) AS NVARCHAR)  
                     FROM CODELKUP(NOLOCK) 
                     WHERE LISTNAME = 'NIKALC'
                     AND Storerkey = @c_Storerkey	--INC0021705
                     ORDER BY UDF01
                     SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
   			          END   			          			       
   			          ELSE IF @c_LoadPickMethod = 'R-ORDER'
   			          BEGIN
                     SET @c_casecond = ' CASE LOC.PutawayZone '
                     SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF02) AS NVARCHAR)  
                     FROM CODELKUP(NOLOCK) 
                     WHERE LISTNAME = 'NIKALC'
                     AND Storerkey = @c_Storerkey	--INC0021705
                     ORDER BY UDF02
                     SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
   			          END
   			          ELSE
   			          BEGIN
                     SET @c_casecond = ' CASE LOC.PutawayZone '
                     SELECT @c_casecond = @c_casecond +' WHEN ''' + RTRIM(code) + ''' THEN ' + CAST(ROW_NUMBER() OVER(ORDER BY UDF03) AS NVARCHAR)  
                     FROM CODELKUP(NOLOCK) 
                     WHERE LISTNAME = 'NIKALC'
                     AND Storerkey = @c_Storerkey	--INC0021705
                     ORDER BY UDF03
                     SET @c_casecond = @c_casecond + ' ELSE 99 END '   			       	   			          
   			          END
   			       END
   			       IF ISNULL(@c_casecond,'') <> ''
   			          SET @c_OrderBy = @c_OrderBy + @c_Casecond + ', '
   			       
   			       IF @n_cnt = 0
   			       BEGIN
                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 '
                  
                  --NJOW06
                  IF ISNULL(@c_casecond,'') <> ''
                     SET @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ',' + @c_Casecond 
                  
                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  '
                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + @c_Orderby + ' CASE WHEN LOTATTRIBUTE.Lottable06 = ''' + RTRIM(ISNULL(@c_lottable06,'')) +''' THEN 1 ELSE 2 END, LOTATTRIBUTE.Lottable04, LOT.Lot'  --NJOW05
               END
               ELSE IF ISNULL(@c_LocType,'') <> ''
               BEGIN
                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 '

                  --NJOW06
                  IF ISNULL(@c_casecond,'') <> ''
                     SET @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ',' + @c_Casecond 

                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  '
                  SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + @c_Orderby +' CASE WHEN LOTATTRIBUTE.Lottable06 = ''' + RTRIM(ISNULL(@c_lottable06,'')) +''' THEN 1 ELSE 2 END, ' +
                                                                     'CASE WHEN MIN(LOC.LocationType) = ''' +RTRIM(@c_LocType)+ ''' THEN 0 ELSE 1 END,LOT.Lot' --NJOW05                                 
               END
               ELSE
               BEGIN
   		      	    IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK)
         	                   WHERE CL.Storerkey = @c_Storerkey
         	                   AND CL.Code = 'ALLOCBYFLOOR'
         	                   AND CL.Listname = 'PKCODECFG'
         	                   AND CL.Long = 'nspPRTW_NK'
         	                   AND ISNULL(CL.Short,'') <> 'N') AND @c_LoadPickMethod <> 'L-ORDER'  --NJOW03
         	        BEGIN         	        	
                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, ISNULL(LOC.Floor,''''), LOTATTRIBUTE.Lottable06 '

                     --NJOW06
                     IF ISNULL(@c_casecond,'') <> ''
                        SET @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ',' + @c_Casecond 

                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  '
                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + @c_Orderby + ' CASE WHEN LOTATTRIBUTE.Lottable06 = ''' + RTRIM(ISNULL(@c_lottable06,'')) +''' THEN 1 ELSE 2 END, ISNULL(LOC.Floor,'''') DESC, LOT.Lot' --NJOW05               
         	        END
         	        ELSE 
         	        BEGIN         	        	          
                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 '

                     --NJOW06
                     IF ISNULL(@c_casecond,'') <> ''
                        SET @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ',' + @c_Casecond 

                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  '
                     SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + @c_Orderby + ' CASE WHEN LOTATTRIBUTE.Lottable06 = ''' + RTRIM(ISNULL(@c_lottable06,'')) +''' THEN 1 ELSE 2 END, LOT.Lot' --NJOW05              
                  END
               END
   		      END
   		      ELSE
   		      BEGIN
               SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable06 '
               SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  '
               SELECT @c_condition = RTRIM(ISNULL(@c_Condition,'')) + ' ORDER BY CASE WHEN LOTATTRIBUTE.Lottable06 = ''' + RTRIM(ISNULL(@c_lottable06,'')) +''' THEN 1 ELSE 2 END, LOTATTRIBUTE.Lottable04, LOT.Lot'  --NJOW05 		        
            END

            EXEC (' DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
            ' SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, ' +
            ' QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) -MIN(LOTXLOCXID.QtyReplen) ' +    --CS01
            ' FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK) ' +
            ' WHERE LOT.STORERKEY = N''' + @c_storerkey + ''' ' +
            ' AND LOT.SKU = N''' + @c_SKU + ''' ' +
            ' AND LOT.STATUS = ''OK'' ' +
            ' AND LOT.LOT = LOTATTRIBUTE.LOT ' +
            ' AND LOT.LOT = LOTXLOCXID.Lot ' +
            ' AND LOTXLOCXID.Loc = LOC.Loc ' +
            ' AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot ' + 
            ' AND LOTXLOCXID.ID = ID.ID ' +
            ' AND ID.STATUS <> ''HOLD'' ' +  
            ' AND LOC.Status = ''OK'' ' + 
	          ' AND LOC.Facility = N''' + @c_facility + ''' ' +
            ' AND LOC.LocationFlag <> ''HOLD'' ' +
            ' AND LOC.LocationFlag <> ''DAMAGE'' ' +
            @c_Condition  ) 

   END
END     

GO