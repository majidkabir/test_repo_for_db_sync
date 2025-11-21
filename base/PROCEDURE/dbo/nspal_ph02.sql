SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspAL_PH02                                         */
/* Creation Date: 04-Oct-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-2958 PH BEVI Allocation Strategy                        */
/*                                                                      */
/* Called By: nspLoadOrderProcessing		                                */
/*            Skip Preallocation mush turn ON                           */
/*                                                                      */
/* PVCS Version: 1.0		                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 03/01/2018   NJOW01  1.0  WMS-2959 allocate uom from other loc type  */
/************************************************************************/
CREATE PROC [dbo].[nspAL_PH02]
   @c_LoadKey    NVARCHAR(10),  
   @c_Facility   NVARCHAR(5),     
   @c_StorerKey  NVARCHAR(15),     
   @c_SKU        NVARCHAR(20),    
   @c_Lottable01 NVARCHAR(18),    
   @c_Lottable02 NVARCHAR(18),    
   @c_Lottable03 NVARCHAR(18),    
   @d_Lottable04 DATETIME,    
   @d_Lottable05 DATETIME,    
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
   @c_UOM        NVARCHAR(10),    
   @c_HostWHCode NVARCHAR(10),    
   @n_UOMBase    INT,    
   @n_QtyLeftToFulfill INT,     
   @c_OtherParms NVARCHAR(200) = '', 
   @b_Debug INT = 0 
