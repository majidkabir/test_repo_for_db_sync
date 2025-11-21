SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispToLoc_DynamicLoc                                */
/* Creation Date: 26-Jul-2018                                           */
/* Copyright: LFL                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Release task calculate toloc strategy for Dynamic location. */     
/*                                                                      */
/* Called By: isp_CreateTaskByPick                                      */ 
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 27-Feb-2019  NJOW01   1.0  WMS-8017 add orderkey parameter           */
/************************************************************************/

CREATE PROC [dbo].[ispToLoc_DynamicLoc]   
      @c_Loadkey                NVARCHAR(10)      
     ,@c_WaveKey                NVARCHAR(10)
     ,@c_Orderkey               NVARCHAR(10) = '' 
     ,@c_Storerkey              NVARCHAR(15)             
     ,@c_Sku                    NVARCHAR(20)
     ,@c_Lot                    NVARCHAR(10)
     ,@c_Loc                    NVARCHAR(10)
     ,@c_ID                     NVARCHAR(18)
     ,@c_UOM                    NVARCHAR(10)
     ,@n_Qty                    INT = 0                          
     ,@c_ToLoc_StrategyParam    NVARCHAR(4000) = ''        
     ,@c_ToLoc                  NVARCHAR(10) = '' OUTPUT
     ,@n_QtyRemain              INT = 0       OUTPUT
     ,@b_Success                INT           OUTPUT 
     ,@n_Err                    INT           OUTPUT 
     ,@c_ErrMsg                 NVARCHAR(255) OUTPUT 
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                     INT,
           @n_Cnt                          INT,
           @n_StartTCnt                    INT,          
           @c_SQL                          NVARCHAR(4000),
           @c_SQLParm                      NVARCHAR(4000)
                                           
   DECLARE @c_LocationType                 NVARCHAR(200),
           @c_Facility                     NVARCHAR(5),
           @c_LocGrouping                  NVARCHAR(1000),
           @c_LocGroupingSQL               NVARCHAR(2000),
           @c_lottable01                   NVARCHAR(18),
           @c_lottable02                   NVARCHAR(18),
           @c_lottable03                   NVARCHAR(18),
           @dt_lottable04                  DATETIME,
           @dt_lottable05                  DATETIME,
           @c_lottable06                   NVARCHAR(30),  
           @c_lottable07                   NVARCHAR(30),  
           @c_lottable08                   NVARCHAR(30),  
           @c_lottable09                   NVARCHAR(30),  
           @c_lottable10                   NVARCHAR(30),  
           @c_lottable11                   NVARCHAR(30),  
           @c_lottable12                   NVARCHAR(30),  
           @dt_lottable13                  DATETIME ,      
           @dt_lottable14                  DATETIME ,      
           @dt_lottable15                  DATETIME ,            
           @c_SkuGroup                     NVARCHAR(10),
           @c_ItemClass                    NVARCHAR(10),
           @c_Style                        NVARCHAR(20),
           @c_Color                        NVARCHAR(10),
           @c_Size                         NVARCHAR(10),
           @c_MaxQtyPerLoc                 NVARCHAR(10),
           @n_MaxQtyPerLoc                 INT,           
           @c_MaxCasePerLoc                NVARCHAR(10),
           @n_MaxCasePerLoc                INT,
           @c_HavingSQL                    NVARCHAR(1000),
           @n_QtyOnLoc                     INT,
           @c_FoundLoc                     NVARCHAR(10),
           @n_CaseCnt                      INT,
           @c_CaseQty                      INT,
           @n_NoofCaseCanFit               INT,
           @c_AllocateGetCasecntFrLottable NVARCHAR(30),
           @c_CaseCntByLocUCC               NVARCHAR(30),
           @n_UCCQty                       INT
                                                                                                              
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
	 SELECT @n_Casecnt = 0 , @n_UCCQty = 0
	 	
	 IF @n_continue IN(1,2)
	 BEGIN
	    SET @c_LocationType = 'DYNPPICK'   --Mulitple locations can be delimited by comma 
	    SET @c_LocGrouping = 'SKU.Storerkey, SKU.Sku'  --Dynamic location grouping. Can group fields from SKU, LOTATTRIBUTE tables.
	    SELECT @c_MaxQtyPerLoc = '0', @n_MaxQtyPerLoc = 0 --Max qty per location.
	    SELECT @c_MaxCasePerLoc = '0', @n_MaxCasePerLoc = 0 --Max case per location.
	    SET @c_CaseCntByLocUCC = 'N' --Get casecnt by UCC of the loc
	    
	    --Get setting from @c_ToLoc_StrategyParam. Exmple settings @c_LocationType=DYNPPICK LocGrouping=STORERKEY,SKU,LOTTABLE03
	    SELECT @c_LocationType = dbo.fnc_GetParamValueFromString('@c_LocationType', @c_ToLoc_StrategyParam, @c_LocationType)
	    SELECT @c_LocGrouping = dbo.fnc_GetParamValueFromString('@c_LocGrouping', @c_ToLoc_StrategyParam, @c_LocGrouping)
	    SELECT @c_MaxQtyPerLoc = dbo.fnc_GetParamValueFromString('@c_MaxQtyPerLoc', @c_ToLoc_StrategyParam, @c_MaxQtyPerLoc)
	    SELECT @c_MaxCasePerLoc = dbo.fnc_GetParamValueFromString('@c_MaxCasePerLoc', @c_ToLoc_StrategyParam, @c_MaxCasePerLoc)
	    SELECT @c_CaseCntByLocUCC = dbo.fnc_GetParamValueFromString('@c_CaseCntByLocUCC', @c_ToLoc_StrategyParam, @c_CaseCntByLocUCC)
	 
	    --Confiure location grouping
	    IF CHARINDEX('STORERKEY', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.Storerkey = @c_Storerkey '
	    IF CHARINDEX('SKU', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.Sku = @c_Sku '
	    IF CHARINDEX('LOTTABLE01', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE01 = @c_Lottable01 '
	    IF CHARINDEX('LOTTABLE02', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE02 = @c_Lottable02 '
	    IF CHARINDEX('LOTTABLE03', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE03 = @c_Lottable03 '
	    IF CHARINDEX('LOTTABLE04', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND DATEDIFF(Day, LOTATTRIBUTE.LOTTABLE04, @dt_Lottable04) = 0 '
	    IF CHARINDEX('LOTTABLE05', @c_LocGrouping, 1) > 0                                                                                 
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND DATEDIFF(Day, LOTATTRIBUTE.LOTTABLE05, @dt_Lottable05) = 0 '
	    IF CHARINDEX('LOTTABLE06', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE06 = @c_Lottable06 '
	    IF CHARINDEX('LOTTABLE07', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE07 = @c_Lottable07 '
	    IF CHARINDEX('LOTTABLE08', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE08 = @c_Lottable08 '
	    IF CHARINDEX('LOTTABLE09', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE09 = @c_Lottable09 '
	    IF CHARINDEX('LOTTABLE10', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE10 = @c_Lottable10 '
	    IF CHARINDEX('LOTTABLE11', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE11 = @c_Lottable11 '
	    IF CHARINDEX('LOTTABLE12', @c_LocGrouping, 1) > 0                                                              
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND LOTATTRIBUTE.LOTTABLE12 = @c_Lottable12 '
	    IF CHARINDEX('LOTTABLE13', @c_LocGrouping, 1) > 0
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND DATEDIFF(Day, LOTATTRIBUTE.LOTTABLE13, @dt_Lottable13) = 0 '
	    IF CHARINDEX('LOTTABLE14', @c_LocGrouping, 1) > 0                                                                                 
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND DATEDIFF(Day, LOTATTRIBUTE.LOTTABLE14, @dt_Lottable14) = 0 '
	    IF CHARINDEX('LOTTABLE15', @c_LocGrouping, 1) > 0                                                                                 
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND DATEDIFF(Day, LOTATTRIBUTE.LOTTABLE15, @dt_Lottable15) = 0 '
	    
	    IF CHARINDEX('LOTTABLE', @c_LocGrouping, 1) > 0     
	    BEGIN
	       SELECT @c_Lottable01 = LA.LOTTABLE01, @c_Lottable02 = LA.LOTTABLE02, @c_Lottable03 = LA.LOTTABLE03, @dt_Lottable04 = LA.LOTTABLE04, @dt_Lottable05 = LA.LOTTABLE05,
	              @c_Lottable06 = LA.LOTTABLE06, @c_Lottable07 = LA.LOTTABLE07, @c_Lottable08 = LA.LOTTABLE08, @c_Lottable09 = LA.LOTTABLE09, @c_Lottable10 = LA.LOTTABLE10,
	              @c_Lottable11 = LA.LOTTABLE11, @c_Lottable12 = LA.LOTTABLE12, @dt_Lottable13 = LA.LOTTABLE13, @dt_Lottable14 = LA.LOTTABLE14, @dt_Lottable15 = LA.LOTTABLE15
	       FROM LOTATTRIBUTE LA (NOLOCK)
	       WHERE Lot = @c_Lot       
	    END
	    
	    IF CHARINDEX('SKUGROUP', @c_LocGrouping, 1) > 0                                        
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.SkuGroup = @c_SkuGroup '
	    IF CHARINDEX('ITEMCLASS', @c_LocGrouping, 1) > 0                                        
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.ItemClass = @c_ItemClass '
	    IF CHARINDEX('STYLE', @c_LocGrouping, 1) > 0                                        
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.Style = @c_Style '
	    IF CHARINDEX('COLOR', @c_LocGrouping, 1) > 0                                        
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.Color = @c_Color '
	    IF CHARINDEX('SIZE', @c_LocGrouping, 1) > 0                                        
	       SET @c_LocGroupingSQL = RTRIM(ISNULL(@c_LocGroupingSQL,'')) + ' AND SKU.Size = @c_Size '
	       
	    --Get facility
	    SELECT @c_Facility = Facility
	    FROM LOC (NOLOCK)
	    WHERE Loc = @c_Loc
	    
	    --Retrieve fiels from sku 
	    SELECT @c_SkuGroup = SKU.SkuGroup,
	           @c_ItemClass = SKU.ItemClass,
             @c_Style = SKU.Style,
             @c_Color = SKU.Color,
             @c_Size = SKU.Size,
             @n_Casecnt = PACK.Casecnt 
	    FROM SKU (NOLOCK)
	    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey	    
	    WHERE SKU.Storerkey = @c_Storerkey
	    AND Sku = @c_Sku

      --Get casecnt by UCC of the loc
      IF @c_CasecntbyLocUCC = 'Y' AND ISNULL(@c_Lot,'') <> '' 
      BEGIN      	
         SELECT @n_UCCQty = MAX(UCC.Qty)
         FROM UCC (NOLOCK)
         WHERE UCC.Storerkey = @c_Storerkey
         AND UCC.Sku = @c_Sku
         AND UCC.Lot = @c_Lot
         AND UCC.Loc = @c_Loc
         AND UCC.ID = @c_ID
         AND UCC.Status <= '3'
         
         IF @n_UCCQty > 0
            SET @n_Casecnt = @n_UCCQty
      END

      --Get casecnt from lottable by config	    
      SELECT @c_AllocateGetCasecntFrLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllocateGetCasecntFrLottable') 
                 
      IF ISNULL(@c_AllocateGetCasecntFrLottable,'')  IN ('01','02','03','06','07','08','09','10','11','12') AND ISNULL(@c_Lot,'') <> ''
      BEGIN
         SET @c_CaseQty = ''
         SET @c_SQL = N'SELECT @c_CaseQty = Lottable' + RTRIM(LTRIM(@c_AllocateGetCasecntFrLottable)) +       	 
             ' FROM LOTATTRIBUTE(NOLOCK) ' +
             ' WHERE LOT = @c_Lot '
         
   	     EXEC sp_executesql @c_SQL,
   	     N'@c_CaseQty NVARCHAR(30) OUTPUT, @c_Lot NVARCHAR(10)', 
   	     @c_CaseQty OUTPUT,
   	     @c_lot    
   	     
   	     IF ISNUMERIC(@c_CaseQty) = 1
   	     	  SELECT @n_CaseCnt = CAST(@c_CaseQty AS INT)
      END
	    	    
	    --Configure maximum qty per location
	    IF ISNUMERIC(@c_MaxQtyPerLoc) = 1
	       SET @n_MaxQtyPerLoc = CAST(@c_MaxQtyPerLoc AS INT)
	       
	     IF @n_MaxQtyPerLoc > 0
	       SET @c_HavingSQL = RTRIM(ISNULL(@c_HavingSQL,''))  +  ' AND SUM((LOTxLOCxID.Qty + LOTxLOCxID.PendingMoveIN + LOTxLOCxID.QtyExpected) - LOTxLOCxID.QtyPicked) < ' + RTRIM(@c_MaxQtyPerLoc)	      
      
      --Configure maximum case per location
	    IF ISNUMERIC(@c_MaxCasePerLoc) = 1
	       SET @c_MaxCasePerLoc = CAST(@c_MaxCasePerLoc AS INT)
	       
	     IF @n_MaxCasePerLoc > 0 AND @n_Casecnt > 0
	       SET @c_HavingSQL = RTRIM(ISNULL(@c_HavingSQL,''))  +  ' AND CEILING(SUM((LOTxLOCxID.Qty + LOTxLOCxID.PendingMoveIN + LOTxLOCxID.QtyExpected) - LOTxLOCxID.QtyPicked) / (@n_Casecnt * 1.00)) < ' + RTRIM(@n_MaxCasePerLoc)	      
	 END   
	 
	 IF @n_continue IN (1,2)
	 BEGIN
	 	   SET @c_FoundLoc = ''
	 	   SET @n_QtyOnLoc = 0
	 	   
	 	   --Find exising loc with stock matching require criteria. Can match by storerkey, sku, lottable01-15, skugroup, itemclass, style, color, size
	 	   --Can fit by location limit. Max qty, Max carton
       SET @c_SQL = N'SELECT TOP 1 @c_FoundLoc = LOC.LOC, 
                      @n_QtyOnLoc = SUM((LOTxLOCxID.Qty + LOTxLOCxID.PendingMoveIN + LOTxLOCxID.QtyExpected) - LOTxLOCxID.QtyPicked) 
                      FROM LOTxLOCxID (NOLOCK)
                      JOIN LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.LOC               
                      JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND LOTxLOCxID.Sku = SKU.Sku    
                      JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot
                      WHERE LOC.Facility = @c_Facility
                      AND LOC.LocationType IN (SELECT ColValue FROM dbo.fnc_DelimSplit('','',@c_LocationType)) ' +
                      RTRIM(ISNULL(@c_LocGroupingSQL,'')) +
                    ' GROUP BY LOC.LogicalLocation, LOC.LOC
                      HAVING SUM((LOTxLOCxID.Qty + LOTxLOCxID.PendingMoveIN + LOTxLOCxID.QtyExpected) - LOTxLOCxID.QtyPicked) > 0 ' +
                      RTRIM(ISNULL(@c_HavingSQL,'')) +
                    ' ORDER BY LOC.LogicalLocation, LOC.LOC '
       
       SET @c_SQLParm = N'@c_LocationType NVARCHAR(200), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_Facility NVARCHAR(5), @c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18),
                          @c_Lottable03 NVARCHAR(18), @dt_Lottable04 DATETIME, @dt_Lottable05 DATETIME, @c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), 
                          @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30), @c_Lottable11 NVARCHAR(30),  @c_Lottable12 NVARCHAR(30), @dt_Lottable13 DATETIME, @dt_Lottable14 DATETIME,
                          @dt_Lottable15 DATETIME, @c_SkuGroup NVARCHAR(10), @c_ItemClass NVARCHAR(10), @c_Style NVARCHAR(20), @c_Color NVARCHAR(10), @c_Size NVARCHAR(10),
                          @c_FoundLoc NVARCHAR(10) OUTPUT, @n_QtyOnLoc INT OUTPUT'

       EXEC sp_executesql @c_SQL, @c_SQLParm, 
            @c_LocationType,
            @c_Storerkey,
            @c_Sku,
            @c_Facility,
            @c_lottable01,  
            @c_lottable02,  
            @c_lottable03,  
            @dt_lottable04,  
            @dt_lottable05,  
            @c_lottable06,  
            @c_lottable07,  
            @c_lottable08,  
            @c_lottable09,  
            @c_lottable10,  
            @c_lottable11,  
            @c_lottable12,  
            @dt_lottable13, 
            @dt_lottable14, 
            @dt_lottable15,
            @c_SkuGroup,
            @c_ItemClass,
            @c_Style,
            @c_Color,
            @c_Size,            
            @c_FoundLoc OUTPUT,
            @n_QtyOnLoc OUTPUT
       
       --find empty location
       IF ISNULL(@c_FoundLoc,'') = ''
       BEGIN       
          /*SELECT TOP 1 @c_FoundLoc = LOC.LOC
          FROM  LOTxLOCxID (NOLOCK)
          JOIN  LOC (NOLOCK) ON LOTxLOCxID.LOC = LOC.Loc
          WHERE LOC.Facility = @c_Facility
          AND LOC.LocationType IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_LocationType))            
          GROUP BY LOC.LogicalLocation, LOC.Loc
          HAVING SUM((LOTxLOCxID.Qty + LOTxLOCxID.PendingMoveIN + LOTxLOCxID.QtyExpected) - LOTxLOCxID.QtyPicked) = 0  
          ORDER BY LOC.LogicalLocation, LOC.Loc*/          
          
          SELECT TOP 1 @c_FoundLoc = LOC.LOC
          FROM  LOC (NOLOCK)
          LEFT JOIN LOTxLOCxID (NOLOCK) ON LOTxLOCxID.LOC = LOC.Loc
          WHERE LOC.Facility = @c_Facility
          AND LOC.LocationType IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_LocationType))            
          GROUP BY LOC.LogicalLocation, LOC.Loc
          HAVING SUM((ISNULL(LOTxLOCxID.Qty,0) + ISNULL(LOTxLOCxID.PendingMoveIN,0) + ISNULL(LOTxLOCxID.QtyExpected,0)) - ISNULL(LOTxLOCxID.QtyPicked,0)) = 0  
          ORDER BY LOC.LogicalLocation, LOC.Loc        
          

          IF ISNULL(@c_FoundLoc,'') <> ''       
             SET @n_QtyOnLoc = 0
       END

       IF ISNULL(@c_FoundLoc,'') = ''
       BEGIN       
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82100   
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unable to find available Dynamic location ''' + RTRIM(@c_LocationType)+ ''' (ispToLoc_DynamicLoc)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                  
       END              
       ELSE
       BEGIN
       	  --Found location
       	  SET @c_ToLoc = @c_FoundLoc
       	   
       	  IF @n_MaxQtyPerLoc > 0    
       	     SET @n_QtyRemain = @n_QtyRemain - (@n_MaxQtyPerLoc - @n_QtyOnLoc) --location full. find next loc with remain qty
       	  ELSE IF @n_MaxCasePerLoc > 0 AND @n_CaseCnt > 0
       	  BEGIN       	     
       	     SET @n_NoofCaseCanFit = @n_MaxCasePerLoc - CEILING(@n_QtyOnLoc / (@n_CaseCnt * 1.00)) 
       	     
       	     IF @n_QtyRemain >= (@n_NoofCaseCanFit * @n_CaseCnt)
       	        SET @n_QtyRemain = @n_QtyRemain - (@n_NoofCaseCanFit * @n_CaseCnt)
       	     ELSE 
       	        SET @n_QtyRemain = 0
       	  END             	           
       	  ELSE
       	     SET @n_QtyRemain = 0  
       END
	 END
	             
   QUIT_SP:
   
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	    IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	ROLLBACK TRAN
	    END
	    ELSE
	    BEGIN
	    	WHILE @@TRANCOUNT > @n_StartTCnt
	    	BEGIN
	    		COMMIT TRAN
	    	END
	    END
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispToLoc_DynamicLoc'		
	    RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	    WHILE @@TRANCOUNT > @n_StartTCnt
	    BEGIN
	    	COMMIT TRAN
	    END
	    RETURN
	 END  
END  

GO