SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPRTW08                                         */
/* Creation Date: 23-07-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: New Preallocation Strategy for E1 CN SOS181973              */
/*                                                                      */
/* Called By: Exceed Allocate Orders                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver Purposes                                    */
/* 27-Dec-2011  SHONG   1.2 SOS233234	- Include Pallet UOM	            */
/* 26-Mar-2013  TLTING01 1.3 Add new Parameter default value            */
/************************************************************************/
CREATE PROC  [dbo].[nspPRTW08]    
@c_storerkey NVARCHAR(15) ,    
@c_sku NVARCHAR(20) ,    
@c_lot NVARCHAR(10) ,    
@c_lottable01 NVARCHAR(18) ,    
@c_lottable02 NVARCHAR(18) ,    
@c_lottable03 NVARCHAR(18) ,    
@d_lottable04 datetime ,    
@d_lottable05 datetime ,    
@c_UOM        NVARCHAR(10) ,     
@c_Facility   NVARCHAR(10)  ,   
@n_UOMBase    int ,    
@n_QtyLeftToFulfill INT,
@c_OtherParms NVARCHAR(200)      = ''
AS    
BEGIN    
    
  SET NOCOUNT ON    
    
   DECLARE @n_StorerMinShelfLife int,    
           @c_Condition          NVARCHAR(MAX)    
           
	-- Get MinShelfLife  
	DECLARE @n_MinShelfLife		int,  
			  @n_Factor				FLOAT,  
			  @n_LeadTime			FLOAT, 
			  @n_Code				int, 
			  @n_PackQTY			FLOAT,
			  @c_OrderUOM		 NVARCHAR(10), 
			  @c_Userdefine03	 NVARCHAR(18), 
			  @c_LimitString     nvarchar(1000)  
			             
    
   IF ISNULL(RTRIM(@c_lot),'') <> '' AND LEFT(@c_LOT,1) <> '*'   
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
         QTYAVAILABLE = (LOT.QTY - LOT.QTYALLOCATED - LOT.QTYPICKED - LOT.QTYPREALLOCATED)    
         FROM LOT (Nolock), Lotattribute (Nolock), LOTXLOCXID (NOLOCK), LOC (NOLOCK)     
         WHERE LOT.LOT = LOTATTRIBUTE.LOT      
        AND LOTXLOCXID.Lot = LOT.LOT    
        AND LOTXLOCXID.LOT = LOTATTRIBUTE.LOT    
        AND LOTXLOCXID.LOC = LOC.LOC    
        AND LOC.Facility = @c_Facility    
        AND LOT.LOT = @c_lot     
         AND DateAdd(Day, @n_StorerMinShelfLife, Lotattribute.Lottable04) > GetDate()     
         ORDER BY Lotattribute.Lottable04, Lot.Lot    
    
   END    
   ELSE    
   BEGIN    
      /* Get Storer Minimum Shelf Life */    
      /* Lottable03 = Consignee Key */    
      SELECT @n_StorerMinShelfLife = ISNULL(Storer.MinShelflife, 0)    
      FROM   STORER (NOLOCK)    
      WHERE  STORERKEY = RTRIM(@c_lottable03)    
 
      SELECT @n_StorerMinShelfLife = ((ISNULL(Sku.Shelflife,0) * @n_StorerMinShelfLife /100) * -1)    
      FROM  Sku (nolock)    
      WHERE Sku.Sku = @c_SKU    
      AND   Sku.Storerkey = @c_Storerkey    
 
      IF LEFT(@c_lot, 1) = '*' AND ISNUMERIC(SUBSTRING(@c_LOT, 2, LEN(@c_LOT) - 1)) = 1
      BEGIN
      	SET @c_Limitstring = ''
      	
         SET @n_MinShelfLife = SUBSTRING(@c_LOT, 2, LEN(@c_LOT) - 1)
         SET @n_Code = 0
         
		   SELECT @n_Factor		  = CONVERT(FLOAT, ISNULL(RTRIM(CODELKUP.Short), 0)),
				    @n_LeadTime	  = CONVERT(FLOAT, ISNULL(RTRIM(CODELKUP.Long), 0)),
				    @n_Code			  = CONVERT(INT, ISNULL(RTRIM(CODELKUP.Code), 0))
		   FROM   CODELKUP (NOLOCK)  
		   WHERE CODELKUP.Code = SUBSTRING(@c_LOT, 2, LEN(@c_LOT) - 1) 
		   AND CODELKUP.LISTNAME = 'SHELFLIFE'
	      AND ISNUMERIC(ISNULL(CODELKUP.Short, 0)) = 1 
	      AND ISNUMERIC(ISNULL(CODELKUP.Long, 0))  = 1
   			  
         IF @n_StorerMinShelfLife IS NULL    
            SELECT @n_StorerMinShelfLife = 0    


		   IF @n_MinShelfLife = @n_Code AND @n_MinShelfLife > 0 
		   BEGIN   
			   SET @c_Limitstring = " AND DateAdd(Day, " + CAST(@n_Factor AS NVARCHAR(10)) 
                              + " * DATEDIFF(Day, LOTATTRIBUTE.Lottable01,LOTATTRIBUTE.lottable04) + " 
                              + CAST(@n_LeadTime AS NVARCHAR(10)) + ", GETDATE()) < LOTATTRIBUTE.Lottable04 " 
									   + " AND ISNULL(LOTATTRIBUTE.Lottable01, '0') <> '' " 
										+ " AND ISDATE(LOTATTRIBUTE.Lottable01) = 1 " 

		   END   
      END
		
      -- lottable01 is used for loc.HostWhCode -- modified by Jeff    
      IF ISNULL(RTRIM(@c_Lottable01),'') <> ''  
      BEGIN    
         SELECT @c_Condition = " AND LOC.HostWhCode = N'" + ISNULL(RTRIM(@c_Lottable01),'') + "' "    
      END    
 
      IF ISNULL(RTRIM(@c_Lottable02),'') <> ''  
      BEGIN    
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE02 = N'" + ISNULL(RTRIM(@c_Lottable02),'') + "' "    
      END    
 
      IF CONVERT(char(10), @d_Lottable04, 103) <> "01/01/1900" AND @d_Lottable04 IS NOT NULL    
      BEGIN    
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE04 = N'" + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106)) + "' "    
      END    
 
      IF CONVERT(char(10), @d_Lottable05, 103) <> "01/01/1900" AND @d_Lottable05 IS NOT NULL    
      BEGIN    
         SELECT @c_Condition = RTRIM(@c_Condition) + " AND LOTTABLE05 = N'" + RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106)) + "' "    
      END    
 
      IF LEN(@c_Limitstring) > 0 
      BEGIN
      	SELECT @c_Condition = RTRIM(@c_Condition) + @c_Limitstring 
      END
      ELSE
      BEGIN
         -- if lottable04 is blank, then get candidate based on expiry date based on the following conversion.    
         IF @n_StorerMinShelfLife <> 0     
         BEGIN    
            IF CONVERT(char(10), @d_Lottable04, 103) = "01/01/1900" OR @d_Lottable04 IS NULL    
            BEGIN    
               SELECT @c_Condition = RTRIM(@c_Condition) + " AND ( DateAdd(Day, " + CAST(@n_StorerMinShelfLife AS NVARCHAR(10)) + ", Lotattribute.Lottable04) > GetDate() "     
               SELECT @c_Condition = RTRIM(@c_Condition) + " OR Lotattribute.Lottable04 IS NULL ) "    
            END    
         END          	
      END
 
         SELECT @c_condition = RTRIM(@c_Condition) + " GROUP BY LOT.StorerKey, LOT.Sku, LOT.Lot, LOTATTRIBUTE.Lottable04 "    
         SELECT @c_condition = RTRIM(@c_Condition) + " HAVING SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) > 0  "    
         SELECT @c_condition = RTRIM(@c_Condition) + " ORDER BY LOTATTRIBUTE.Lottable04, LOT.Lot"    
  
         EXEC (" DECLARE  PREALLOCATE_CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR " +    
         " SELECT LOT.STORERKEY, LOT.SKU, LOT.LOT, " +    
         " QTYAVAILABLE = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED) - MIN(LOT.QTYPREALLOCATED) " +     
         " FROM LOTATTRIBUTE (NOLOCK), LOT (NOLOCK), LOTXLOCXID (nolock), LOC (Nolock), ID (NOLOCK) " +    
         " WHERE LOT.STORERKEY = N'" + @c_storerkey + "' " +    
         " AND LOT.SKU = N'" + @c_SKU + "' " +    
         " AND LOT.STATUS = 'OK' " +    
         " AND LOT.LOT = LOTATTRIBUTE.LOT " +    
         " AND LOT.LOT = LOTXLOCXID.Lot " +    
         " AND LOTXLOCXID.Loc = LOC.Loc " +    
         " AND LOTXLOCXID.Lot = LOTATTRIBUTE.Lot " +     
         " AND LOTXLOCXID.ID = ID.ID " +    
         " AND ID.STATUS <> 'HOLD' " +      
         " AND LOC.Status = 'OK' " +     
         " AND LOC.Facility = N'" + @c_Facility + "' " +    
         " AND LOC.LocationFlag <> 'HOLD' " +    
         " AND LOC.LocationFlag <> 'DAMAGE' " +    
         @c_Condition  )     

   END    
END   


GO