AS
BEGIN	
	--SET @b_Debug = 1
	
   DECLARE @c_SQLStmt                  NVARCHAR(MAX)
          ,@c_SQLParm                  NVARCHAR(4000) 
          ,@b_Success                  INT
          ,@n_Err                      INT
          ,@c_ErrMsg                   NVARCHAR(255)
          ,@c_LimitString              NVARCHAR(2000)
          ,@c_OrderBy                  NVARCHAR(1000)
          ,@c_DocKey                   NVARCHAR(10)
          ,@c_DocLineNumber            NVARCHAR(5)
          ,@n_SkuShelfLife             INT
          ,@n_SkuOutgoingShelfLife     INT	-- SKU.Busr6
          ,@n_ConsigneeShelfLife       INT = 0 
          ,@c_Lottable04label          NVARCHAR(20)
          ,@n_QtyAvailable             INT
          ,@n_LoadConsoAllocation      INT = 0 
          ,@c_ConsigneeKey             NVARCHAR(15) = '' 
          ,@c_MinShelfChecking         NVARCHAR(10) = ''
          ,@n_PalletCtn                INT = 0 
          ,@n_CaseCtn                  INT = 0 
				
	  SELECT @c_SQLStmt = '', @c_OrderBy = ''
	  SELECT @c_errmsg = '', @n_err = 0, @b_success = 0, @c_LimitString = '', 
	         @c_Lottable04Label = '', @n_SkuOutgoingShelfLife = 0, @n_SkuShelfLife = 0
 
                             	  	     
      IF ISNULL(@c_OtherParms,'') <> ''
     	BEGIN
     	   SELECT @c_DocKey = LEFT(LTRIM(@c_OtherParms), 10)
     	   SELECT @c_DocLineNumber = SUBSTRING(RTRIM(@c_OtherParms),11,5) 

         SET @c_ConsigneeKey = ''
         SET @n_ConsigneeShelfLife = 0           	          
         SET @n_LoadConsoAllocation = 0
          
         SELECT @n_LoadConsoAllocation = 1
         FROM   StorerConfig SC WITH (NOLOCK) 
         WHERE  SC.ConfigKey = 'LoadConsoAllocation' 
         AND  SC.sValue = '1' 
         AND  SC.StorerKey = @c_storerkey  
         AND (SC.Facility = @c_Facility OR ISNULL(SC.Facility,'') = '') 
            
         IF @n_LoadConsoAllocation = 1
         BEGIN
          	SELECT TOP 1 @c_ConsigneeKey = O.ConsigneeKey  
          	FROM   LoadplanDetail LPD WITH (NOLOCK) 
          	JOIN   ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey 
          	WHERE  LPD.LoadKey = @c_DocKey
         END
         ELSE 
         BEGIN
          	SELECT TOP 1 @c_ConsigneeKey = O.ConsigneeKey 
          	FROM   ORDERS O WITH (NOLOCK)  
          	WHERE  O.OrderKey = @c_DocKey          	
         END 
         IF @c_ConsigneeKey <> ''
         BEGIN
            SET @n_ConsigneeShelfLife = 0
             
            SELECT @n_ConsigneeShelfLife = ISNULL(s.MinShelfLife,0)
            FROM STORER AS s WITH (NOLOCK) 
            WHERE s.StorerKey = @c_ConsigneeKey 
         END     	        	    
     	END
     	 
   	SET @n_SkuOutgoingShelfLife = 0     	   
     	SET @n_SkuShelfLife = 0 
     	SET @c_Lottable04Label = ''
     	 
     	SELECT @n_SkuShelfLife = ISNULL(SKU.Shelflife, 0),
     	      @n_SkuOutgoingShelfLife = ISNULL( CAST( SKU.BUSR6 AS INT), 0),
     	      @c_Lottable04Label = ISNULL(SKU.Lottable04Label,''), 
     	      @n_PalletCtn = ISNULL(P.Pallet,0),  
     	      @n_CaseCtn   = ISNULL(P.CaseCnt,0)
     	FROM  SKU (NOLOCK) 
     	JOIN  PACK P WITH (NOLOCK) ON P.PACKKey = SKU.PACKKey 
     	WHERE SKU.StorerKey = @c_storerkey
     	AND SKU.SKU = @c_sku

    
      SET @c_Lottable01 = ISNULL(RTRIM(@c_Lottable01),'')
      SET @c_Lottable02 = ISNULL(RTRIM(@c_Lottable02),'')
      SET @c_Lottable03 = ISNULL(RTRIM(@c_Lottable03),'')
      SET @c_Lottable06 = ISNULL(RTRIM(@c_Lottable06),'')
      SET @c_Lottable07 = ISNULL(RTRIM(@c_Lottable07),'')
      SET @c_Lottable08 = ISNULL(RTRIM(@c_Lottable08),'')
      SET @c_Lottable09 = ISNULL(RTRIM(@c_Lottable09),'')
      SET @c_Lottable10 = ISNULL(RTRIM(@c_Lottable10),'')
      SET @c_Lottable11 = ISNULL(RTRIM(@c_Lottable11),'')
      SET @c_Lottable12 = ISNULL(RTRIM(@c_Lottable12),'')       
       
      IF @c_Lottable03 <> ''
      BEGIN
       	SET @c_MinShelfChecking = 'N'
       	 
       	SELECT @c_MinShelfChecking = ISNULL(UDF01, 'N') 
       	FROM CODELKUP AS c WITH(NOLOCK) 
       	WHERE c.LISTNAME = 'HOSTWHCODE' 
       	AND   c.Storerkey = @c_storerkey
       	AND   c.Code = @c_Lottable03 
       	 
       	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOC.HostWHCode = @c_Lottable03 '
      END

     	IF @b_Debug = 1
     	BEGIN
     		PRINT '   >>> 	SkuShelfLife: ' + CAST(@n_SkuShelfLife AS VARCHAR(10))
     	   PRINT '   >>> 	SkuOutgoingShelfLife: ' + CAST(@n_SkuOutgoingShelfLife AS VARCHAR(10))
     	   PRINT '   >>> 	SkuShelfLife: ' + CAST(@n_SkuShelfLife AS VARCHAR(10))
     	   PRINT '   >>> 	PalletCtn: ' + CAST(@n_PalletCtn AS VARCHAR(10))
     	   PRINT '   >>> 	CaseCtn: ' + CAST(@n_CaseCtn AS VARCHAR(10))
     	   PRINT '   >>> 	ConsigneeShelfLife: ' + CAST(@n_ConsigneeShelfLife AS VARCHAR(10))
     	   PRINT '   >>> 	MinShelfChecking: ' +@c_MinShelfChecking
     	   PRINT '   >>> 	Lottable04Label: ' +@c_Lottable04Label
     	END


     	IF @c_MinShelfChecking = 'Y' AND @c_Lottable04Label = 'EXP_DATE'	 
     	BEGIN
     		IF @n_ConsigneeShelfLife > 0  
     	 	   SET @n_SkuOutgoingShelfLife = @n_ConsigneeShelfLife
     	 	
     	 	SET @n_SkuShelfLife = 0 
     	END     	        	   
     	ELSE IF @c_MinShelfChecking = 'Y' AND @c_Lottable04Label = 'PRODN_DATE'
     	BEGIN
     		IF @n_ConsigneeShelfLife > 0  
     	 	   SET @n_SkuShelfLife = @n_ConsigneeShelfLife
     	   
     	 	SET @n_SkuOutgoingShelfLife = 0
     	END
     	ELSE 
     	BEGIN
     	   SET @n_SkuOutgoingShelfLife = 0    
     	   SET @n_SkuShelfLife = 0 	 	
     	END
     	
     		         
      IF @c_Lottable01 <> ''
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable01= @c_Lottable01 '       
	    
	  	IF @c_Lottable02 <> ' '  
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable02= @c_Lottable02 ' 
	               
	     	  	 
	  	IF @d_Lottable04 IS NOT NULL AND @d_Lottable04 <> '1900-01-01'
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable04 = @d_Lottable04 '  
	       
	  	IF @d_Lottable05 IS NOT NULL  AND @d_Lottable05 <> '1900-01-01'
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable05= @d_Lottable05 '  	  		

	  	IF ISNULL(RTRIM(@c_Lottable06),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable06= @c_Lottable06 '  

	  	IF ISNULL(RTRIM(@c_Lottable07),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable07= @c_Lottable07 '  

	  	IF ISNULL(RTRIM(@c_Lottable08),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable08= @c_Lottable08 '   

	  	IF ISNULL(RTRIM(@c_Lottable09),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable09= @c_Lottable09 '  

	  	IF ISNULL(RTRIM(@c_Lottable10),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable10= @c_Lottable10 '  

	  	IF ISNULL(RTRIM(@c_Lottable11),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable11= @c_Lottable11 '  

	  	IF ISNULL(RTRIM(@c_Lottable12),'') <> ' '  
	      SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable12= @c_Lottable12 '  

	  	IF @d_Lottable13 IS NOT NULL AND @d_Lottable13 <> '1900-01-01'
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable13 = @d_Lottable13 '  

	  	IF @d_Lottable14 IS NOT NULL AND @d_Lottable14 <> '1900-01-01'
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable14 = @d_Lottable14 '  

	  	IF @d_Lottable15 IS NOT NULL AND @d_Lottable15 <> '1900-01-01'
	  	SELECT @c_LimitString =  RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable15 = @d_Lottable15 '  
	  	 	
	  	IF @c_Lottable04Label = 'EXP_DATE'	 
	  	BEGIN
	  	   IF ISNULL(@n_SkuOutgoingShelfLife, 0) > 0
     	      SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND DATEADD (Day, ' +
     	    	   				RTRIM(CAST(@n_SkuOutgoingShelfLife as NVARCHAR(10))) + ' * -1, LOTATTRIBUTE.Lottable04) >= GetDate() '		
     	   ELSE
     	      SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND LOTATTRIBUTE.Lottable04 > GetDate() '		     	    	   				  
	  	END   

	  	IF @c_Lottable04Label = 'PRODN_DATE' AND ISNULL(@n_SkuShelfLife, 0) > 0
	  	BEGIN
     		SELECT @c_LimitString = RTRIM(@c_LimitString) + ' AND DATEADD (Day, ' +
     		  			   RTRIM(CAST(@n_SkuShelfLife as NVARCHAR(10))) + ', Lottable04) >= GetDate() '		
	  	END            
	  	
	IF @c_UOM = '1'  
	BEGIN
	  	SET @c_LimitString = 
	  	      RTRIM(@c_LimitString) +' AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) >= ' + 
	  	      CAST(@n_PalletCtn AS VARCHAR(10))  
	  	
	  	--NJOW01
	  	--SET @c_LimitString = RTRIM(@c_LimitString) + ' AND LOC.LocationType NOT IN (''PICK'',''CASE'') '	  	  
   	  SET @c_OrderBy =	' ORDER BY CASE WHEN LOC.LocationType NOT IN (''PICK'',''CASE'') THEN 1 WHEN LOC.LocationType =''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.Lottable04, LOT.LOT, LOTATTRIBUTE.Lottable05 '
	END
  	ELSE IF @c_UOM = '2'  
	BEGIN
	  	SET @c_LimitString = 
	  	      RTRIM(@c_LimitString) +' AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) >= ' + 
	  	      CAST(@n_CaseCtn AS VARCHAR(10))

      --NJOW01	  	        
	  	--SET @c_LimitString = RTRIM(@c_LimitString) + ' AND LOC.LocationType =''CASE'' '  
   	  SET @c_OrderBy =	' ORDER BY CASE WHEN LOC.LocationType =''CASE'' THEN 1 WHEN LOC.LocationType NOT IN (''PICK'',''CASE'') THEN 2 ELSE 3 END, LOTATTRIBUTE.Lottable04, LOT.LOT, LOTATTRIBUTE.Lottable05 '
	END
  	ELSE  IF @c_UOM = '6' 
	BEGIN
	  	SET @c_LimitString = 
	  	      RTRIM(@c_LimitString) +' AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) > 0 ' 
	  	
	  	--NJOW01
	  	--SET @c_LimitString = RTRIM(@c_LimitString) + ' AND LOC.LocationType =''PICK'' '  
   	  SET @c_OrderBy =	' ORDER BY CASE WHEN LOC.LocationType =''PICK'' THEN 1 WHEN LOC.LocationType =''CASE'' THEN 2 ELSE 3 END, LOTATTRIBUTE.Lottable04, LOT.LOT, LOTATTRIBUTE.Lottable05 '
	END  	   	
	ELSE 
   BEGIN
	  	SET @c_LimitString = 
	  	      RTRIM(@c_LimitString) +' AND (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) > 0 '      	

      --NJOW01
 	    SET @c_OrderBy =	' ORDER BY LOTATTRIBUTE.Lottable04, LOT.LOT, LOTATTRIBUTE.Lottable05 ' 
   END		
  	   
	--SET @c_OrderBy =	' ORDER BY LOTATTRIBUTE.Lottable04, LOT.LOT, LOTATTRIBUTE.Lottable05 ' --NJOW01 remarked
	  	     
    	SELECT @c_SQLStmt = 'DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR ' +
    	' SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC, LOTxLOCxID.ID, ' +
    	' QtyAvailable = (LOTxLOCxID.Qty-LOTxLOCxID.QtyAllocated-LOTxLOCxID.QtyPicked-LOTxLOCxID.QtyReplen), ' +
    	' N'''' ' + 
    	' FROM LOTxLOCxID (NOLOCK) ' +
	  	' JOIN LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT ' +
    	' JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.LOT = LOTATTRIBUTE.LOT ' +
    	' JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC ' +
      ' JOIN ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID ' +  
    	' WHERE LOTxLOCxID.StorerKey = @c_storerkey ' +
	  	' AND LOTxLOCxID.SKU = @c_sku ' +
	  	' AND LOT.Status = ''OK'' ' +
	  	' AND LOC.Facility = @c_facility ' +
    	' AND LOC.Status = ''OK'' AND LOC.LocationFlag = ''NONE'' ' +
      ' AND ID.Status = ''OK'' ' +        
      RTRIM(@c_LimitString) + ' ' +  
	   RTRIM(@c_OrderBy)
    
      SET @c_SQLParm = N'@c_Facility   NVARCHAR(5),  @c_StorerKey  NVARCHAR(15), ' +
                     N'@c_SKU        NVARCHAR(20), @c_Lottable01 NVARCHAR(18), ' +   
                     N'@c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), ' +   
                     N'@d_Lottable04 DATETIME,     @d_Lottable05 DATETIME, ' +   
                     N'@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), ' +    
                     N'@c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), ' +   
                     N'@c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30), ' +   
                     N'@c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, ' +   
                     N'@d_Lottable14 DATETIME,     @d_Lottable15 DATETIME '
   
	EXEC sp_ExecuteSQL 
	  	@c_SQLStmt,    @c_SQLParm, 	
	  	@c_Facility,   @c_StorerKey , @c_SKU,    
      @c_Lottable01, @c_Lottable02, @c_Lottable03,    
      @d_Lottable04, @d_Lottable05, @c_Lottable06,    
      @c_Lottable07, @c_Lottable08, @c_Lottable09,    
      @c_Lottable10, @c_Lottable11, @c_Lottable12,    
      @d_Lottable13, @d_Lottable14, @d_Lottable15 	  	 	  	 
    
	 IF @b_debug = 1	PRINT @c_SQLStmt	    	  	 	           
END

GO